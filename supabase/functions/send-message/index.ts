// supabase/functions/send-message/index.ts
//
// HTTP Edge Function. Called by the iOS app after inserting a message.
// Looks up the receiver's APNs push token and sends a notification.
//
// Required secrets (shared with friend-overuse-check):
//   APNS_KEY_ID
//   APNS_TEAM_ID
//   APNS_PRIVATE_KEY
//   SUPABASE_URL          — auto-injected
//   SUPABASE_SERVICE_ROLE_KEY — auto-injected

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "https://deno.land/x/jose@v4.15.5/index.ts";

const BUNDLE_ID = "fotiospongas.dev.UnPluq";
const APNS_HOST = "https://api.push.apple.com"; // production

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

// ─── Send APNs push ────────────────────────────────────────────────────────

async function sendPush(
  deviceToken: string,
  title: string,
  body: string
): Promise<void> {
  const jwt = await getApnsJwt();
  const url = `${APNS_HOST}/3/device/${deviceToken}`;

  const payload = {
    aps: {
      alert: { title, body },
      sound: "default",
      category: "PICKSY_MESSAGE"
    }
  };

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      authorization:      `bearer ${jwt}`,
      "apns-topic":       BUNDLE_ID,
      "apns-push-type":   "alert",
      "apns-priority":    "10",
      "content-type":     "application/json"
    },
    body: JSON.stringify(payload)
  });

  if (!resp.ok) {
    const err = await resp.text();
    console.error(`[send-message] ❌ APNs ${resp.status}: ${err}`);
  } else {
    console.log(`[send-message] ✅ Push sent to ${deviceToken.slice(0, 8)}…`);
  }
}

// ─── Main ──────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  let body: { receiver_device_id?: string; sender_name?: string };
  try {
    body = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const { receiver_device_id, sender_name } = body;

  if (!receiver_device_id) {
    return new Response("Missing receiver_device_id", { status: 400 });
  }

  // Look up receiver's push token
  const { data: tokenRows, error } = await supabase
    .from("device_tokens")
    .select("token")
    .eq("device_id", receiver_device_id)
    .eq("is_active", true)
    .eq("token_type", "device")
    .limit(1);

  if (error) {
    console.error("[send-message] ❌ Supabase error:", error);
    return new Response("Database error", { status: 500 });
  }

  const pushToken = tokenRows?.[0]?.token;
  if (!pushToken) {
    console.log(`[send-message] ⚠️ No token for device ${receiver_device_id.slice(0, 8)}…`);
    return new Response("No push token for receiver", { status: 200 });
  }

  const name  = sender_name ?? "A friend";
  const title = name;
  const alert = "sent you a message";

  await sendPush(pushToken, title, alert);

  return new Response("OK", { status: 200 });
});
