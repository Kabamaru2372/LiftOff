// supabase/functions/duel-alerts/index.ts
//
// Runs every 5 minutes via pg_cron.
// Sends two kinds of duel notifications:
//   1. Lead-change alert  — when one player overtakes the other in Picksy Score
//      Throttled: max once per 2h per duel (last_lead_alert column).
//   2. Midday check-in    — at 09:00 UTC (noon Greece) for every active duel.
//
// Picksy Score formula: pickups + (screen_time_minutes × 5). Lower = better.
//
// Required secrets (Supabase dashboard → Edge Functions → Secrets):
//   APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (auto-injected)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "https://deno.land/x/jose@v4.15.5/index.ts";

const BUNDLE_ID  = "fotiospongas.dev.UnPluq";
const APNS_HOST  = "https://api.push.apple.com";
const LEAD_THROTTLE_HOURS = 2;      // max one lead-change alert per duel per 2h
const SCORE_SCREEN_MULT   = 5;      // pickups + (screen_time_min × 5)

// ─── Supabase ──────────────────────────────────────────────────────────────

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

// ─── APNs JWT (cached, reused for up to 45 min) ───────────────────────────

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

// ─── Send APNs alert ──────────────────────────────────────────────────────

async function sendPush(deviceToken: string, title: string, body: string): Promise<void> {
  const jwt = await getApnsJwt();
  const payload = {
    aps: { alert: { title, body }, sound: "default" }
  };
  const resp = await fetch(`${APNS_HOST}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      "authorization":  `bearer ${jwt}`,
      "apns-topic":     BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority":  "10",
      "content-type":   "application/json"
    },
    body: JSON.stringify(payload)
  });
  if (!resp.ok) {
    console.error(`[APNs] ❌ ${deviceToken.slice(0, 8)}… → ${resp.status}: ${await resp.text()}`);
  } else {
    console.log(`[APNs] ✅ ${deviceToken.slice(0, 8)}…`);
  }
}

// ─── Picksy Score ─────────────────────────────────────────────────────────

function picksyScore(pickups: number, screenTimeSeconds: number): number {
  return pickups + Math.floor(screenTimeSeconds / 60) * SCORE_SCREEN_MULT;
}

// ─── Main ─────────────────────────────────────────────────────────────────

Deno.serve(async () => {
  try {
    const now = new Date();
    const utcHour = now.getUTCHours();
    const utcMin  = now.getUTCMinutes();
    const isMidday = utcHour === 9 && utcMin < 5; // 09:00–09:05 UTC = noon Greece

    // Fetch all active duels
    const { data: duels, error } = await supabase
      .from("duels")
      .select(`
        id,
        challenger_id, opponent_id,
        challenger_name, opponent_name,
        challenger_pickups, opponent_pickups,
        challenger_screen_time, opponent_screen_time,
        last_lead_alert
      `)
      .eq("status", "active");

    if (error || !duels?.length) {
      console.log("[DuelAlerts] No active duels.");
      return new Response("No active duels", { status: 200 });
    }

    // Collect all device IDs and fetch their APNs tokens in one query
    const allIds = [...new Set(duels.flatMap(d => [d.challenger_id, d.opponent_id]))];
    const { data: tokenRows } = await supabase
      .from("device_tokens")
      .select("device_id, token")
      .in("device_id", allIds)
      .eq("is_active", true)
      .eq("token_type", "device");

    const tokenMap = new Map(tokenRows?.map(r => [r.device_id, r.token]) ?? []);

    const throttleCutoff = new Date(now.getTime() - LEAD_THROTTLE_HOURS * 60 * 60 * 1000);
    const duelIdsToUpdateAlert: string[] = [];

    for (const duel of duels) {
      const challengerScore = picksyScore(duel.challenger_pickups, duel.challenger_screen_time);
      const opponentScore   = picksyScore(duel.opponent_pickups,   duel.opponent_screen_time);

      const challengerToken = tokenMap.get(duel.challenger_id);
      const opponentToken   = tokenMap.get(duel.opponent_id);

      // ── 1. Midday check-in ──────────────────────────────────────────────
      if (isMidday) {
        const cLead = challengerScore < opponentScore;
        const oLead = opponentScore < challengerScore;

        if (challengerToken) {
          const title = cLead
            ? "🏆 Κερδίζεις!"
            : oLead ? "💪 Μπορείς καλύτερα!" : "🤝 Ισοπαλία!";
          const body = `Picksy Score: Εσύ ${challengerScore} · ${duel.opponent_name} ${opponentScore}`;
          await sendPush(challengerToken, title, body);
        }
        if (opponentToken) {
          const title = oLead
            ? "🏆 Κερδίζεις!"
            : cLead ? "💪 Μπορείς καλύτερα!" : "🤝 Ισοπαλία!";
          const body = `Picksy Score: Εσύ ${opponentScore} · ${duel.challenger_name} ${challengerScore}`;
          await sendPush(opponentToken, title, body);
        }
        console.log(`[DuelAlerts] 🕛 Midday sent for duel ${duel.id}`);
      }

      // ── 2. Lead-change alert ────────────────────────────────────────────
      // Only fire if one side is clearly ahead and throttle hasn't expired
      if (challengerScore === opponentScore) continue; // tie — skip

      const lastAlert = duel.last_lead_alert ? new Date(duel.last_lead_alert) : null;
      const throttled = lastAlert && lastAlert > throttleCutoff;
      if (throttled) continue;

      // The loser gets the alert ("opponent is winning")
      if (challengerScore > opponentScore) {
        // Opponent winning → notify challenger
        if (challengerToken) {
          const diff = challengerScore - opponentScore;
          await sendPush(
            challengerToken,
            "😤 Σε προηγείται!",
            `Ο ${duel.opponent_name} έχει Picksy Score ${opponentScore}, εσύ ${challengerScore} (+${diff}). Μην τον αφήσεις!`
          );
        }
      } else {
        // Challenger winning → notify opponent
        if (opponentToken) {
          const diff = opponentScore - challengerScore;
          await sendPush(
            opponentToken,
            "😤 Σε προηγείται!",
            `Ο ${duel.challenger_name} έχει Picksy Score ${challengerScore}, εσύ ${opponentScore} (+${diff}). Μην τον αφήσεις!`
          );
        }
      }

      duelIdsToUpdateAlert.push(duel.id);
    }

    // Bulk update last_lead_alert for duels that sent an alert
    if (duelIdsToUpdateAlert.length) {
      await supabase
        .from("duels")
        .update({ last_lead_alert: now.toISOString() })
        .in("id", duelIdsToUpdateAlert);
    }

    return new Response(
      `Processed ${duels.length} duel(s), sent alerts for ${duelIdsToUpdateAlert.length}`,
      { status: 200 }
    );
  } catch (e) {
    console.error("[DuelAlerts] ❌ Error:", e);
    return new Response("Error", { status: 500 });
  }
});
