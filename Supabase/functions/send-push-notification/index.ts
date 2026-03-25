import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v4.14.4/index.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!;
const BUNDLE_ID = "com.taehee.calendartodo";
const APNS_HOST = "api.sandbox.push.apple.com"; // Change to api.push.apple.com for production

interface PushPayload {
  recipient_id: string
  title: string;
  body: string;
  data?: Record<string, string>;
}

async function getAPNsToken(): Promise<string> {
  const privateKey = await importPKCS8(APNS_PRIVATE_KEY, "ES256");
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: APNS_KEY_ID })
    .setIssuer(APNS_TEAM_ID)
    .setIssuedAt()
    .sign(privateKey);
}

async function sendToDevice(
  token: string,
  title: string,
  body: string,
  data: Record<string, string>
): Promise<boolean> {
  try {
    const jwt = await getAPNsToken();

    const payload = {
      aps: {
        alert: { title, body },
        sound: "default",
        badge: 1,
      },
      ...data,
    };

    const res = await fetch(`https://${APNS_HOST}/3/device/${token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      const err = await res.text();
      console.error(`APNs error [${token}]: ${res.status} ${err}`);
      return false;
    }
    return true;
  } catch (e) {
    console.error(`Push error: ${e}`);
    return false;
  }
}

Deno.serve(async (req: Request) => {
  try {
    const payload: PushPayload = await req.json();
    console.log("Received push request:", JSON.stringify(payload));

    // Fetch device tokens
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("apns_device_tokens")
      .eq("id", payload.recipient_id)
      .single();

    if (profileError) {
      console.error("Profile fetch error:", profileError);
    }

    const tokens: string[] = profile?.apns_device_tokens ?? [];
    console.log(`Found ${tokens.length} device tokens for ${payload.recipient_id}`);

    // Send push to all devices
    let sent = 0;
    if (tokens.length > 0) {
      const results = await Promise.all(
        tokens.map((t) => {
          console.log(`Sending to token: ${t.substring(0, 10)}...`);
          return sendToDevice(t, payload.title, payload.body || "", payload.data || {});
        })
      );
      sent = results.filter(Boolean).length;
      console.log(`Sent: ${sent}/${tokens.length}`);
    } else {
      console.log("No tokens to send to");
    }

    return new Response(
      JSON.stringify({ sent, total: tokens.length }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
