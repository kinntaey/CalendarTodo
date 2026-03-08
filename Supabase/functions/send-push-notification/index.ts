import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

interface PushPayload {
  recipient_id: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

Deno.serve(async (req: Request) => {
  const payload: PushPayload = await req.json();

  // Fetch recipient's device tokens
  const { data: profile } = await supabase
    .from("profiles")
    .select("apns_device_tokens")
    .eq("id", payload.recipient_id)
    .single();

  if (!profile?.apns_device_tokens?.length) {
    return new Response(JSON.stringify({ error: "No device tokens" }), {
      status: 404,
    });
  }

  // TODO: Send APNs notification using HTTP/2
  // This requires APNs auth key (p8 file) stored as env variable
  // For now, log the notification
  console.log("Push notification:", {
    tokens: profile.apns_device_tokens,
    title: payload.title,
    body: payload.body,
  });

  // Insert into notifications table
  await supabase.from("notifications").insert({
    recipient_id: payload.recipient_id,
    title: payload.title,
    body: payload.body,
    type: payload.data?.type ?? "event_alarm",
    reference_type: payload.data?.reference_type,
    reference_id: payload.data?.reference_id,
  });

  return new Response(JSON.stringify({ success: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
