# Memory Index

- [CI/CD failures 2026-07](ci-cd-failures-2026-07.md) — why every workflow was failing: local_auth API drift, release.yml stale Flutter 3.27, missing setup-flutter composite action, real formatters test mismatch (merge itself was fine)
- [microflow release command quirks](release-command-quirks.md) — what `microflow release` does step by step and where it bites (`git add .`, silent tag overwrite, live DB push, interactive prompt)
- [My nickname](my-nickname.md) — Sayan calls me "buddy"; conversational nickname, not a functional rename
- [Relationship & tone](relationship-tone.md) — bros, not agent/user: casual, never sugarcoat, always give the real/better solution
- [Beta customer: FUTURE MICROFINANCE](beta-customer-future-microfinance.md) — first paid MFI, ₹12K lifetime (outlier), 46 members / 4,550 savings rows, 0 staff
- [Remotion video project 2026-07-18](remotion-video-project-2026-07-18.md) — exec-admin org setup tutorial video: Remotion 4.0.491, 9 scenes, Pixel 7 portrait mockup, sequential typing animations, confetti/sparkle effects, exact Flutter app design match, Studio at localhost:3000
- [Remotion hooks rules learned](remotion-hooks-rules-learned.md) — never call hooks after early return; `useMemo`/`useState`/`useEffect` must run unconditionally; use simple variables for one-off computed values in render
- [Remotion render timeout handling](remotion-render-timeout-handling.md) — full 3150-frame render gets killed by harness timeout; use detached background render or shorter test renders; verify with `remotion still` for individual frames
- [Target Audience & Buyer Persona](target-audience-money-lender.md) — complete profile of local money-lending audience (sahukars, 28-40yo), Khatabook gap, pain points, security fears, dialect, and conversion strategy

---

## 2026-07-20 04:30 — MicroFlow FB Branding Prompts & Bengali Marketing Campaign
- **What:** Designed complete marketing suite for MicroFlow Pro targeting individual money-lenders in West Bengal. Includes 5-Act Google Veo 3.1 video ad spec (narrator "Siddharth Da", Kolkata dialect, exact Flutter UI workflow), WhatsApp lead copy (`+91 9733657929`), Amazon-style logo prompts, and fully customized Facebook Cover Photo prompts with all text, tagline, and WhatsApp CTA rendered directly in AI image generation.
- **Files created/modified:** `videos/microflow-product/BENGALI_SCRIPT.md` (updated master spec), `memory/target-audience-money-lender.md` (new dedicated audience memory file).
- **Next:** Sayan to copy-paste prompts into Google Imagen 3 / Midjourney for instant FB Cover & Logo, and render Veo 3.1 video clips.
