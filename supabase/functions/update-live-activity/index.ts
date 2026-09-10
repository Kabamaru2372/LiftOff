// supabase/functions/update-live-activity/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "https://deno.land/x/jose@v4.15.5/index.ts";

const BUNDLE_ID = "fotiospongas.dev.UnPluq";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

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

const SWIFT_REF_DATE = 978307200;

async function sendLiveActivityPush(
  liveToken: string,
  isProduction: boolean,
  pickupCount: number,
  screenTimeSecs: number,
  duelOpponentName: string | null,
  duelMySecs: number,
  duelTheirSecs: number,
  focusEndTimeUnix: number | null,
  focusPickupCount: number,
  plantHealth: number,
  plantHealthTimeUnix: number,
  plantHealthWilting: boolean,
  lastPickupTimeUnix: number
): Promise<{ ok: boolean; status: number; body: string }> {
  const host = isProduction
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";
  const nowSwift = Date.now() / 1000 - SWIFT_REF_DATE;
  // An active Focus session takes priority over Duel/Normal — mirrors the
  // priority order the app itself uses (Focus > Duel > Normal). Without this,
  // a background/remote push during Focus would flip the DI back to
  // Normal/Duel, since a remote push replaces the WHOLE content-state.
  const focusEndTimeSwift = focusEndTimeUnix != null ? focusEndTimeUnix - SWIFT_REF_DATE : null;
  // Plant-growth checkpoint (Dynamic Island "time since last pickup" growth
  // animation) — default to "now" with 0 health if never set, so the plant
  // starts fresh instead of showing distantPast. plantHealthWilting is a
  // straight passthrough — the widget does its own client-side extrapolation
  // (grow vs wilt) from (baseline, time, isWilting), same math as the app.
  const plantHealthTimeSwift = plantHealthTimeUnix > 0 ? plantHealthTimeUnix - SWIFT_REF_DATE : nowSwift;
  // "Time since last pickup" ticker — must reflect the REAL last detected
  // pickup (sent by the app from ScreenUnlockDetector), never "now" at push
  // time. Stamping "now" here meant every routine background/remote push
  // (BGAppRefresh, duel sync, silent push) falsely reset the ticker to 0,
  // even when no new pickup had actually happened. Fall back to "now" only
  // when the app never sent one (e.g. very first-ever activity).
  const lastPickupTimeSwift = lastPickupTimeUnix > 0 ? lastPickupTimeUnix - SWIFT_REF_DATE : nowSwift;
  const contentState: Record<string, unknown> = {
    pickupCount,
    currentQuote: duelOpponentName ? `⚔️ Duel vs ${duelOpponentName}` : "Stay present 🍃",
    lastPickupTime: lastPickupTimeSwift,
    focusEndTime: focusEndTimeSwift,
    focusPickupCount,
    duelOpponentName,
    duelMySecs,
    duelTheirSecs,
    screenTimeSecs,
    plantHealthBaseline: plantHealth,
    plantHealthBaselineTime: plantHealthTimeSwift,
    plantHealthIsWilting: plantHealthWilting,
  };
  const payload = { aps: { timestamp: Math.floor(Date.now() / 1000), event: "update", "content-state": contentState } };
  const jwt = await getApnsJwt();
  const resp = await fetch(`${host}/3/device/${liveToken}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": `${BUNDLE_ID}.push-type.liveactivity`,
      "apns-push-type": "liveactivity",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  const body = await resp.text();
  return { ok: resp.ok, status: resp.status, body };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  let input: {
    device_id: string;
    pickup_count: number;
    screen_time_secs?: number;
    duel_opponent_name?: string | null;
    duel_my_secs?: number;
    duel_their_secs?: number;
    focus_end_time?: number;
    focus_pickup_count?: number;
    plant_health?: number;
    plant_health_time?: number;
    plant_health_wilting?: boolean;
    last_pickup_time?: number;
  };

  try {
    input = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  if (!input.device_id || input.pickup_count === undefined) {
    return new Response("Missing device_id or pickup_count", { status: 400 });
  }

  // Await the increment so Deno doesn't terminate before the request completes
  await supabase.rpc("increment_edge_calls").catch(() => {});

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
    console.log(`[LiveActivity] No token for ${input.device_id.slice(0, 8)}… — skipping`);
    return new Response("No token", { status: 200 });
  }

  const { token, is_production } = rows[0];
  const result = await sendLiveActivityPush(
    token, is_production, input.pickup_count,
    input.screen_time_secs ?? 0,
    input.duel_opponent_name ?? null,
    input.duel_my_secs ?? 0, input.duel_their_secs ?? 0,
    input.focus_end_time ?? null, input.focus_pickup_count ?? 0,
    input.plant_health ?? 0, input.plant_health_time ?? 0,
    input.plant_health_wilting ?? false,
    input.last_pickup_time ?? 0
  );

  if (!result.ok) {
    console.error(`[LiveActivity] ❌ APNs ${result.status}: ${result.body}`);
    if (result.status === 410 || result.body.includes("BadDeviceToken")) {
      await supabase.from("device_tokens").update({ is_active: false }).eq("token", token);
      console.log("[LiveActivity] 🗑️ Deactivated stale token");
    }
    return new Response(`APNs error ${result.status}`, { status: 500 });
  }

  console.log(`[LiveActivity] ✅ DI updated for ${input.device_id.slice(0, 8)}… → ${input.pickup_count} pickups`);
  return new Response("OK", { status: 200 });
});
