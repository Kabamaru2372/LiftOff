import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Generates a short-lived APNs JWT token (same as picksy-silent-push)
async function generateAPNsToken(
  privateKey: string,
  keyId: string,
  teamId: string
): Promise<string> {
  const pemContents = privateKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const header = btoa(JSON.stringify({ alg: "ES256", kid: keyId }))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  const now = Math.floor(Date.now() / 1000);
  const payload = btoa(JSON.stringify({ iss: teamId, iat: now }))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  const message = `${header}.${payload}`;
  const encoder = new TextEncoder();

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    cryptoKey,
    encoder.encode(message)
  );

  const signatureBase64 = btoa(
    String.fromCharCode(...new Uint8Array(signature))
  ).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  return `${message}.${signatureBase64}`;
}

async function sendVisiblePush(
  deviceToken: string,
  bundleId: string,
  apnsToken: string,
  isProduction: boolean,
  title: string,
  body: string
): Promise<{ success: boolean; error?: string }> {
  const apnsHost = isProduction
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";

  const payload = {
    aps: {
      alert: { title, body },
      sound: "default",
      "mutable-content": 1,
    },
    type: "update-available",
  };

  try {
    const response = await fetch(`${apnsHost}/3/device/${deviceToken}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${apnsToken}`,
        "apns-topic": bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (response.status === 200) {
      return { success: true };
    } else {
      const errorText = await response.text();
      return { success: false, error: `${response.status}: ${errorText}` };
    }
  } catch (err) {
    return { success: false, error: String(err) };
  }
}

Deno.serve(async (req) => {
  // Simple secret check so only you can trigger this
  const authHeader = req.headers.get("authorization") ?? "";
  const broadcastSecret = Deno.env.get("BROADCAST_SECRET") ?? "";
  if (!broadcastSecret || authHeader !== `Bearer ${broadcastSecret}`) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "content-type": "application/json" },
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SERVICE_ROLE_KEY")!;
    const apnsPrivateKey = Deno.env.get("APNS_PRIVATE_KEY")!;
    const apnsKeyId = Deno.env.get("APNS_KEY_ID")!;
    const apnsTeamId = Deno.env.get("APNS_TEAM_ID")!;
    const bundleId = Deno.env.get("BUNDLE_ID")!;
    const isProduction = Deno.env.get("APNS_PRODUCTION") === "true";

    // Optional: override message via request body
    let title = "Picksy 2.0 is here! 🎉";
    let body = "Soundscapes, animated sky, duel sounds and more. Update now!";
    try {
      const reqBody = await req.json();
      if (reqBody.title) title = reqBody.title;
      if (reqBody.body) body = reqBody.body;
    } catch {
      // no body — use defaults above
    }

    const supabase = createClient(supabaseUrl, supabaseKey);
    const apnsToken = await generateAPNsToken(apnsPrivateKey, apnsKeyId, apnsTeamId);

    const { data: tokens, error: fetchError } = await supabase
      .from("device_tokens")
      .select("token, is_production")
      .eq("is_active", true)
      .eq("token_type", "device");

    if (fetchError) throw new Error(`Failed to fetch tokens: ${fetchError.message}`);
    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: "No devices registered", sent: 0 }),
        { headers: { "content-type": "application/json" } }
      );
    }

    console.log(`📢 Broadcasting update notification to ${tokens.length} devices...`);

    // Batch in groups of 50 to avoid overwhelming APNs
    const batchSize = 50;
    let sent = 0, failed = 0;
    const errors: string[] = [];

    for (let i = 0; i < tokens.length; i += batchSize) {
      const batch = tokens.slice(i, i + batchSize);
      const results = await Promise.all(
        batch.map((t) =>
          sendVisiblePush(
            t.token, bundleId, apnsToken,
            t.is_production ?? isProduction,
            title, body
          )
        )
      );
      sent += results.filter((r) => r.success).length;
      const batchErrors = results.filter((r) => !r.success).map((r) => r.error!);
      failed += batchErrors.length;
      errors.push(...batchErrors.slice(0, 5)); // keep first 5 errors per batch
    }

    console.log(`✅ Sent: ${sent}, ❌ Failed: ${failed}`);

    return new Response(
      JSON.stringify({ success: true, sent, failed, total: tokens.length, errors }),
      { headers: { "content-type": "application/json" } }
    );
  } catch (err) {
    console.error("Error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "content-type": "application/json" } }
    );
  }
});
