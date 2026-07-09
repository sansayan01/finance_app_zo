import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface PushNotificationPayload {
  user_id?: string;
  customer_id?: string;
  staff_id?: string;
  org_id?: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
  token?: string; // Direct token for testing
}

// ---------------------------------------------------------------------------
// Firebase access token (FCM HTTP v1) via service-account JWT (RS256)
// ---------------------------------------------------------------------------

function base64urlFromString(input: string): string {
  return btoa(input)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function base64urlFromBytes(bytes: ArrayBuffer): string {
  const arr = new Uint8Array(bytes);
  let binary = "";
  for (const b of arr) binary += String.fromCharCode(b);
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function pemToBytes(pem: string): Uint8Array {
  const b64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

async function getFirebaseAccessToken(): Promise<string | null> {
  const saRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_KEY");
  if (!saRaw) {
    console.error("FIREBASE_SERVICE_ACCOUNT_KEY not configured");
    return null;
  }

  let serviceAccount: any;
  try {
    serviceAccount = JSON.parse(saRaw);
  } catch {
    console.error("FIREBASE_SERVICE_ACCOUNT_KEY is not valid JSON");
    return null;
  }

  const projectId: string | undefined = serviceAccount.project_id;
  if (!projectId) {
    console.error("service account missing project_id");
    return null;
  }

  const privateKey = (serviceAccount.private_key as string).replace(/\\n/g, "\n");
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const input = `${base64urlFromString(JSON.stringify(header))}.${base64urlFromString(
    JSON.stringify(payload)
  )}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBytes(privateKey),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(input)
  );

  const jwt = `${input}.${base64urlFromBytes(signature)}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }).toString(),
  });

  const tokenJson = await tokenRes.json();
  if (!tokenJson.access_token) {
    console.error("Failed to obtain Firebase access token", tokenJson);
    return null;
  }

  return tokenJson.access_token as string;
}

// ---------------------------------------------------------------------------
// FCM send (HTTP v1)
// ---------------------------------------------------------------------------

async function sendFcmMessage(
  token: string,
  title: string,
  body: string,
  data?: Record<string, unknown>
): Promise<{ success: boolean; error?: string }> {
  const accessToken = await getFirebaseAccessToken();
  if (!accessToken) {
    return { success: false, error: "Firebase credentials not configured" };
  }

  const projectId = JSON.parse(
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT_KEY") ?? "{}"
  ).project_id;

  if (!projectId) {
    return { success: false, error: "Firebase project_id not configured" };
  }

  try {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data: data
              ? Object.fromEntries(
                  Object.entries(data).map(([k, v]) => [k, String(v)])
                )
              : undefined,
            android: {
              priority: "high",
              notification: {
                channel_id: "push_notifications",
                sound: "default",
              },
            },
            apns: {
              payload: {
                aps: { sound: "default", badge: 1 },
              },
            },
          },
        }),
      }
    );

    const result = await response.json();

    if (!response.ok) {
      console.error("FCM error:", result);
      return {
        success: false,
        error: result?.error?.message || "FCM request failed",
      };
    }

    return { success: true };
  } catch (error) {
    console.error("FCM send error:", error);
    return { success: false, error: String(error) };
  }
}

// ---------------------------------------------------------------------------
// Token resolution
// ---------------------------------------------------------------------------

async function getTokensByField(
  supabase: ReturnType<typeof createClient>,
  field: string,
  value: string
): Promise<string[]> {
  const { data } = await supabase
    .from("device_tokens")
    .select("fcm_token")
    .eq(field, value)
    .eq("is_active", true);
  return data?.map((t: any) => t.fcm_token) ?? [];
}

async function resolveTokens(
  supabase: ReturnType<typeof createClient>,
  payload: PushNotificationPayload
): Promise<string[]> {
  if (payload.token) return [payload.token];

  if (payload.user_id) {
    return getTokensByField(supabase, "user_id", payload.user_id);
  }

  if (payload.customer_id) {
    const { data: member } = await supabase
      .from("members")
      .select("profile_id")
      .eq("id", payload.customer_id)
      .maybeSingle();
    if (!member?.profile_id) return [];
    const { data: profile } = await supabase
      .from("profiles")
      .select("user_id")
      .eq("id", member.profile_id)
      .maybeSingle();
    if (!profile?.user_id) return [];
    return getTokensByField(supabase, "user_id", profile.user_id);
  }

  if (payload.staff_id) {
    const { data: staff } = await supabase
      .from("staff_profiles")
      .select("user_id")
      .eq("id", payload.staff_id)
      .maybeSingle();
    if (!staff?.user_id) return [];
    return getTokensByField(supabase, "user_id", staff.user_id);
  }

  if (payload.org_id) {
    return getTokensByField(supabase, "org_id", payload.org_id);
  }

  return [];
}

// ---------------------------------------------------------------------------
// Cleanup invalid tokens
// ---------------------------------------------------------------------------

async function cleanupTokens(
  supabase: ReturnType<typeof createClient>,
  invalidTokens: string[]
): Promise<void> {
  if (invalidTokens.length === 0) return;
  try {
    await supabase
      .from("device_tokens")
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .in("fcm_token", invalidTokens);
    console.log(`Cleaned up ${invalidTokens.length} invalid tokens`);
  } catch (error) {
    console.error("Token cleanup error:", error);
  }
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: PushNotificationPayload = await req.json();
    const { user_id, customer_id, staff_id, org_id, title, body, data, token } =
      payload;

    if (!title || !body) {
      return new Response(
        JSON.stringify({ error: "title and body are required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const tokens = await resolveTokens(supabase, {
      user_id,
      customer_id,
      staff_id,
      org_id,
      token,
    });

    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "No active devices found",
          sent: 0,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const invalidTokens: string[] = [];
    let sentCount = 0;
    let failedCount = 0;

    await Promise.allSettled(
      tokens.map(async (t) => {
        const result = await sendFcmMessage(t, title, body, data);
        if (result.success) {
          sentCount++;
        } else {
          failedCount++;
          if (
            result.error?.includes("InvalidToken") ||
            result.error?.includes("registration_token_not_registered") ||
            result.error?.includes("UNREGISTERED")
          ) {
            invalidTokens.push(t);
          }
        }
      })
    );

    await cleanupTokens(supabase, invalidTokens);

    console.log(
      `Push notifications: ${sentCount} sent, ${failedCount} failed, ${invalidTokens.length} tokens cleaned up`
    );

    return new Response(
      JSON.stringify({
        success: true,
        sent: sentCount,
        failed: failedCount,
        cleanedUp: invalidTokens.length,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Push notification error:", error);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
