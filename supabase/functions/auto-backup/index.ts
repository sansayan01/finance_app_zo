import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// All backup tables in foreign-key order
const BACKUP_TABLES = [
  "profiles", "branches", "org_branding",
  "members", "loans", "emi_schedule", "savings", "savings_plans",
  "transactions", "collections", "savings_collections", "cash_deposits", "wallet_transactions",
  "staff_profiles", "activity_logs", "visit_logs", "staff_streaks", "achievements", "offline_sync_queue",
];

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Use service_role to bypass RLS
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Google Drive credentials (from Edge Function secrets)
    const googleClientId = Deno.env.get("GOOGLE_WEB_CLIENT_ID")!;
    const googleClientSecret = Deno.env.get("GOOGLE_WEB_CLIENT_SECRET")!;

    // 1. Find all orgs with auto-backup enabled
    const { data: orgs, error: orgError } = await supabase
      .from("organizations")
      .select("id, name, settings")
      .not("settings->>backup_schedule", "is", null);

    if (orgError) throw new Error(`Failed to fetch orgs: ${orgError.message}`);
    if (!orgs || orgs.length === 0) {
      return new Response(
        JSON.stringify({ message: "No orgs with auto-backup configured" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const results: Array<{ orgId: string; orgName: string; status: string; error?: string }> = [];

    for (const org of orgs) {
      const schedule = (org.settings as any)?.backup_schedule;
      if (!schedule?.enabled) continue;

      // Check if this org needs a backup right now (based on frequency + time)
      if (!shouldBackupNow(schedule)) continue;

      const driveConnection = (org.settings as any)?.google_drive;
      if (!driveConnection?.connected || !driveConnection?.refresh_token) {
        results.push({ orgId: org.id, orgName: org.name, status: "skipped", error: "Drive not connected" });
        continue;
      }

      try {
        // 2. Get fresh access token
        const accessToken = await refreshAccessToken(
          googleClientId, googleClientSecret, driveConnection.refresh_token
        );

        // 3. Fetch all table data
        const categoryData: Record<string, any[]> = {};
        for (const table of BACKUP_TABLES) {
          const { data } = await supabase.from(table).select("*").eq("org_id", org.id).limit(50000);
          categoryData[table] = data || [];
        }

        // 4. Build JSON payload
        const totalRecords = Object.values(categoryData).reduce((sum, rows) => sum + rows.length, 0);
        const rowCounts: Record<string, number> = {};
        for (const [key, rows] of Object.entries(categoryData)) {
          rowCounts[key] = rows.length;
        }

        const payload = {
          metadata: {
            org_id: org.id,
            org_name: org.name,
            generated_at: new Date().toISOString(),
            app_version: "auto-backup",
            total_records: totalRecords,
            categories: rowCounts,
            schema_version: "1.0",
            automated: true,
          },
          data: categoryData,
        };

        // 5. Upload to Google Drive
        const uploadResult = await uploadToDrive(accessToken, driveConnection.folder_id, org.name, payload);

        // 6. Record in data_exports
        await supabase.from("data_exports").insert({
          org_id: org.id,
          type: "auto_backup",
          format: "json",
          filters: {
            categories: Object.keys(categoryData),
            total_records: totalRecords,
            file_id: uploadResult.file_id,
            drive_url: uploadResult.drive_url,
            automated: true,
          },
          status: "completed",
        });

        // 7. Apply retention policy
        if (schedule.retention_enabled) {
          await applyRetention(accessToken, driveConnection.folder_id, schedule);
        }

        results.push({ orgId: org.id, orgName: org.name, status: "completed" });
      } catch (e) {
        // Record failure
        await supabase.from("data_exports").insert({
          org_id: org.id,
          type: "auto_backup",
          format: "json",
          filters: { error: String(e), automated: true },
          status: "failed",
        });

        results.push({ orgId: org.id, orgName: org.name, status: "failed", error: String(e) });
      }
    }

    return new Response(
      JSON.stringify({ results }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: "Internal error", message: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

// ── Helpers ──────────────────────────────────────────────────────────

function shouldBackupNow(schedule: any): boolean {
  const now = new Date();
  const frequency = schedule.frequency || "weekly";
  const targetHour = schedule.time_hour ?? 2;
  const targetMinute = schedule.time_minute ?? 0;

  // Check if current hour matches
  if (now.getHours() !== targetHour) return false;
  // Check if current minute is within the 59-minute window (cron runs hourly)
  if (now.getMinutes() !== targetMinute && now.getMinutes() !== targetMinute + 1) return false;

  switch (frequency) {
    case "daily":
      return true;
    case "weekly": {
      const targetDay = schedule.day_of_week ?? 1; // 1=Monday
      const currentDay = now.getDay() === 0 ? 7 : now.getDay(); // Convert Sun=0 to 7
      return currentDay === targetDay;
    }
    case "monthly": {
      return now.getDate() === 1; // First day of month
    }
    default:
      return false;
  }
}

async function refreshAccessToken(clientId: string, clientSecret: string, refreshToken: string): Promise<string> {
  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: "refresh_token",
      refresh_token: refreshToken,
    }).toString(),
  });

  if (!resp.ok) throw new Error(`Token refresh failed: ${resp.status}`);
  const data = await resp.json();
  return data.access_token;
}

async function uploadToDrive(
  accessToken: string,
  folderId: string,
  orgName: string,
  payload: any,
): Promise<{ file_id: string; drive_url: string }> {
  const safeName = orgName.replace(/[^a-zA-Z0-9]/g, "_");
  const timestamp = new Date().toISOString().replace(/[-:T]/g, "").slice(0, 15);
  const fileName = `${safeName}_auto_backup_${timestamp}.json`;
  const fileContent = new TextEncoder().encode(JSON.stringify(payload));

  const boundary = `boundary_${Date.now()}`;
  const metadata = JSON.stringify({ name: fileName, parents: [folderId], mimeType: "application/json" });

  const body = new TextEncoder().encode(
    `--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${metadata}\r\n` +
    `--${boundary}\r\nContent-Type: application/json\r\n\r\n${new TextDecoder().decode(fileContent)}\r\n` +
    `--${boundary}--\r\n`
  );

  const resp = await fetch("https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": `multipart/related; boundary=${boundary}`,
    },
    body,
  });

  if (!resp.ok) throw new Error(`Drive upload failed: ${resp.status}`);
  const result = await resp.json();
  return { file_id: result.id, drive_url: `https://drive.google.com/file/d/${result.id}/view` };
}

async function applyRetention(accessToken: string, folderId: string, schedule: any): Promise<void> {
  const mode = schedule.retention_mode || "count";
  const keepCount = schedule.retention_count ?? 10;
  const keepDays = schedule.retention_days ?? 30;

  // List all backups in folder
  const listResp = await fetch(
    `https://www.googleapis.com/drive/v3/files?q=${encodeURIComponent(
      `'${folderId}' in parents and trashed=false`
    )}&fields=files(id,name,createdTime)&orderBy=createdTime%20desc&pageSize=100`,
    { headers: { Authorization: `Bearer ${accessToken}` } }
  );

  if (!listResp.ok) return;
  const listData = await listResp.json();
  const files = listData.files || [];
  if (files.length === 0) return;

  let toDelete: string[] = [];

  if (mode === "count" && files.length > keepCount) {
    toDelete = files.slice(keepCount).map((f: any) => f.id);
  } else if (mode === "days") {
    const cutoff = new Date(Date.now() - keepDays * 86400000).toISOString();
    toDelete = files.filter((f: any) => f.createdTime < cutoff).map((f: any) => f.id);
  }

  for (const fileId of toDelete) {
    await fetch(`https://www.googleapis.com/drive/v3/files/${fileId}`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${accessToken}` },
    });
  }
}
