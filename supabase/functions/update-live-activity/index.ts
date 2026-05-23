// supabase/functions/update-live-activity/index.ts
//
// Called by the iOS app on every pickup.
// Sends an APNs Live Activity push that updates the Dynamic Island
// directly — no app process needed on the device.
//
// This is how live-score apps keep their DI in sync even when
// the app is fully suspended by iOS.
//
// Required secrets (already set from friend-overuse-check):
//   APNS_KEY_ID           — Key ID from Apple Developer
//   APNS_TEAM_ID          — Team ID from Apple Developer
//   APNS_PRIVATE_KEY      — Full content of the .p8 file
//   SUPABASE_URL          — auto-injected
//   SUPABASE_SERVICE_ROLE_KEY — auto-injected
//
// Request body (JSON):
//   device_id          string   — anonymous device UUID
//   pickup_count       number   — new total pickup count
//   duel_opponent_name string?  — present only during an active duel
//   duel_my_pickups    number?
//   duel_their_pickups number?

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "https://deno.land/x/jose@v4.15.5/index.ts";

const BUNDLE_ID = "fotiospongas.dev.UnPluq";

// ─── Supabase ──────────────────────────────────────────────────────────────

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

// ─── APNs JWT (reused from friend-overuse-check pattern) ──────────────────

let cachedJwt: { token: string; issuedAt: number } | null = null;

async function getApnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now - cachedJwt.issuedAt < 45 * 60) return cachedJwt.token;

  const privateKey = await importPKCS8(Deno.env.get("APNS_PRIVATE_KEY")!, "ES256");
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: Deno.env.get("APNS_KEY_ID")! })
    .setIssuer(Deno.env.get("APNS_TEAM_ID")!)
    .setIssuedAt(now)
    .sign(privateKey);

  cachedJwt = { token, issuedAt: now };
  return token;
}

// ─── APNs Live Activity push ───────────────────────────────────────────────

// Swift's JSONEncoder encodes Date as timeIntervalSinceReferenceDate
// (seconds since Jan 1, 2001). The APNs content-state must match exactly.
const SWIFT_REF_DATE = 978307200; // Unix timestamp of 2001-01-01T00:00:00Z

async function sendLiveActivityPush(
  liveToken: string,
  isProduction: boolean,
  pickupCount: number,
  duelOpponentName: string | null,
  duelMyPickups: number,
  duelTheirPickups: number
): Promise<{ ok: boolean; status: number; body: string }> {
  const host = isProduction
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";

  const nowSwift = Date.now() / 1000 - SWIFT_REF_DATE;

  // content-state must match LiftOffActivityAttributes.ContentState (Codable, camelCase)
  const contentState: Record<string, unknown> = {
    pickupCount,
    currentQuote: duelOpponentName
      ? `⚔️ Duel vs ${duelOpponentName}`
      : "Stay present 🍃",
    lastPickupTime:   nowSwift,   // Date → Double (timeIntervalSinceReferenceDate)
    focusEndTime:     null,       // Optional<Date> → null
    focusPickupCount: 0,
    duelOpponentName: duelOpponentName,  // Optional<String>
    duelMyPickups,
    duelTheirPickups,
  };

  const payload = {
    aps: {
      timestamp: Math.floor(Date.now() / 1000),
      event: "update",
      "content-state": contentState,
    },
  };

  const jwt = await getApnsJwt();
  const resp = await fetch(`${host}/3/device/${liveToken}`, {
    method: "POST",
    headers: {
      "authorization":  `bearer ${jwt}`,
      "apns-topic":     `${BUNDLE_ID}.push-type.liveactivity`,
      "apns-push-type": "liveactivity",
      "apns-priority":  "10",
      "content-type":   "application/json",
    },
    body: JSON.stringify(payload),
  });

  const body = await resp.text();
  return { ok: resp.ok, status: resp.status, body };
}

// ─── Main handler ──────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let input: {
    device_id: string;
    pickup_count: number;
    duel_opponent_name?: string | null;
    duel_my_pickups?: number;
    duel_their_pickups?: number;
  };

  try {
    input = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  if (!input.device_id || input.pickup_count === undefined) {
    return new Response("Missing device_id or pickup_count", { status: 400 });
  }

  // 1. Fetch the Live Activity push token for this device
  const { data: rows, error } = await supabase
    .from("device_tokens")
    .select("token, is_production")
    .eq("device_id", input.device_id)
    .eq("token_type", "live_activity")
    .eq("is_active", true)
    .order("updated_at", { ascending: false })
    .limit(1);

  if (error) {
    console.error("[LiveActivity] DB error:", error.message);
    return new Response("DB error", { status: 500 });
  }

  if (!rows?.length) {
    // No token yet — Live Activity may not have started or pushType was nil previously.
    // Not an error; will work after the user's next app open.
    console.log(`[LiveActivity] No token for ${input.device_id.slice(0, 8)}… — skipping`);
    return new Response("No token", { status: 200 });
  }

  const { token, is_production } = rows[0];

  // 2. Send the APNs Live Activity push
  const result = await sendLiveActivityPush(
    token,
    is_production,
    input.pickup_count,
    input.duel_opponent_name ?? null,
    input.duel_my_pickups   ?? 0,
    input.duel_their_pickups ?? 0
  );

  if (!result.ok) {
    console.error(`[LiveActivity] ❌ APNs ${result.status}: ${result.body}`);

    // Deactivate expired / invalid tokens so we don't keep hitting them
    if (result.status === 410 || result.body.includes("BadDeviceToken")) {
      await supabase
        .from("device_tokens")
        .update({ is_active: false })
        .eq("token", token);
      console.log("[LiveActivity] 🗑️ Deactivated stale token");
    }

    return new Response(`APNs error ${result.status}`, { status: 500 });
  }

  console.log(
    `[LiveActivity] ✅ DI updated for ${input.device_id.slice(0, 8)}… → ${input.pickup_count} pickups`
  );
  return new Response("OK", { status: 200 });
});
