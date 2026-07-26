# Bengali Facebook Content Creation — Day 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create first batch of Bengali Facebook organic content (30-day calendar + 20 reel scripts + templates) and optionally set up n8n scheduling workflow.

**Architecture:** Content-first approach — create all assets, then optionally set up n8n pipeline. All under `marketing/bengali-facebook/` directory.

**Tech Stack:** Markdown, Bengali (Bangla), Facebook, optional n8n

**CTA Strategy:** Comment "খাতা" → DM → WhatsApp demo

## Global Constraints
- All reels under 25 seconds max
- Bengali language (pure Bangla, Hinglish only where natural for younger audience)
- No generic SaaS/CRM/automation words
- MicroFlow positioned as: সুদের ব্যবসা, সঞ্চয় আর আদায়ের খাস ডিজিটাল খাতা
- Trust line every 3-4 reels: "আপনার হিসাব শুধু আপনার কাছেই থাকবে।"
- Legal-safe: record-keeping tool description, not lending/verification claims

---

### Task 1: 30-Day Bengali Content Calendar

**Files:**
- Create: `marketing/bengali-facebook/content-calendar-30.md`

**Interface:**
- Consumes: Approved strategy spec at `docs/superpowers/specs/2026-07-26-bengali-facebook-organic-strategy-design.md`
- Produces: Markdown table with Date/Week, Day, Content Pillar, Hook, CTA, Content Type

- [ ] Step 1: Write the 30-day calendar content

Structure:
| Day | Week | Content Pillar | Hook (Bengali) | CTA | Post Type | Notes |
|-----|------|---------------|----------------|-----|-----------|-------|
| Mon 1 | Wk 1 | Pain | "আজ কার কিস্তির তারিখ ছিল?" | কমেন্টে লিখুন "খাতা" | Reel | 25s |
| Tue 2 | Wk 1 | Education | "সুদের ব্যবসায় ৩টা হিসাব আলাদা রাখতেই হবে" | সেভ করুন | Carousel | |
| Wed 3 | Wk 1 | Solution | "এই ৩টা হিসাব MicroFlow এক জায়গায় দেখায়" | কমেন্টে লিখুন "খাতা" | Reel | 25s |
| Thu 4 | Wk 1 | Trust | "আপনার হিসাব শুধু আপনার কাছেই থাকবে" | শেয়ার করুন | Post | |
| Fri 5 | Wk 1 | CTA | "ডেমো চাইলে কমেন্টে লিখুন খাতা" | লিখুন "খাতা" | Reel | 25s |

...rest 25 days

- [ ] Step 2: Add weekly theme labels
    - Week 1-2: "Problem Awareness"
    - Week 3-4: "Trust + Solution"
    - Week 5: "Conversion + Social Proof"

- [ ] Step 3: Add festive/regional tie-ins for upcoming dates
    - Durga Pujo timing
    - Local market days
    - Poila Boisakh

- [ ] Step 4: Verify complete coverage
    - Check: each week has 1-2 pain reels, 1-2 solution reels
    - Check: trust line appears every 3-4 posts
    - Check: no two adjacent posts same pillar

---

### Task 2: 20 Bengali Reel Scripts (max 25 seconds each)

**Files:**
- Create: `marketing/bengali-facebook/reel-scripts-20.md`

**Interfaces:**
- Consumes: Content calendar hooks from Task 1
- Produces: 20 complete reel scripts with hook, body, CTA, visual note

- [ ] Step 1: Write 20 reel scripts

Each script structure:
```
## Script N: [Hook Line]

**Hook (0-3s):** [painful question]
**Body (3-15s):** [one concrete problem]
**Solution (15-21s):** [MicroFlow as fix]
**CTA (21-25s):** কমেন্টে লিখুন "খাতা"

**On-screen text:** [Bengali captions for video overlay]
**Visual idea:** [brief visual description]
**Caption copy:** [FB post caption below the reel]
```

Theme distribution:
- Week 1-2 (Problem Awareness): 8 scripts
  - 4 pain hooks (no notebook, missed collection, lost records, manual calculation)
  - 2 education hooks (tips for better tracking)
  - 2 solution hooks (MicroFlow as answer)
- Week 3-4 (Trust + Solution): 7 scripts
  - 2 trust hooks (privacy, security)
  - 3 solution hooks (SMS, PDF, savings module)
  - 2 CTA hooks (demo request, comment-first)
- Week 5 (Conversion): 5 scripts
  - 2 social proof hooks (real user scenarios)
  - 2 urgency hooks (signup, free start)
  - 1 bonus: festive tie-in (Durga Pujo)

- [ ] Step 2: Time-check each script for 25-second limit
    - Read aloud timing: ~3 words per second
    - Max 60-65 Bengali words per script
    - Cut any script exceeding limit

- [ ] Step 3: Verify Bengali is natural and local
    - Check: no English corporate/buzzwords
    - Check: using "দাদা" sporadically, not every script
    - Check: familiar words (খাতা, বাকি টাকা, কিস্তি, সঞ্চয়, আদায়, SMS, PDF)

---

### Task 3: Bengali Caption & CTA Templates

**Files:**
- Create: `marketing/bengali-facebook/captions-and-cta-templates.md`

**Interfaces:**
- Consumes: Reel scripts from Task 2, calendar from Task 1
- Produces: Reusable caption templates + hashtags per pillar

- [ ] Step 1: Write reusable caption templates per pillar

```
Pain post caption:
[hook question] 🤔
↓
আপনার খাতায় কি এই সমস্যা হয়?
মন্তব্যে জানান 👇

#MicroflowPro [pillar hashtag]

Education post caption:
[tip] 💡
↓
একটি জিনিস আজ থেকে বদলান।
বাকিটা মাইক্রোফ্লো দেখবে।

CTA post caption:
ডেমো চাইলে কমেন্টে লিখুন "খাতা" 📱
↓
আমরা ডিএম করবো।
```

- [ ] Step 2: Write Bengali hashtag sets (primary + secondary + avoid-list)
- [ ] Step 3: Write Bengali comment reply templates
    - Template for "what is this"
    - Template for "is my data safe"
    - Template for "pricing"
    - Template for "direct inquiries"
    - Template for generic curiosity

---

### Task 4: DM-to-WhatsApp Conversion Templates

**Files:**
- Create: `marketing/bengali-facebook/dm-whatsapp-templates.md`

- [ ] Step 1: Write DM opening templates
    - Initial DM when user comments "খাতা"
    - Follow-up if no reply in 6 hours
    - Follow-up if no reply in 24 hours

- [ ] Step 2: Write WhatsApp call script
    - Opening message
    - Demo scheduling
    - Follow-up after demo

---

### Task 5 (Optional): n8n Workflow for Content Pipeline

**Files:**
- Create: `marketing/bengali-facebook/n8n-workflow-spec.md`

- [ ] Step 1: Design n8n workflow structure
    - Schedule trigger (weekly)
    - Generate content with Claude API / static queue
    - Save to Google Sheet / Notion
    - Send draft to WhatsApp/Telegram for approval

- [ ] Step 2: Document Facebook Graph API setup
    - Step-by-step: developer account → app → token
    - Long-lived token generation
    - n8n HTTP Request node config

- [ ] Step 3: Write n8n workflow JSON (exportable)
    - Trigger: Every Sunday 9 PM
    - Nodes: Schedule → HTTP Request (Claude API) → Google Sheets → WhatsApp → End

---
