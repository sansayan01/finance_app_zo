# India Money-Lender Compliance Brief — MicroFlow Pro

**General information. NOT legal advice. Speak to a qualified lawyer in each applicable state before relying on any of the following.**

---

## 1. For Sayan (One-Paragraph Bottom Line)

MicroFlow Pro is a **digital book-keeping tool** for individual local money-lenders tracking loans given to acquaintances on trust. The app itself is NOT a lending platform — it does not disburse funds, set interest rates, collect payments, or facilitate matches between lenders and borrowers. Under established intermediary/tool-provider principles, **the app provider faces low direct regulatory liability** for users' lending activities. However, state-level Money Lenders Acts vary: **all major states require anyone "in the business of money-lending" to register**, and most delegate an interest cap to a state Gazette notification (only Bihar fixes a % in the Act itself). Your users (individual lenders) could theoretically face legal exposure in those states if lending crosses a frequency/volume threshold. **The primary risk for MicroFlow is indirect** — a user who faces prosecution/loss may attempt to involve the app. Strong disclaimers + explicit "user bears sole responsibility" language in TOS is the practical safeguard. On data: the "personal/domestic" DPDP exemption likely does NOT cover commercial lending, so **MicroFlow as app provider IS a Data Fiduciary in scope** — but real-world enforcement risk today is low (hygiene-level: consent notice + secure cloud + breach readiness), not an imminent-raid risk. Minimize stored PII regardless.

---

## 2. Per-State Quick-Reference Table

> **IMPORTANT VERIFICATION NOTE — read this first.** The *numeric* maximum interest rate is **almost never written as a fixed % in the bare Act**. Nearly every Act delegates the cap to a **state-government Gazette notification** that changes over time. The only state with a fixed numeric cap in the bare Act text itself is **Bihar (12%/15%)**. Rajasthan, West Bengal, and MP use a *structural* cap ("interest recoverable shall not exceed the principal"). For Maharashtra, TN, Karnataka, UP, Gujarat, AP, Telangana the rate is set by notification — verify the **current** figure in that state's Gazette before relying on any number. The table below marks what is **verified** (traceable to Act text) vs. **unverified** (delegated to notification). Do NOT treat the % cells as settled law.

| State | Governing Act | Registration Required? | Interest Cap (verified vs. delegated) | Notes |
|-------|--------------|----------------------|--------------------------------------|-------|
| **Maharashtra** | Bombay Money-Lenders Act 1946 + Maharashtra Money-Lending (Regulation) Act 2014 | Yes — mandatory for money-lending business (verified Act names) | **Delegated** to state notification — no % in Act (UNVERIFIED exact rate) | License from District Registrar. Active urban enforcement. |
| **Tamil Nadu** | Tamil Nadu Money Lenders Act 1957 | **Yes — licence required** (verified) | **Delegated** to Govt notification (UNVERIFIED exact rate) | Strict licensing; fee ~₹100. Known for aggressive stance on exorbitant interest. |
| **Karnataka** | Karnataka Money Lenders Act 1961 (Act 12 of 1961) | Yes — mandatory (registration provisions) | **Delegated** — S.31 lets State fix max rate by notification (UNVERIFIED exact rate) | Registration with Deputy Commissioner. |
| **Uttar Pradesh** | U.P. Regulation of Money-Lending Act 1976 | Yes — registration provided for (S.7) | **Delegated** — S.7: State fixes max rate, no charging above it (UNVERIFIED exact rate) | Statute empowers notification of the cap. |
| **Gujarat** | Gujarat Money-Lenders Act 2011 | **Yes** — registration/licence (verified) | **Delegated** — S.12 caps interest, rate set by notification (UNVERIFIED exact rate) | Modern Act with explicit cap-power. |
| **Rajasthan** | Rajasthan Money-Lenders Act 1963 | **Yes** — licence (S.5/6, verified) | **Structural cap:** interest recoverable ≤ **principal** (S.27, verified). Govt *may* notify max simple rate (S.29) — rate UNVERIFIED. | Only amount (not rate) fixed in bare text. |
| **Bihar** | Bihar Money-Lenders Act 1974 | **Yes** — certificate by Anchal Adhikari (S.5, verified) | **VERIFIED numeric:** **12% p.a. secured / 15% p.a. unsecured** (S.9) | Only state with a fixed numeric cap in bare Act text. Active enforcement (esp. rural). |
| **West Bengal** | Bengal Money-Lenders Act 1940 | **Yes** — licence (S.8, verified) | **Structural cap:** interest recoverable ≤ **principal** (S.30, verified) | Old Act still in effect. |
| **Kerala** | Kerala Money-Lenders Act 1958 | **Yes** — licence (S.3; unlicensed penalised S.17, verified) | **UNVERIFIED** — no cap section surfaced in accessible text | Licence confirmed; numeric cap not sourced. |
| **Madhya Pradesh** | M.P. Money Lenders Act 1934 | **Yes** — certificate by Registering Authority (S.11-B, verified) | **Structural cap:** interest arrears recoverable ≤ **principal** (S.9, verified) | Only amount (not rate) fixed in bare text. |
| **Andhra Pradesh** | A.P. (Telangana Area) Money Lenders Act, 1349 Fasli | **Yes** — licence (S.3; unlicensed suit dismissed S.9, verified) | **Delegated** — Govt notification (S.10, UNVERIFIED exact rate) | Post-bifurcation AP Act may differ; verify. |
| **Telangana** | Telangana Money Lenders Act 1349F (renamed from AP Act) | **Yes** — licence (S.3; Tahsildar/Collector, verified) | **Delegated** — Govt notification (S.10, UNVERIFIED exact rate) | A cited "9% secured / 12% unsecured" could NOT be confirmed — treat as unverified. |
| **Delhi (NCT)** | Punjab Registration of Money-Lenders' Act 1938 (extended to Delhi) | **Yes** — licence (S.4; Collector, verified) | **No rate-cap section** in Act (UNVERIFIED exhaustively) | Same 1938 Punjab Act applies. |
| **Haryana** | Punjab Registration of Money-Lenders' Act 1938 (extended) | **Yes** — licence (S.4; Collector, verified) | **No rate-cap section** in Act (UNVERIFIED exhaustively) | Same 1938 Punjab Act. |
| **Punjab** | Punjab Registration of Money-Lenders' Act 1938 | **Yes** — registration + licence (S.5, Collector, verified) | **No rate-cap section** in Act (UNVERIFIED exhaustively) | 1938 Act has no rate-cap section as fetched. |

**Key patterns:**
- **Registration is mandatory in every one of the 15 states/UTs** — highest-confidence finding. No state permits unlicensed money-lending as a *business*. The threshold question is whether occasional lending between acquaintances crosses into "business of money lending" — fuzzy, state-dependent.
- **Most caps are delegated to state Gazette notifications**, NOT fixed in the Act. Pull the current notification for each state before quoting a number.
- **Rajasthan / WB / MP** cap the *interest amount* at the principal — a hard ceiling on profit, not a rate.
- **Only Bihar** states a fixed % (12%/15%) in the bare Act.
- "Exorbitant interest" is separately policed by the central **Usurious Loans Act 1918** (court power to cut) regardless of state caps (see §6).

---

## 3. App Provider Liability Assessment

**Risk: LOW to MODERATE (but this depends on app features)**

| Scenario | Liability Risk | Why |
|----------|---------------|-----|
| User uses MicroFlow to *record* manually loans already given offline | **Low.** App is a pure record-keeping tool (digital diary). Neutral tool principle applies. | |
| User pays via MicroFlow (UPI/gateway integrated) | **Moderate.** If funds flow through the app, it starts looking like a lending platform. Avoid this. | |
| User matches lender-borrower via MicroFlow | **Moderate-High.** This makes you a lending marketplace, requiring RBI NBFC-P2P license. Avoid. | |
| App calculates and *auto-suggests* interest rates | **Low-Moderate.** If rates are user-configured and app merely computes, still likely neutral. But if you preset rates that exceed state caps, risk rises (aiding violation). | |
| MicroFlow stores borrower data in the cloud | **Low** (for DPDP — see below). But becomes an evidence source that could be subpoenaed. | |

**Key legal shield: No liability without INTENT to aid**

The decisive principle is **abetment** (IPC §107 / BNS §45): a person is liable for aiding an offence only if they *"intentionally aids"* it. Mere **foreseeability that someone might misuse** a neutral tool is **not enough** — see *Madan Mohan Singh v. State of Gujarat*, *Arnab Goswami v. State of Maharashtra*, and *Essa @ Anjum Memon v. State of Maharashtra* (2013, supplying a vehicle = facilitation only with intent to aid; mere ownership imposes no liability). Supplying a general-purpose ledger to unknown users, without intent to further any specific offence, falls outside abetment.

**"Neutral utility" vs. "active facilitator" — the line that matters:**
| Protected (neutral utility) | Liable (active facilitator) |
|---|---|
| Provides the means; doesn't participate | Designs/markets the tool *to enable* the offence |
| Generic ledger; no loan-specific illegality engineered | Usurious-rate engine; steers users toward unlicensed lending |
| Takes no cut of proceeds | Revenue-share from the illegal activity |

> The biggest single risk lever is **how MicroFlow is marketed and positioned**. If it's pitched as "the easy way to run an unlicensed lending business," the neutral-tool shield weakens (fact-specific, untested for software — a lawyer's call).

**IT Act §79 safe harbor (Shreya Singhal v. Union of India, 2015):** intermediaries aren't liable for third-party content if they don't initiate/select/modify it and act on court/government takedown orders. BUT for a **single-user private book-keeping app** (user stores only their *own* data, no public/third-party content), §79 is largely **beside the point** — there's no "other person's content" to be a publisher of. The 2021 Rules' heavy duties apply only to large social-media intermediaries (≥5M users, user-to-user interaction) — a single-user utility fails that test outright.

**RBI / NBFC angle:** An NBFC **must be a company** (RBI Act §45-I(f)); §45-I(c) **expressly excludes an individual**. So a natural person lending to neighbors needs **no RBI/NBFC registration**. RBI's 2022 Digital Lending Guidelines bind banks/NBFCs and their lending service providers — a passive ledger with no disbursal and no bank link sits **outside** the RBI lending perimeter. The RBI "illegal loan app" crackdown targeted unauthorized lending + data-harvesting + harassment, **not** passive ledgers. (Real-world anchors: Khatabook, OkCredit, Vyapar operate as unregulated book-keeping SaaS, not lenders; OkCredit's *P2P* product OkNivesh was shut only because P2P lending is a regulated RBI category — a lending *feature*, not the ledger.)

**Reality check on user-side risk (the real exposure):** An unregistered lender faces only *limited* risk, and mainly **if lending is a "business"** — an *isolated/occasional* transaction is NOT "carrying on the business of money-lending" (*Gajanan v. Seth Brindaban*, AIR 1970 SC 2007; occasional neighbor lending ≠ business). **But** if it IS a business, the sharpest consequence isn't a fine — it's that **the unlicensed lender generally cannot recover the loan in court** (Andhra Pradesh HC 2004; Karnataka HC 2020; Maharashtra Act s.13 bars recovery). Some states even let the borrower claw back amounts paid. This is the practical hazard to surface to users.

---

## 4. Indian Contract Act — Validity of Informal Loans

**Section 10 — Essentials of a Valid Contract:**

An agreement is a contract if made by:
- Free consent of parties competent to contract,
- For a lawful consideration and with a lawful object,
- Not expressly declared void.

All of these are satisfied for an informal trust-based loan:
- **Consideration:** The lender gives money; borrower promises to repay with interest. Valid consideration.
- **Competent parties:** Both adults of sound mind.
- **Lawful object:** Loan is not illegal per se (money-lending is not a crime; unlicensed lending may violate state laws but the loan contract itself may not be void — the state act usually makes it *unenforceable* rather than void).
- **Writing not required:** Oral loan agreements are valid under the Contract Act. **BUT** — oral loans become hard to prove. The app's records (transaction log, digital acknowledgment) become **strong evidence** under the Indian Evidence Act (electronic records are admissible under Section 65B).

**Practical impact:**
- A lender using MicroFlow has far stronger legal position to recover money in court than one relying on memory/chits.
- The app records (timestamped, persistent, tamper-evident) can serve as primary evidence of the contract's existence and terms.
- **Caveat:** If the loan violates a state Money Lenders Act (e.g., unlicensed lending in TN/Karnataka), the court may refuse to enforce the contract — the loan is not void but **unenforceable** (money may need to be returned sans interest).

**Evidence Act angle (important for app design):** Electronic records are admissible under **Section 65A/65B, Indian Evidence Act**, but a **Section 65B(4) certificate** (a manually signed certificate by a responsible company officer confirming the device/process) is *mandatory* when producing electronic evidence — see *Anvar P.V. v. P.K. Basheer* (2014). MicroFlow should keep a standing process to generate these certificates for any record-set that may need to be produced in court. Oral side-deals cannot override the electronic loan record (S.91/92).

**Section 25 (consideration):** An agreement "without consideration is void," but a **loan has consideration** (the money advanced) — so S.25 does not void trust-based loans between acquaintances. The love/affection exception only applies where there is *no* consideration (pure gifts).

**Registration:** Unsecured personal loans recorded in the app need **no writing or registration**. Only loans secured by a mortgage/charge on immovable property require a registered instrument (TPA s.59; Registration Act s.17).

**Limitation:** Recovery suits are barred after **3 years** (Limitation Act, Art. 56/57) unless acknowledged in writing. The app's persistent, timestamped records help establish the acknowledgment date.

---

## 5. DPDP Act 2023 — Practical Risk

| Aspect | Assessment |
|--------|-----------|
| **Does DPDP apply to individual lenders?** | **Probably NOT — but it's a judgment call.** The Act exempts "data processed by an individual for *purely personal or domestic purposes*." The trouble: an individual running a *money-lending business* (even informally, one person, small book) is generally viewed as **commercial, not domestic** — mirroring the EU GDPR "household exemption." So the exemption likely does NOT shield the individual lender. Practically, though, an individual is a very low enforcement target. |
| **Does DPDP apply to MicroFlow as app provider?** | **YES.** The app company determines purpose + means of processing and stores data in its cloud → it is a **Data Fiduciary** almost certainly, regardless of size. There is **no automatic "below-X revenue = exempt" rule** in the Act. The govt has a *power* to exempt startups/small fiduciaries by class, but no fixed threshold is in force yet. |
| **"Significant Data Fiduciary" status?** | SDF is designated by the Central Govt based on *volume/sensitivity/risk*, not company size. A micro-scale app is unlikely to be designated — but SDF status would add obligations, not remove them. |
| **Core fiduciary duties** | Notice + consent (use a privacy notice + consent checkbox); reasonable security safeguards for the cloud store; breach notification (within 72 hrs per the 2025 Rules); data erasure on request. |
| **Penalties** | Up to ₹250 crore for security-failure breaches; up to ₹200 crore for children's-data failures. These are headline maxima — they scale to actual harm, and enforcement to date has been minimal. |
| **Practical enforcement risk** | **Low for the individual lender; Moderate (hygiene-level) for MicroFlow as Data Fiduciary.** The real, concrete risk sits with the company: getting valid consent, securing the cloud store, and breach-notification readiness. Not an imminent-raid risk, but treat DPDP as applicable, not optional. |

**Recommendation:** Add a simple privacy notice inside the app. Do not collect Aadhaar, PAN, or biometrics within the app (leave it to the user's offline copies). Minimize stored PII to name + phone.

---

## 6. Usurious Loans Act 1918 (Central Law)

| Aspect | Detail |
|--------|--------|
| **What it does** | Gives courts power to reopen a transaction and reduce the rate of interest if the court finds the interest is "excessive" and the transaction was "unconscionable." |
| **Does it set a cap?** | **No.** It does NOT set a specific percentage. The court decides case-by-case based on: risk, market rates at the time, relationship of parties, and whether the lender took advantage of the borrower's distress. |
| **Relevance to state caps** | If a state Money Lenders Act sets a cap, that cap applies. The Usurious Loans Act is a **residual** power — even in states without caps, a court can reduce interest if it seems excessive. |
| **Typical "safe" interest range in Indian courts (principle, not statutory)** | Indian courts have historically treated **~12-18% p.a. simple interest** as reasonable, and routinely **cut exorbitant rates down to a fair commercial rate (often ~12% or the prevailing bank rate)** when found exploitative. Rates materially above this (e.g., 24-30%+ p.a.) carry real risk of judicial reduction. This is *settled judicial practice*, not a fixed statutory ceiling — exact "usurious" thresholds are decided case-by-case. |
| **Compounding / interest-on-interest** | Indian courts strongly disfavor compound interest at high rates. Most courts reduce to simple interest if the original contract appears exploitative. |

**Bottom line:** The app should let users enter their own rate (never preset one). As general guidance to surface in-app (not legal advice), staying within a moderate simple-interest range reduces the chance a court later calls the rate usurious and slashes it. The exact safe number varies by state notification and court — users must check locally.

---

## 7. Recommended Disclaimers & Safeguards

These should be placed in:
- **Terms of Service** (legal contract between MicroFlow and the user)
- **In-app warnings** (shown once or on every new loan entry)
- **App Store description** / marketing materials

### TOS Clauses (Draft language)

```
1. SOFTWARE AS A TOOL. MicroFlow Pro is a digital record-keeping tool only.
   The Company does not lend money, does not facilitate lending, does not
   match lenders with borrowers, does not set or recommend interest rates,
   and does not collect or disburse payments. All lending decisions,
   interest rates, and repayment terms are solely determined by the User.

2. USER RESPONSIBILITY. The User is solely responsible for ensuring
   compliance with all applicable central and state laws, including but not
   limited to the Money Lenders Act(s), Usurious Loans Act, Indian Contract
   Act, and applicable licensing requirements in the User's state/region.
   The Company makes no representation that the User's use of the Software
   complies with local laws.

3. NO LEGAL ADVICE. The Company does not provide legal, tax, or financial
   advice. Users should consult qualified legal counsel regarding their
   specific obligations.

4. NO WARRANTIES ON DATA ACCURACY. Data entered by the User is the User's
   responsibility. The Software stores data as-is and does not verify its
   accuracy.

5. INDEMNIFICATION. User agrees to indemnify and hold harmless the Company
   from any claims, losses, or damages arising from User's lending
   activities or non-compliance with applicable laws.

6. DATA PRIVACY. The Company processes minimal personal data (name, phone)
   solely for the purpose of providing the record-keeping service. The User
   is responsible for obtaining consent from their borrowers regarding
   storage of their information.
```

### In-App Warning (shown on first launch or first loan entry)

```
**Important Notice**

MicroFlow Pro is a RECORD-KEEPING TOOL, not a lending platform. You are
solely responsible for:

- Complying with your state's Money Lenders Act (if applicable)
- Setting legal interest rates
- Any licensing/registration you may need

This app does NOT provide legal advice. Consult a lawyer if unsure.
```

### Additional Safeguards

| Measure | Why |
|---------|-----|
| **Don't preset/recommend interest rates** | Setting a default rate (even 12%) could be seen as advising users on rates. Let users enter their own rate every time. |
| **Don't integrate payments** | If money never touches MicroFlow, you're clearly just a diary. UPI/gateway integration changes the picture. |
| **Don't allow public lender profiles / matchmaking** | Avoid any marketplace dynamics. Each user's data is private to that user. |
| **Don't collect Aadhaar/PAN** | Store the bare minimum — name, amount, date, phone. Aadhaar/PAN are sensitive under DPDP and escalate your compliance burden. |
| **Don't offer "legal support" to users** | Don't help users file recovery cases or send legal notices. That transforms you from tool to service provider. |
| **Country block** | Consider restricting the app to India (since non-Indian lending laws are a whole other rabbit hole). |
| **Terms versioning** | Keep a changelog of TOS updates — if laws change, you update TOS and users must re-accept. |

---

## 8. "Consult a Lawyer" Flags

The following issues genuinely need a lawyer's opinion for your specific situation:

1. **If you ever integrate payments (UPI, gateway)** — RBI may consider this a payment system requiring authorization.
2. **If user base crosses ~10,000+ active lenders** — state authorities may start noticing; you may need regulatory engagement strategy.
3. **If you expand beyond "individual lender tracking friends/neighbors"** to small NBFCs or chit funds — completely different regulation.
4. **If you want to offer users "digital loan agreement templates"** — this starts approaching document creation/legal services regulation.
5. **If a specific state government issues a notice/order** — respond only through a local lawyer familiar with that state's law.
6. **If a borrower disputes a loan recorded in the app** — the app's records could be subpoenaed. Consult evidence/procedural law.
7. **If you store any biometric / Aadhaar / PAN data** — DPDP Act significant-data-fiduciary risk escalates; lawyer needed.
8. **Tax implications** — users may have income tax liability on interest income; the app itself may have GST on subscription/service fees. Discuss with a CA.
9. **Before relying on any interest-rate figure from this brief** — verify the **current state Gazette notification** for the specific state, since most caps are delegated (not in the Act itself). This doc only tells you *where* to look, not the current rate.
10. **Determine whether your app crosses from "neutral utility" to "active facilitator"** — if you add features like interest auto-calculation, payment collection, or borrower-lender matching, the legal posture changes.
11. **DPDP compliance readiness** — as the app's Data Fiduciary, your concrete obligations (notice, consent, security, breach notification, data erasure) need a lawyer to audit before launch.

---

## 9. Summary of Key Risks (Ranked)

| Risk | Severity | Action |
|------|----------|--------|
| App being seen as "enabling unlicensed lending" by a state authority | **Medium** | TOS disclaimers + don't integrate payments |
| User violating state Money Lenders Act and blaming the app | **Low-Medium** | Indemnity clause in TOS |
| Interest charged by user found usurious by court | **Low** (app not liable) | User-configured rates, no defaults |
| DPDP violation for storing borrower data | **Very Low** (current enforcement) | Basic privacy notice + consent checkbox |
| Subpoena / court order for app records | **Low-Medium** (if user grows) | Prepare data export for production before court |
| Borrower suing the app for facilitating predatory lending | **Low** (strong intermediary defense) | Clear terms, no payment integration |

---

*Last updated: 2026-07-19. This document is a research brief, not legal advice. Laws change, state-level enforcement varies, and judicial interpretation differs by court. Consult local counsel for specific compliance.*
