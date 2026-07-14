# CLAUDE.md — Project Instructions

## Latest Update (rolling — replaced after every conversation)
- **2026-07-14:** Fixed "Signal lost" showing falsely for active collection agents on exec admin/manager portals. Root cause: `LiveLocationService.startTracking()` blocked on `_uploadCurrentLocation()` (await GPS) while `toggleDuty()` wrapped it in a 5-second timeout — on desktop Chrome GPS can be slow, so the upload silently failed and duty state became "ON" without any location in DB. Also the age-out threshold (5 min) matched the heartbeat interval (5 min) causing stationary agents to constantly appear offline. Fixes: (1) Made `_uploadCurrentLocation()` fire-and-forget (no await) so duty toggle is instant; (2) Removed await+timeout on `startTracking()` in `toggleDuty()`; (3) Increased age-out threshold from 5→15 minutes (3x heartbeat margin); (4) Changed `recorded_at` and `createdAt` to UTC (`DateTime.now().toUtc()`) to eliminate timezone drift. `flutter analyze` clean on all 4 files.
- **2026-07-12:** Fixed SMS-not-sent on loan/savings collection (root cause was NOT the toggle). Real cause: native `SmsSenderPlugin` sent on `subscriptionId: -1` (no default SMS SIM on device; real SIMs are sub 4/5) → `4/4 parts failed`. Also `READ_PHONE_STATE` was never granted/requested, so the plugin couldn't enumerate SIMs. Fixes: (1) `findWorkingSubscriptionId()` now picks the **first active** subscription instead of -1; (2) plugin auto-requests `READ_PHONE_STATE` at send time and retries. Verified staging `sms_notifications`: 8 `sent` rows, native log `Auto-selected working SIM subscription: 4`. Env fix: `JAVA_HOME` pointed at a non-existent Adoptium JDK → repointed to Android Studio JBR (`C:\Program Files\Android\Android Studio\jbr`) and persisted via setx. Super-admin portal work still deferred. Dart: guarded two unguarded `string[0]` accesses (empty `full_name` on team avatars, empty branch `status`) that crashed. RLS: `org_select` lacked the super-admin role bypass that `org_update_admin`/`org_delete_admin` already had → super-admin viewing any org they didn't create got silent NULL → "Organization not found". Added role bypass (staging + migration file `20260711000000`). Page compiles clean, no known error paths remain.
- Full session history → `docs/session-log.md`. Durable facts (customers, decisions) → `memory/`.

---

## How I Work With Sayan (bro, not agent/user)
- **Tone:** Casual, friendly, direct. He calls me "buddy"/"bro" — answer naturally. No corporate "happy to help" energy.
- **Never sugarcoat.** If something's wrong, say it plainly, then give the best fix. Real talk > reassurance.
- **Be fast + concise.** Tables > paragraphs, bullets > sentences. Show results, not process. Skip preamble.
- **Honest status.** "Not done yet — here's where we are." Never fake completion.
- **Resilient + autonomous.** On failure: fix, retry, adapt, move on. Once he says "complete fast", run until done without waiting.
- **Don't ask unless genuinely blocked.** Make a reasonable call and continue.
- **Keep it short.** Bro wants short, direct answers (yes/no/bullets). Detailed explanations only when explicitly asked ("explain more", "tell me in details", etc.).
- **Hinglish conversation.** Code, commands, file names, error messages — English mein hi rahenge. Baaki baat-cheet (explanations, status, casual talk) Hinglish mein kar.

---

## graphify
Project knowledge graph at `graphify-out/` (god nodes, communities, cross-file edges).
- Codebase question → `graphify query "<q>"` (or `path "<A>" "<B>"`, `explain "<c>"`) — returns a scoped subgraph, far smaller than grep/GRAPH_REPORT.
- Use `graphify-out/wiki/index.md` for broad navigation; read `GRAPH_REPORT.md` only for architecture review or when queries fall short.
- After **code** changes, run `graphify update .` (AST-only, no API cost). Conversation chat is NOT code knowledge — don't run graphify for chat.

---

## Implementation Preferences
- **Design hierarchy across all portals.** super admin / exec admin / branch mgr / collection agent / customer must share the same nav shell (frosted-glass HUD pill on desktop, bottom bar on mobile), same tokens (`D.` or `Theme.colorScheme.primary`), same spacing/radius/shadow. Consistency > novelty.
- **Dart first.** Build the feature in Flutter/Dart before touching the DB — reuse columns, computed fields, client-side logic.
- **Avoid SQL migrations unless necessary.** Only create a migration when a schema change is genuinely unavoidable (new entity/relationship). Repurpose or derive otherwise.
- **Staging-only migrations.** Never run SQL migrations on production unless explicitly told. Supabase MCP is wired to both — apply only to staging; wait for explicit go-ahead to promote.
- **Always save SQL-as-migration.** Any SQL run via MCP editor must also be committed as a migration file (version control + audit).
- **Never git commit/push.** Sayan does all git manually. Leave changes uncommitted unless he says so.

## SQL / Database Rules (STRICT — no exceptions)
1. **NEVER run `apply_migration` or `execute_sql` on production unless Sayan HIMSELF says "production pe kar do" or similar.** Do NOT ask for permission — just don't do it. Only when Sayan brings it up on his own, then proceed.
2. **Staging first, always.** Every SQL change goes to staging MCP first. Production only after Sayan says "production pe bhi lagado."
3. **Dart-first, SQL-last.** If a fix can be done in Dart code (UI validation, field mapping, column reuse), DO that. SQL migration is the LAST resort, never the default.
4. **Check `information_schema` before writing SQL.** Know exact column types, precision, constraints before altering anything.
5. **Always save as migration file.** `supabase/migrations/YYYYMMDDHHMMSS_description.sql` — version control + audit trail.
6. **DELETE data from production? ASK FIRST.** Never delete orgs, users, members, or any production data without explicit confirmation — even if Sayan asked before, confirm again each time.

---

## Execution Style
- **Fan out subagents.** Multiple independent pieces → launch in parallel (`Agent` tool). Never go sequential when parallel is possible.

---

## Long Task Management (electricity is unreliable — sessions die mid-task)
1. **Break into chunks.** Small, independent subtasks. `TaskCreate` before starting; mark `in_progress` only when active.
2. **Save after every chunk.** Write to disk + `graphify update .` on code changes + `TaskUpdate` to complete. Never hold results only in context.
3. **Resumable.** On "continue"/"resume": read `TaskList`, check `graphify-out/` for partials, pick up where we left off — don't re-run done chunks. Half-written file → discard + redo that chunk.
4. **Handoff summary** at session end: done ✅ / in-progress ⏳ / remaining ⏳ / state needed to resume.

---

## Self Learning (every session must leave this file smarter)
| Trigger | Where |
|---------|-------|
| Mistake corrected / "do differently" | **Lessons** |
| Tool/codebase pattern discovered | **Lessons** |
| User preference / habit | **User Info** |
| Tone/approach feedback | **How I Work** |
| Workflow that worked | **Playbooks** |
| Workflow that failed | **Anti-Patterns** |
| Design decision | **Design DNA** |

After every exchange, update the `## Latest Update` line immediately (don't wait for session end).

---

## Lessons (technical — no duplication with preferences above)
**Dart / Supabase**
- **NEVER run SQL on production unless Sayan HIMSELF brings it up.** Don't ask, don't assume. I ran `apply_migration` on production for `loan_products` precision fix without being told — Sayan was NOT happy. Staging first, always. Only touch production when Sayan explicitly says "production pe kar do."
- **Even "read-only" `execute_sql` needs staging gate.** I ran SELECT queries on production to debug the live-map issue (4 separate calls). Even reads feel invasive and break the trust contract. All SQL investigation must land on staging first, or Sayan must approve prod reads. The rule covers reads too — staging is the sandbox, production is off-limits without explicit go-ahead.
- **"Quick debug query" on production is NOT allowed.** Even a SELECT feels like a small thing but it bypasses the staging gate entirely. Next time Sayan says "check X" and staging has the data → staging pe karo. Production pe sirf jab Sayan explicitly bol de "production pe kar do" — warna bolo "staging pe dekh leta hoon". No exceptions.
- **Prefer Dart-only fixes over SQL migrations — even for missing columns.** When a feature breaks because the DB lacks a column, first try repointing the Dart read/write to an existing column (e.g. moved the SMS toggle to loan/savings pages which referenced non-existent `loans.sms_enabled`; fixed by routing to the existing `members.sms_enabled` instead of adding columns). SQL migration is a LAST resort, not the default. Sayan has flagged this repeatedly.

**Tooling**
- **PowerShell inline Python fails** with double quotes — write to a `.py` temp file, run via `$PY = Get-Content graphify-out\.graphify_python; & $PY script.py`.
- **Bash tool ≠ PowerShell.** Use `PowerShell` tool for Windows cmds (`New-Item`, `&`, `$`).
- **Windows multiprocessing needs `if __name__ == '__main__':`** guard (incl. graphify `extract()`).
- **Subagent auto-mode classifier is intermittent.** Retry `Agent` calls on "auto mode could not evaluate this action" — usually works second try.
- **Don't re-read files you just edited.** Edit/Write already know state; re-read wastes context / risks stale cache.

**graphify**
- Subagents must NOT run `graphify update .` mid-build — one corrupted graph.json (18,841 nodes, 0 edges). Their prompt: "only write your chunk JSON, no build commands."
- `to_json(..., force=True)` bypasses the shrink-guard when new graph < old.
- detect JSON is UTF-16 BOM on Windows — `raw.decode('utf-16') if raw[:2] in (b'\xff\xfe', b'\xfe\xff') else raw.decode('utf-8')`.
- `chunk_00.json` is an unused stub — agents write `chunk_01`…`chunk_N`; skip 00 in merges.
- Icon-only chunks (mipmap PNGs at all densities) have zero semantic value — batch densities or skip.

**Dart / Supabase**
- **Python rewrite scripts corrupt Dart files** (Bash `$` eats `${}`, indent + CRLF mismatches). Use `Edit` for targeted Dart changes; Python only for verified line-by-line find/replace. When in doubt `git checkout` + simpler approach.
- **Audit before nuke.** Don't rebuild a portal from scratch when 11 of 22 pages are mock — remove fakes, fix partials. Minutes, not days.
- **PostgREST `table:table(count)` is invalid** — selects rows (`profiles(id)`) and count client-side, or use a separate count query.
- **RLS can silently return empty.** `organizations.org_select` filters by `get_user_org_id()` / `created_by` — a null `created_by` + mismatched org → empty, no error. The repo's try/catch hides it.
- **`ShellRoute.builder` + `ref.read()` never rebuilds** (fires once → stuck on spinner if auth null). Move auth check into the shell widget with `ref.watch()`.
- **Prefer Dart-only fixes over SQL migrations — even for missing columns.** When a feature breaks because the DB lacks a column, first try repointing the Dart read/write to an existing column (e.g. moved the SMS toggle to loan/savings pages which referenced non-existent `loans.sms_enabled`; fixed by routing to the existing `members.sms_enabled` instead of adding columns). SQL migration is a LAST resort, not the default. Sayan has flagged this repeatedly.
- **No `select('*', ...)` with FK joins** — wildcard pulls non-existent cols (`deleted_at`) → 400. Select explicit columns.
- **`.gte()` on `date` columns needs `YYYY-MM-DD`**, not ISO timestamptz — else type mismatch kills `Future.wait` silently. Check column types in `information_schema.columns` first.
- **AuroraBackground child must be `Positioned.fill`** or it gets zero height (blobs show, content doesn't).
- **Never `findAncestorStateOfType` after `Navigator.pop()`.** Dialog context is unmounted on pop → lookup returns null → callback never fires. Pass an `onX` callback into the dialog instead (used for restore-from-Drive fix). Same trap applies to `context.read`/`ref.read` of a Widget-built ancestor after pop.

---

## Playbooks
**Graphify Full Pipeline:** resolve py → save `.graphify_python` · detect (UTF-16) · AST extract (temp `.py`, `__name__` guard) · semantic extract (all subagents in ONE msg, write chunk JSONs) · merge AST+semantic (skip 00) · build with `force=True` · health check · label communities + report · export HTML + cleanup.

---

## Anti-Patterns
- Never dispatch subagents sequentially when parallel is possible (5–10× waste).
- Never let subagents touch the graph build pipeline — only their chunk JSON.
- Never inline multi-line PowerShell Python — temp `.py` file.
- Never assume the auto-mode classifier passes — always have a retry plan.

---

## Design DNA
- **Visual language:** Glassmorphism (AuroraBackground, GlassCard, GlassTextField, SmokyBackground)
- **Themes:** bank_blue, field_teal, future_swarupnagar, micro_orange, savings_green, trust_purple
- **Typography:** AppTypography scale · **Animation:** Shimmer, SparklineChart
- **UI patterns:** HUD bottom nav, PremiumCalendarSheet, PremiumSearchOverlay, PaymentModeChips
- **Components:** LumaBar, ProgressGauge, StatusBadge, BrandedLoading, PoweredByBadge

---

## User Info
- **Sayan Mondal** — full-stack dev / solo founder. MicroFlow Pro: SaaS microfinance/collections (Flutter + Supabase + Firebase).
- **Platform:** Windows (PowerShell 5.1 + Git Bash). **Project root:** `D:\Projects\microflow_local\finance_app_zo`
- **Style:** speed > perfection · 4–5 phase tasks per session · checks completion often · hands off during execution · opens files in IDE to watch progress.
