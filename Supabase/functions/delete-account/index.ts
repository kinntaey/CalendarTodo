import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Verify JWT from Authorization header
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "Missing authorization" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const token = authHeader.replace("Bearer ", "");

  // Create a user-scoped client to verify the token
  const supabaseUser = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: `Bearer ${token}` } } }
  );

  const {
    data: { user },
    error: authError,
  } = await supabaseUser.auth.getUser();

  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Invalid token" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Admin client for privileged operations
  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  try {
    // Delete avatar from storage (ignore errors if no avatar exists)
    const { data: files } = await supabaseAdmin.storage
      .from("avatars")
      .list(user.id);

    if (files && files.length > 0) {
      const filePaths = files.map((f: { name: string }) => `${user.id}/${f.name}`);
      await supabaseAdmin.storage.from("avatars").remove(filePaths);
    }

    // Clean up references that lack ON DELETE CASCADE before deleting the user
    const uid = user.id;
    await supabaseAdmin.from("event_participants").delete().eq("invited_by", uid);
    await supabaseAdmin.from("event_participants").delete().eq("user_id", uid);
    await supabaseAdmin.from("todos").update({ completed_by: null }).eq("completed_by", uid);
    await supabaseAdmin.from("todos").update({ assigned_to: null }).eq("assigned_to", uid);
    await supabaseAdmin.from("todo_list_members").delete().eq("invited_by", uid);
    await supabaseAdmin.from("notifications").delete().eq("sender_id", uid);
    await supabaseAdmin.from("notifications").delete().eq("recipient_id", uid);

    // Delete auth user — this cascades: auth.users → profiles → remaining tables
    const { error: deleteError } =
      await supabaseAdmin.auth.admin.deleteUser(user.id);

    if (deleteError) {
      console.error("Delete user error:", deleteError.message);
      return new Response(
        JSON.stringify({ error: "Failed to delete account" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
