import { createClient } from "npm:@supabase/supabase-js@2";

const ADMIN_EMAIL = "aleeshopping2026@gmail.com";
const ONE_SIGNAL_URL = "https://api.onesignal.com/notifications";

type Json = Record<string, unknown>;

function response(status: number, body: Json, origin: string) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(origin),
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function corsHeaders(origin: string) {
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

function getSiteUrl() {
  const raw = Deno.env.get("ALEE_SITE_URL");
  if (!raw) throw new Error("Set ALEE_SITE_URL in Supabase Function Secrets.");
  const url = new URL(raw);
  if (url.protocol !== "https:") throw new Error("ALEE_SITE_URL must use HTTPS.");
  if (!url.pathname.endsWith("/")) url.pathname += "/";
  return url;
}

function validateDestination(value: unknown, siteUrl: URL) {
  if (typeof value !== "string" || !value.trim()) {
    throw new Error("Choose where the notification should open.");
  }
  const destination = new URL(value, siteUrl);
  if (destination.protocol !== "https:" || destination.origin !== siteUrl.origin) {
    throw new Error("The link must point to the ALEE website.");
  }
  return destination.href;
}

function createUserClient(accessToken: string) {
  const url = Deno.env.get("SUPABASE_URL") || "";
  const publishableKey =
    Deno.env.get("SUPABASE_ANON_KEY") ||
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ||
    (() => {
      try {
        return JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") || "{}").default;
      } catch {
        return "";
      }
    })();
  if (!url || !publishableKey) throw new Error("Supabase user authentication is not configured.");
  return createClient(url, publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: "Bearer " + accessToken } },
  });
}

function createAdminClient() {
  const url = Deno.env.get("SUPABASE_URL") || "";
  const secretKey =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
    (() => {
      try {
        return JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}").default;
      } catch {
        return "";
      }
    })();
  if (!url || !secretKey) throw new Error("Supabase server-side secret key is not available.");
  return createClient(url, secretKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

async function sendOneSignal(payload: Json) {
  const appId = Deno.env.get("ONESIGNAL_APP_ID");
  const apiKey = Deno.env.get("ONESIGNAL_REST_API_KEY");
  if (!appId || !apiKey) throw new Error("Set ONESIGNAL_APP_ID and ONESIGNAL_REST_API_KEY in Supabase Function Secrets.");

  const result = await fetch(ONE_SIGNAL_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Key " + apiKey,
    },
    body: JSON.stringify({ app_id: appId, target_channel: "push", ...payload }),
  });
  const data = await result.json().catch(() => ({}));
  if (!result.ok) {
    const detail = typeof data.errors === "string" ? data.errors : JSON.stringify(data.errors || data);
    throw new Error("OneSignal rejected the notification: " + detail);
  }
  return data as Json;
}

function isValidSubscriptionId(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

Deno.serve(async (request) => {
  let siteUrl: URL;
  try {
    siteUrl = getSiteUrl();
  } catch (error) {
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { "Content-Type": "application/json; charset=utf-8" },
    });
  }

  const requestOrigin = request.headers.get("origin") || siteUrl.origin;
  if (requestOrigin !== siteUrl.origin) {
    return response(403, { error: "This website is not allowed to use the ALEE notification service." }, siteUrl.origin);
  }
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(siteUrl.origin) });
  }
  if (request.method !== "POST") {
    return response(405, { error: "Use POST for this request." }, siteUrl.origin);
  }

  try {
    const authorization = request.headers.get("authorization") || "";
    const accessToken = authorization.replace(/^Bearer\s+/i, "").trim();
    if (!accessToken) return response(401, { error: "Sign in to continue." }, siteUrl.origin);

    const userClient = createUserClient(accessToken);
    const { data: authData, error: authError } = await userClient.auth.getUser(accessToken);
    const user = authData?.user;
    if (authError || !user) return response(401, { error: "Your sign-in has expired. Sign in again." }, siteUrl.origin);

    const body = await request.json().catch(() => null) as Record<string, unknown> | null;
    const action = String(body?.action || "");
    const adminClient = createAdminClient();

    if (action === "register") {
      if (!isValidSubscriptionId(body?.subscriptionId)) {
        return response(400, { error: "The browser notification subscription is not ready yet." }, siteUrl.origin);
      }
      const result = await adminClient.from("alee_push_subscriptions").upsert({
        subscription_id: body.subscriptionId,
        user_id: user.id,
        updated_at: new Date().toISOString(),
      }, { onConflict: "subscription_id" });
      if (result.error) throw new Error("Could not save this phone's notification link: " + result.error.message);
      return response(200, { ok: true }, siteUrl.origin);
    }

    if (action === "unregister") {
      if (!isValidSubscriptionId(body?.subscriptionId)) {
        return response(400, { error: "The browser notification subscription is invalid." }, siteUrl.origin);
      }
      const result = await adminClient.from("alee_push_subscriptions")
        .delete()
        .eq("subscription_id", body.subscriptionId)
        .eq("user_id", user.id);
      if (result.error) throw new Error("Could not remove this phone's notification link: " + result.error.message);
      return response(200, { ok: true }, siteUrl.origin);
    }

    if (action === "broadcast") {
      if (String(user.email || "").trim().toLowerCase() !== ADMIN_EMAIL) {
        return response(403, { error: "මෙම පාලකය භාවිත කළ හැක්කේ ALEE ප්‍රධාන පරිපාලක ගිණුමට පමණයි." }, siteUrl.origin);
      }
      const title = String(body?.title || "").trim().slice(0, 70);
      const message = String(body?.message || "").trim().slice(0, 220);
      if (!title || !message) return response(400, { error: "මාතෘකාව සහ පණිවිඩය දෙකම පුරවන්න." }, siteUrl.origin);

      const destination = validateDestination(body?.destinationUrl, siteUrl);
      const imageUrl = typeof body?.imageUrl === "string" ? body.imageUrl.trim() : "";
      if (imageUrl) {
        const image = new URL(imageUrl);
        if (image.protocol !== "https:") return response(400, { error: "ඡායාරූප සබැඳිය HTTPS විය යුතුයි." }, siteUrl.origin);
      }
      const payload: Json = {
        included_segments: ["Subscribed Users"],
        headings: { en: title },
        contents: { en: message },
        url: destination,
        ...(imageUrl ? { chrome_web_image: imageUrl } : {}),
      };
      const sent = await sendOneSignal(payload);
      return response(200, { ok: true, id: sent.id || null, recipients: sent.recipients ?? null }, siteUrl.origin);
    }

    if (action === "chat") {
      if (!/^\d+$/.test(String(body?.messageId || ""))) {
        return response(400, { error: "The chat message ID is invalid." }, siteUrl.origin);
      }
      const messageId = Number(body?.messageId);
      const { data: message, error: messageError } = await adminClient.from("seller_messages")
        .select("id,conversation_id,sender_id,body,attachment_name,deleted_for_everyone")
        .eq("id", messageId)
        .maybeSingle();
      if (messageError) throw new Error("Could not check the chat message: " + messageError.message);
      if (!message || message.sender_id !== user.id || message.deleted_for_everyone) {
        return response(403, { error: "This chat message cannot trigger a notification." }, siteUrl.origin);
      }

      const { data: conversation, error: conversationError } = await adminClient.from("seller_conversations")
        .select("id,shop_id,buyer_id,seller_id,buyer_label,is_group")
        .eq("id", message.conversation_id)
        .maybeSingle();
      if (conversationError) throw new Error("Could not check the chat participants: " + conversationError.message);
      if (!conversation) return response(404, { error: "The chat was not found." }, siteUrl.origin);

      let recipientIds: string[] = [];
      if (conversation.is_group) {
        const { data: members, error: memberError } = await adminClient.from("seller_chat_group_members")
          .select("user_id")
          .eq("conversation_id", conversation.id)
          .neq("user_id", user.id);
        if (memberError) throw new Error("Could not check group members: " + memberError.message);
        recipientIds = (members || []).map((row) => String(row.user_id));
      } else {
        recipientIds = [conversation.buyer_id, conversation.seller_id].filter((id) => id && id !== user.id);
      }
      recipientIds = [...new Set(recipientIds)];
      if (!recipientIds.length) return response(200, { ok: true, skipped: "no_recipients" }, siteUrl.origin);

      const { data: preferences, error: preferenceError } = await adminClient.from("seller_chat_preferences")
        .select("user_id,is_muted,mute_until")
        .eq("conversation_id", conversation.id)
        .in("user_id", recipientIds);
      if (preferenceError) throw new Error("Could not check chat notification settings: " + preferenceError.message);
      const now = Date.now();
      const muted = new Set((preferences || []).filter((pref) =>
        pref.is_muted && (!pref.mute_until || new Date(pref.mute_until).getTime() > now)
      ).map((pref) => String(pref.user_id)));
      recipientIds = recipientIds.filter((id) => !muted.has(id));
      if (!recipientIds.length) return response(200, { ok: true, skipped: "muted" }, siteUrl.origin);

      const { data: subscriptions, error: subscriptionError } = await adminClient.from("alee_push_subscriptions")
        .select("subscription_id")
        .in("user_id", recipientIds);
      if (subscriptionError) throw new Error("Could not find subscribed devices: " + subscriptionError.message);
      const subscriptionIds = [...new Set((subscriptions || []).map((row) => String(row.subscription_id)))];
      if (!subscriptionIds.length) return response(200, { ok: true, skipped: "no_subscribed_devices" }, siteUrl.origin);

      const reserve = await adminClient.from("alee_chat_push_dispatches")
        .insert({ message_id: messageId, status: "sending" });
      if (reserve.error?.code === "23505") return response(200, { ok: true, skipped: "already_sent" }, siteUrl.origin);
      if (reserve.error) throw new Error("Could not reserve this chat notification: " + reserve.error.message);

      const chatUrl = new URL("index.html", siteUrl);
      chatUrl.searchParams.set("openChat", String(conversation.id));
      try {
        const sent = await sendOneSignal({
          include_subscription_ids: subscriptionIds,
          headings: { en: "ALEE" },
          contents: { en: "You have a new message from a shop." },
          url: chatUrl.href,
          data: { type: "chat", conversationId: String(conversation.id) },
        });
        await adminClient.from("alee_chat_push_dispatches").update({
          status: sent.id ? "sent" : "skipped",
          onesignal_message_id: sent.id || null,
          updated_at: new Date().toISOString(),
        }).eq("message_id", messageId);
        return response(200, { ok: true, id: sent.id || null, recipients: sent.recipients ?? null }, siteUrl.origin);
      } catch (error) {
        await adminClient.from("alee_chat_push_dispatches").delete().eq("message_id", messageId);
        throw error;
      }
    }

    return response(400, { error: "Unknown notification action." }, siteUrl.origin);
  } catch (error) {
    console.error("ALEE push error:", error);
    return response(500, { error: (error as Error)?.message || "Could not send the notification." }, siteUrl.origin);
  }
});
