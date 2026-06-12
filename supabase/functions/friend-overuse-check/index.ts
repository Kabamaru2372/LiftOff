// supabase/functions/friend-overuse-check/index.ts
//
// Runs every 15 minutes via pg_cron.
// Finds pairs where BOTH devices have ≥ 20 min screen time in the last 2h
// AND their status is fresh (updated within last 30 min).
// Sends APNs push to both devices.
//
// Required secrets (set in Supabase dashboard → Edge Functions → Secrets):
//   APNS_KEY_ID      — Key ID from Apple Developer (e.g. "ABC123DEFG")
//   APNS_TEAM_ID     — Team ID from Apple Developer (e.g. "XYZ987TEAM")
//   APNS_PRIVATE_KEY — Full content of the .p8 file (including headers)
//   SUPABASE_URL     — auto-injected
//   SUPABASE_SERVICE_ROLE_KEY — auto-injected

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "https://deno.land/x/jose@v4.15.5/index.ts";

const BUNDLE_ID      = "fotiospongas.dev.UnPluq";
const SCREEN_THRESH  = 20 * 60;   // 20 minutes in seconds
const FRESH_WINDOW   = 30 * 60;   // 30 minutes — ignore stale status rows
const APNS_HOST      = "https://api.push.apple.com"; // production

// ─── Supabase client ───────────────────────────────────────────────────────

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

// ─── APNs JWT ──────────────────────────────────────────────────────────────

let cachedApnsJwt: { token: string; issuedAt: number } | null = null;

async function getApnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  // Reuse token if issued < 45 min ago (APNs tokens expire after 1h)
  if (cachedApnsJwt && now - cachedApnsJwt.issuedAt < 45 * 60) {
    return cachedApnsJwt.token;
  }

  const keyId   = Deno.env.get("APNS_KEY_ID")!;
  const teamId  = Deno.env.get("APNS_TEAM_ID")!;
  const rawKey  = Deno.env.get("APNS_PRIVATE_KEY")!;

  const privateKey = await importPKCS8(rawKey, "ES256");
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt(now)
    .sign(privateKey);

  cachedApnsJwt = { token, issuedAt: now };
  return token;
}

// ─── Send single APNs push ─────────────────────────────────────────────────

async function sendPush(deviceToken: string, title: string, body: string): Promise<void> {
  const jwt = await getApnsJwt();
  const url = `${APNS_HOST}/3/device/${deviceToken}`;

  const payload = {
    aps: {
      alert: { title, body },
      sound: "default",
      "category": "PICKSY_FRIEND_OVERUSING"
    }
  };

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic":    BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type":  "application/json"
    },
    body: JSON.stringify(payload)
  });

  if (!resp.ok) {
    const err = await resp.text();
    console.error(`[APNs] ❌ ${deviceToken.slice(0, 8)}… → ${resp.status}: ${err}`);
  } else {
    console.log(`[APNs] ✅ Sent to ${deviceToken.slice(0, 8)}…`);
  }
}

// ─── Main ──────────────────────────────────────────────────────────────────

Deno.serve(async () => {
  try {
    const now = new Date();
    const freshCutoff = new Date(now.getTime() - FRESH_WINDOW * 1000).toISOString();

    // 1. Fetch all pairs
    const { data: pairs, error: pairsErr } = await supabase
      .from("friend_pairs")
      .select("device_a, device_b, friend_name");

    if (pairsErr || !pairs?.length) {
      return new Response("No pairs", { status: 200 });
    }

    // 2. Fetch all fresh device statuses in one query
    const allDeviceIds = [...new Set(pairs.flatMap(p => [p.device_a, p.device_b]))];

    const { data: statuses } = await supabase
      .from("device_status")
      .select("device_id, screen_time_last_2h_seconds, updated_at")
      .in("device_id", allDeviceIds)
      .gte("updated_at", freshCutoff);

    const statusMap = new Map(statuses?.map(s => [s.device_id, s]) ?? []);

    // 3. Find pairs where BOTH are overusing
    const overusingPairs: { deviceA: string; deviceB: string; name: string }[] = [];

    for (const pair of pairs) {
      const a = statusMap.get(pair.device_a);
      const b = statusMap.get(pair.device_b);
      if (!a || !b) continue;

      if (
        a.screen_time_last_2h_seconds >= SCREEN_THRESH &&
        b.screen_time_last_2h_seconds >= SCREEN_THRESH
      ) {
        overusingPairs.push({ deviceA: pair.device_a, deviceB: pair.device_b, name: pair.friend_name ?? "your friend" });
        console.log(`[FriendCheck] 🔥 Both overusing: ${pair.device_a.slice(0,8)}… & ${pair.device_b.slice(0,8)}…`);
      }
    }

    if (!overusingPairs.length) {
      return new Response("No overusing pairs", { status: 200 });
    }

    // 4. Fetch APNs tokens for affected devices
    const affectedIds = overusingPairs.flatMap(p => [p.deviceA, p.deviceB]);

    // We need to map device_id → APNs token.
    // device_tokens table has: token, bundle_id, is_active, token_type
    // We need to join with device_status via device_id.
    // For now device_tokens doesn't have device_id — we use the push token
    // stored when the user registered. We'll look up by the anonymous device_id
    // stored alongside the APNs token.
    const { data: tokenRows } = await supabase
      .from("device_tokens")
      .select("token, device_id")
      .in("device_id", affectedIds)
      .eq("is_active", true)
      .eq("token_type", "device");

    const tokenMap = new Map(tokenRows?.map(r => [r.device_id, r.token]) ?? []);

    // 5. Send pushes
    for (const pair of overusingPairs) {
      const tokenA = tokenMap.get(pair.deviceA);
      const tokenB = tokenMap.get(pair.deviceB);

      const title = `You and ${pair.name} 📱`;
      const body  = "You're both on your phones a lot right now. How about a little detox together?";

      if (tokenA) await sendPush(tokenA, title, body);
      if (tokenB) await sendPush(tokenB, `You and a friend 📱`, body);
    }

    return new Response(`Processed ${overusingPairs.length} overusing pair(s)`, { status: 200 });

  } catch (e) {
    console.error("[FriendCheck] ❌ Error:", e);
    return new Response("Error", { status: 500 });
  }
});
