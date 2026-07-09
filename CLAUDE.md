# CLAUDE.md — Project Instructions

## graphify

This project has a knowledge graph at `graphify-out/` with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when `graphify-out/graph.json` exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than `GRAPH_REPORT.md` or raw grep output.
- If `graphify-out/wiki/index.md` exists, use it for broad navigation instead of raw source browsing.
- Read `graphify-out/GRAPH_REPORT.md` only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

---

## Long Task Management

The user performs multi-step tasks (4–5+ phases) in a single session. Due to unreliable electricity, sessions can cut off mid-task. Follow these rules strictly:

### 1. Break Into Chunks
- Every long task MUST be broken into small, independent chunks (steps, phases, or subtasks).
- Create a task list via `TaskCreate` before starting. Mark each chunk `in_progress` only when actively working on it.

### 2. Save Progress After Every Chunk
- After completing **every chunk**, persist the result immediately:
  - Write to disk (files, configs, reports).
  - Run `graphify update .` after any code changes.
  - Commit if meaningful progress was made.
  - Update the task list (`TaskUpdate`) to mark completion.
- **Never hold results only in memory or agent context.** If the session dies mid-task, the completed chunks must be safe on disk.

### 3. Resumability
- When the user says **"continue"** or **"resume"**, check:
  1. Read the task list (`TaskList`) to find what was completed and what's pending.
  2. Check `graphify-out/` for any incomplete/partial files.
  3. Pick up exactly where the last chunk ended — do NOT re-run completed chunks.
- If a chunk is partially done (e.g., a file is half-written), discard the partial result and redo that chunk from scratch.

### 4. Session Handoff Summary
- If the session is about to end (user says bye, or a long idle timeout), print a summary:
  - What chunks are done ✅
  - What chunk is in progress ⏳
  - What chunks remain ⏳
  - Any files or state needed to resume

---

## Self Learning (Self-Improving System)

This CLAUDE.md is my **brain**. It evolves every single session. Every prompt, every mistake, every correction, every observation is a chance to become smarter. The rule is simple: **every session must leave this file slightly better than before.**

### What to update and when

| Trigger | Where | Example |
|---------|-------|---------|
| Mistake corrected by user | **Lessons** | "Don't use Bash for PowerShell commands" |
| User preference or habit revealed | **User Info** | "Prefers speed over explanation" |
| New codebase/tool pattern discovered | **Lessons** | "graphify detect uses UTF-16 on Windows" |
| User feedback on my tone or approach | **Behavior** | "User wants direct answers, not preamble" |
| A workflow that worked well | **Playbooks** | "Graphify pipeline: detect → AST → semantic → build" |
| A workflow that failed badly | **Anti-Patterns** | "Never let subagents run graphify update mid-build" |
| Design decision or preference noticed | **Design DNA** | "Glassmorphism is the visual language" |
| Something I'd do differently next time | **Lessons** | "Read chunk metadata before dispatching agents" |

**Rule:** Do NOT wait until session ends. Update immediately after the event.

---

## Lessons

- **PowerShell inline Python with double quotes fails.** Always write Python scripts to `.py` temp files and run via `$PY = Get-Content graphify-out\.graphify_python; & $PY script.py`. Never inline multi-line Python in PowerShell `-c "..."` with double quotes — escaping is broken.
- **Bash tool cannot run PowerShell.** Use the `PowerShell` tool for Windows commands. The Bash tool runs POSIX sh and fails on `New-Item`, `&`, `$` substitution, etc.
- **Windows multiprocessing requires `if __name__ == '__main__':` guard.** Any Python script using `multiprocessing` (including graphify's `extract()`) must wrap the entry point.
- **Subagent auto-mode classifier is intermittent.** If `Agent` calls fail with "auto mode could not evaluate this action", retry immediately. They usually succeed on retry.
- **Don't let subagents run `graphify update .` mid-build.** One subagent ran it during extraction and created a corrupt graph.json (18,841 nodes, 0 edges). Subagent prompts should include "Do NOT run graphify update or any build commands — only write your chunk JSON."
- **graphify `to_json` accepts `force=True`.** When the shrink-guard blocks (new graph < old graph), use `to_json(G, communities, path, force=True)` instead of trying internal `_write_graph_json`.
- **graphify detect JSON uses UTF-16 BOM on Windows.** Always read detect JSON with: `raw.decode('utf-16') if raw[:2] in (b'\xff\xfe', b'\xfe\xff') else raw.decode('utf-8')`.
- **Chunk 00 = unused stub.** The 0-indexed template `chunk_00.json` is never populated; agents write `chunk_01` through `chunk_N`. Skip chunk 00 in merges.
- **Icon-only chunks yield zero semantic value.** Android mipmap PNGs at different densities are identical content. Batch all densities of one icon into one chunk or skip semantic extraction for them entirely.
- **Don't re-read files you just edited.** Edit/Write already know the state. Re-reading wastes context and can trigger stale-cache issues.

---

## Playbooks

Proven workflows I can execute reliably. Update after each successful run.

### Graphify Full Pipeline
1. Step 1: Resolve Python interpreter, save to `.graphify_python`
2. Step 2: Detect files (handle UTF-16 on Windows)
3. Step 3a: AST extraction via temp `.py` file with `__name__` guard
4. Step 3b: Semantic extraction — dispatch all subagents in ONE message, write chunk JSONs
5. Step 3c: Merge AST + semantic (skip chunk_00)
6. Step 4: Build graph with `force=True` (shrink-guard workaround)
7. Step 4.5: Health check
8. Step 5: Label communities, regenerate report
9. Step 6: Export HTML, cleanup temp files

---

## Anti-Patterns

Things that went wrong — never repeat these.

- Never dispatch subagents sequentially when parallel is possible — it wastes 5-10x time.
- Never let subagents modify the graph build pipeline — they should only write their chunk JSON.
- Never use inline PowerShell Python for multi-line scripts — always write to temp `.py` file.
- Never assume auto-mode classifier will always pass — always have a retry plan for Agent calls.

---

## Behavior

How I should conduct myself in every session with Sayan.

- **Be direct.** No "Let me help you with that!" preamble. Just do the work.
- **Be honest about status.** If not done, say "Not done yet — here's where we are." Never fake completion.
- **Be fast.** Skip unnecessary explanations unless asked. Show results, not process.
- **Be resilient.** If something fails, fix it and continue. Don't stop and wait — retry, adapt, move on.
- **Be proactive.** Update CLAUDE.md, update task list, save progress — without being asked.
- **Be concise in output.** Tables > paragraphs. Bullet points > sentences. Show, don't tell.

---

## Design DNA

Visual and product design principles I've absorbed from working on MicroFlow Pro.

- **Visual language:** Glassmorphism (AuroraBackground, GlassCard, GlassTextField, SmokyBackground)
- **Color system:** Preset themes per org (bank_blue, field_teal, future_swarupnagar, micro_orange, savings_green, trust_purple)
- **Typography:** AppTypography defines the full type scale
- **Animation:** Shimmer loading states, SparklineChart for mini visualizations
- **UI pattern:** HUD bottom navigation, PremiumCalendarSheet, PremiumSearchOverlay, PaymentModeChips
- **Component library:** LumaBar, ProgressGauge, StatusBadge, BrandedLoading, PoweredByBadge

---

## User Info

Things I've learned about Sayan Mondal across sessions.

### Identity & Role
- **Name:** Sayan Mondal
- **Role:** Full-stack developer / solo founder
- **Project:** MicroFlow Pro — a SaaS microfinance/collections app (Flutter + Supabase + Firebase)
- **Platform:** Windows machine (PowerShell 5.1 + Git Bash)

### Work Style
- **Prefers speed over perfection.** Asked me to "complete fast" multiple times. Don't over-plan — just do the work.
- **Combines many steps into one session.** Runs 4–5 phase tasks in a single ask. Break them down and save after each chunk.
- **Checks completion frequently.** Will ask "did you complete?" — always give honest status, not reassurance.
- **Opens files in IDE while I work.** The file-open events in system reminders are him watching progress, not unrelated activity.
- **Hands off during execution.** Once he says "complete fast", he expects me to run autonomously until done.

### Environment Constraints
- **Unreliable electricity.** Sessions can cut off mid-task without warning. Everything must be saved to disk after every chunk.
- **Resumability is critical.** When he says "continue", pick up exactly where we left off — don't restart.
- **Project root:** `D:\Projects\microflow_local\finance_app_zo`

### Communication
- **Minimal prompts, maximal action.** He says "okay then complete fast" — he wants execution, not explanation.
- **Don't ask unless genuinely blocked.** Prefer making a reasonable choice and moving on over pausing for approval.
- **Values the CLAUDE.md as a living document.** Wants it to grow smarter every session — update it proactively.
- **Wants a self-improving system.** Every interaction should make me smarter — behavior, personality, design sense, decision-making. Not just technical lessons.
