import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Check, ArrowRight, X, Sparkles, ChevronDown, Search } from "lucide-react";

// ─── 4 TIERS ───────────────────────────────────────────────────────────
const tiers = [
  {
    name: "Free Forever",
    monthly: "₹0",
    annual: "₹0",
    period: "/mo",
    color: "slate",
    desc: "Start managing your lending book — zero cost, forever.",
    features: [
      "Up to 10 Borrowers",
      "1 Loan per borrower only",
      "1 Savings account per borrower",
      "Simple interest only",
      "Record repayments",
      "Change theme and app icon",
      "Email support (48 hours)",
    ],
    missing: [
      "SMS reminders", "Compound interest",
      "PDF slip print", "Online UPI payments",
      "PIN lock", "Growth dashboard",
      "Staff and branch tools",
    ],
    popular: false,
    trial: false,
    cta: "Start Free",
  },
  {
    name: "Bronze",
    monthly: "₹299",
    annual: "₹3,229",
    period: "/mo",
    color: "indigo",
    desc: "Full toolkit for growing lenders. Manage up to 40 borrowers with all essential tools.",
    features: [
      "Up to 40 Borrowers",
      "Simple and compound interest",
      "Set your own interest rates",
      "Up to 3 loans per borrower",
      "Multiple savings accounts per borrower",
      "Print or save loan slips as PDF",
      "Print or save savings slips as PDF",
      "SMS reminders (100 per month)",
      "PIN lock and fingerprint lock",
      "Growth dashboard — see how your business is doing",
      "Collect EMI online with UPI",
      "All payment types — Cash, UPI, Bank, Cheque",
      "Print receipts with Bluetooth printer",
      "Google Drive backup — your data is safe",
      "Full transaction history with edit or delete",
      "Lock your books — prevent unwanted changes",
      "3 Branches, 3 Managers, 6 Agents",
      "Set staff targets and track performance",
      "Reward staff with streaks and leaderboard",
      "Track staff live location — where are they today",
      "Live map — see all staff on one screen",
      "Withdraw request and approval system",
      "Your own branding — logo, name, theme",
      "GST, PAN, Currency, Language, Timezone setup",
      "AI assistant that speaks Hindi",
      "Email support (24 hours)",
    ],
    missing: [
      "More than 40 borrowers", "Unlimited SMS reminders",
      "PAR default reports", "Full security shield",
      "WhatsApp notifications", "Custom email setup",
      "Razorpay and PhonePe gateway", "API access",
      "Dedicated account manager", "SLA guarantee",
    ],
    popular: false,
    trial: false,
    cta: "Get Started",
  },
  {
    name: "Silver",
    monthly: "₹499",
    annual: "₹5,389",
    period: "/mo",
    color: "emerald",
    desc: "Full control for serious lenders. Up to 100 borrowers and powerful analytics. 2 months FREE trial.",
    features: [
      "Up to 100 Borrowers",
      "All Bronze features included",
      "Daily, weekly or monthly EMI schedules",
      "Create your own loan products",
      "Unlimited SMS reminders",
      "Portfolio dashboard — full overview at a glance",
      "PAR 30/60/90 report — see who is late",
      "Cash flow report — money in, money out, what is left",
      "Branch and staff reports",
      "Activity log — who changed what, full tracking",
      "Auto-logout — app locks after being idle",
      "Google Drive auto backup every day",
      "Email setup — send emails using your own SMTP or Resend",
      "WhatsApp Business — send notifications to customers",
      "Razorpay and PhonePe — online payment gateway",
      "Connect your own software — API and webhooks",
      "Export all data — download your books as CSV or PDF",
      "Priority chat support",
      "Email support (12 hours)",
    ],
    missing: [
      "More than 100 borrowers", "Full two-factor authentication",
      "Custom payment gateway", "Run on your own server",
      "Dedicated account manager", "SLA guarantee",
    ],
    popular: true,
    trial: true,
    trialDuration: "2 Months FREE",
    cta: "Start Free Trial",
  },
  {
    name: "Enterprise",
    monthly: "Custom",
    annual: "Custom",
    period: "",
    color: "blue",
    desc: "For large NBFCs and multi-city lending operations. Fully customized for your needs.",
    features: [
      "Unlimited Borrowers, Branches, Managers, Agents",
      "All Silver features included",
      "Complete security lock — two-factor auth and IP lock",
      "Custom reports — build any report you need",
      "White label — your brand, your name everywhere",
      "Run on your own server (on-premise)",
      "Dedicated account manager — your own person",
      "SLA guarantee — we reply within 4 hours",
      "Full API access — connect any software",
      "Custom integration — connect any tool you use",
    ],
    missing: [],
    popular: false,
    trial: false,
    cta: "Contact Sales",
  },
];

const accentMap = {
  slate: { from: "from-slate-500", to: "to-slate-400", bg: "bg-slate-500/10", border: "border-slate-500/25", text: "text-slate-400", glow: "148,163,184" },
  indigo: { from: "from-indigo-500", to: "to-indigo-400", bg: "bg-indigo-500/10", border: "border-indigo-500/25", text: "text-indigo-400", glow: "99,102,241" },
  emerald: { from: "from-emerald-500", to: "to-emerald-400", bg: "bg-emerald-500/10", border: "border-emerald-500/25", text: "text-emerald-400", glow: "52,211,153" },
  blue: { from: "from-blue-500", to: "to-blue-400", bg: "bg-blue-500/10", border: "border-blue-500/25", text: "text-blue-400", glow: "59,130,246" },
};

// ─── FULL COMPARISON TABLE (simple English, zero jargon) ──────────────
// Every row answers: "can I do this?" — plain yes / no / how many.
const comparisonData = [
  { cat: "BORROWERS & LOANS", rows: [
    { f: "How many borrowers can you manage",
      free: "10", bronze: "40", silver: "100", ent: "Unlimited" },
    { f: "Add, edit or remove borrowers",
      free: "Yes", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "Interest type (simple and compound)",
      free: "Simple only", bronze: "Both", silver: "Both", ent: "Both" },
    { f: "How many loans per borrower",
      free: "1", bronze: "3", silver: "6", ent: "As needed" },
    { f: "Set your own custom interest rates",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "Print or save loan slips as PDF",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "Lock your books from changes",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "SMS reminders for EMI due dates",
      free: "No", bronze: "Yes (100/mo)", silver: "Yes Unlimited", ent: "Yes" },
  ]},
  { cat: "SAVINGS & WITHDRAWALS", rows: [
    { f: "Savings accounts per borrower",
      free: "1", bronze: "Multiple", silver: "Multiple", ent: "Unlimited" },
    { f: "Daily bachat and recurring deposits",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "Print or save savings slips as PDF",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "Withdrawal request and approval system",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
  ]},
  { cat: "COLLECTION & PAYMENT", rows: [
    { f: "Record EMI payments",
      free: "Yes", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "Record multiple EMIs at once",
      free: "Basic", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "Collect EMI online via UPI (PhonePe, GPay)",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "Payment types (Cash, UPI, Bank, Cheque)",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "Print receipts with Bluetooth printer",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "Full history of edits and deletes",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
  ]},
  { cat: "STAFF & BRANCH", rows: [
    { f: "Branches, managers and agents you can add",
      free: "1 / 1 / 1", bronze: "3 / 3 / 6", silver: "6 / 6 / 12", ent: "As needed" },
    { f: "Set staff targets and see performance",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "Reward staff with streaks and leaderboard",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "Track staff live location — where are they today",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "See all staff on a live map",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "Give each staff member different access levels",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
  ]},
  { cat: "SECURITY & BACKUP", rows: [
    { f: "PIN lock to open the app",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "Fingerprint lock (biometric)",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "Backup your books to Google Drive",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "See who changed what (activity log)",
      free: "No", bronze: "No", silver: "Yes", ent: "Yes" },
    { f: "App locks itself after some time (auto-logout)",
      free: "No", bronze: "No", silver: "Yes", ent: "Yes" },
  ]},
  { cat: "SETTINGS & INTEGRATIONS", rows: [
    { f: "Your own brand — logo, theme and name",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "GST, PAN, currency, language, timezone setup",
      free: "No", bronze: "Yes", silver: "Yes", ent: "Yes" },
    { f: "Growth dashboard — see how your business is running",
      free: "No", bronze: "Basic", silver: "Detailed", ent: "Custom" },
    { f: "PAR report — how many borrowers are late (30, 60, 90 days)",
      free: "No", bronze: "No", silver: "Yes", ent: "Yes" },
    { f: "Cash flow report — money in, money out, what is left",
      free: "No", bronze: "No", silver: "Yes", ent: "Yes" },
    { f: "Send notifications via WhatsApp Business",
      free: "No", bronze: "No", silver: "Yes", ent: "Yes" },
    { f: "Send emails using your own email (SMTP or Resend)",
      free: "No", bronze: "No", silver: "Yes", ent: "Yes" },
    { f: "Online payment gateway (Razorpay, PhonePe)",
      free: "No", bronze: "No", silver: "No", ent: "Yes" },
    { f: "Connect your own software (API and webhooks)",
      free: "No", bronze: "No", silver: "No", ent: "Yes" },
    { f: "AI assistant that speaks Hindi for help",
      free: "No", bronze: "No", silver: "Yes", ent: "Yes" },
  ]},
  { cat: "SUPPORT", rows: [
    { f: "Email support — how fast we reply",
      free: "48 hours", bronze: "24 hours", silver: "12 hours", ent: "4 hours" },
    { f: "Chat support and your own manager",
      free: "No", bronze: "No", silver: "Yes", ent: "Yes" },
    { f: "2 months free trial (Silver plan only)",
      free: "No", bronze: "No", silver: "Yes", ent: "No" },
  ]},
];

// ─── Sub-components ──────────────────────────────────────────────────

function TierCard({ t, i, annual, isMobile }) {
  const ac = accentMap[t.color];
  return (
    <motion.div
      initial={{ opacity: 0, y: 24 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1], delay: i * 0.1 }}
      className={
        "relative rounded-2xl p-6 md:p-7 flex flex-col transition-all duration-500 group " +
        (t.popular
          ? "bg-gradient-to-b from-indigo-500/[0.08] via-indigo-500/[0.03] to-transparent border border-indigo-500/25 hover:border-indigo-400/40 hover:shadow-2xl hover:shadow-indigo-500/10 scale-[1.02]"
          : t.trial
            ? "bg-gradient-to-b from-emerald-500/[0.05] to-transparent border border-emerald-500/15 hover:border-emerald-500/30 hover:shadow-xl hover:shadow-emerald-500/5"
            : "border border-white/[0.04] hover:border-white/[0.1] bg-white/[0.01]")
      }
    >
      {/* Badges */}
      {t.popular && !t.trial && (
        <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-4 py-1 rounded-full bg-gradient-to-r from-indigo-500 to-indigo-400 text-white text-[9px] font-semibold uppercase tracking-[0.08em] shadow-lg shadow-indigo-500/30 whitespace-nowrap">
          Most Popular
        </div>
      )}
      {t.trial && (
        <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-4 py-1 rounded-full bg-gradient-to-r from-emerald-500 to-emerald-400 text-white text-[9px] font-semibold uppercase tracking-[0.08em] shadow-lg shadow-emerald-500/30 whitespace-nowrap">
          {t.trialDuration}
        </div>
      )}

      {/* Plan name */}
      <div className={"text-white/40 text-[11px] font-semibold uppercase tracking-[0.08em] mb-1 " + ac.text}>{t.name}</div>

      {/* Annual save badge */}
      {annual && t.monthly !== "Custom" && t.monthly !== "₹0" && (
        <div className="text-emerald-400/60 text-[10px] mb-2">Save 10% with annual billing</div>
      )}

      {/* Price */}
      <AnimatePresence mode="wait">
        <motion.div
          key={(annual ? "a" : "m") + i}
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -8 }}
          transition={{ duration: 0.2 }}
        >
          <span className="text-3xl md:text-[42px] font-semibold tracking-[-0.03em] text-white">
            {annual ? t.annual : t.monthly}
          </span>
          {t.period && (
            <span className="text-white/30 text-sm ml-1">{annual ? "/yr" : t.period}</span>
          )}
          {t.monthly !== "Custom" && t.monthly !== "₹0" && !annual && t.trial && (
            <div className="text-emerald-400/60 text-[10px] mt-1">Then ₹{t.monthly}/mo after trial</div>
          )}
        </motion.div>
      </AnimatePresence>

      <p className="text-white/50 text-[11px] mt-1 mb-5">{t.desc}</p>

      {/* Included features */}
      <ul className="space-y-2 mb-3 flex-1">
        {t.features.map((f, j) => (
          <li key={j} className="flex items-start gap-2 text-[12px] md:text-[13px] text-white/70">
            <span className="w-5 h-5 rounded-full bg-indigo-500/10 flex items-center justify-center shrink-0 mt-0.5">
              <Check className="w-3 h-3 text-indigo-400" />
            </span>
            {f}
          </li>
        ))}
      </ul>

      {/* Missing features */}
      {t.missing.length > 0 && (
        <ul className="space-y-1.5 mb-5 pb-4 border-b border-white/[0.04]">
          <div className="text-white/20 text-[9px] font-medium tracking-[0.1em] uppercase mb-2">Unlock with upgrade</div>
          {t.missing.map((f, j) => (
            <li key={j} className="flex items-center gap-2 text-[12px] text-white/30 line-through">
              <span className="w-5 h-5 rounded-full flex items-center justify-center shrink-0 text-[9px] text-white/20">✕</span>
              {f}
            </li>
          ))}
        </ul>
      )}

      {/* CTA */}
      <button
        className={
          "w-full py-3 min-h-[44px] rounded-full text-[13px] font-semibold transition-all duration-300 inline-flex items-center justify-center gap-1 " +
          (t.popular
            ? "bg-gradient-to-r from-indigo-500 to-indigo-400 text-white hover:shadow-xl hover:shadow-indigo-500/25 hover:scale-[1.02]"
            : t.trial
              ? "bg-gradient-to-r from-emerald-500 to-emerald-400 text-white hover:shadow-xl hover:shadow-emerald-500/25 hover:scale-[1.02]"
              : "border border-white/[0.1] text-white/70 hover:border-white/30 hover:bg-white/[0.02] hover:text-white/90")
        }
      >
        {t.cta}
        <ArrowRight className="w-3.5 h-3.5" />
      </button>
    </motion.div>
  );
}

// ─── FEATURE COMPARISON TABLE ────────────────────────────────────────
function ComparisonTable() {
  return (
    <div className="overflow-x-auto pb-4 -mx-4 px-4">
      <table className="w-full min-w-[720px] text-[12px] border-collapse">
        {/* Table Header */}
        <thead>
          <tr className="border-b border-white/[0.06]">
            <th className="text-left py-3 pr-4 text-white/50 font-medium text-[11px] sticky left-0 z-10" style={{ background: "var(--background)" }}>Feature</th>
            <th className="py-3 px-3 text-center text-white/40 font-medium text-[11px]">Free</th>
            <th className="py-3 px-3 text-center text-indigo-400 font-semibold text-[11px]">Bronze</th>
            <th className="py-3 px-3 text-center text-emerald-400 font-semibold text-[11px]">Silver</th>
            <th className="py-3 px-3 text-center text-blue-400 font-semibold text-[11px]">Enterprise</th>
          </tr>
        </thead>
        <tbody>
          {comparisonData.map((section, si) => (
            <Fragment key={si}>
              {/* Category header row */}
              <tr className="border-b border-white/[0.03]">
                <td colSpan={5} className="py-3 text-white/30 text-[10px] font-semibold tracking-[0.15em] uppercase">
                  {section.cat}
                </td>
              </tr>
              {/* Feature rows */}
              {section.rows.map((row, ri) => {
                const cells = [
                  { key: 'free', val: row.free, accent: false },
                  { key: 'bronze', val: row.bronze, accent: false },
                  { key: 'silver', val: row.silver, accent: true },
                  { key: 'ent', val: row.ent, accent: false },
                ];
                return (
                  <tr key={ri} className="border-b border-white/[0.02] hover:bg-white/[0.02] transition-colors">
                    <td className="py-2.5 pr-4 text-white/60 sticky left-0 z-10" style={{ background: "var(--background)" }}>
                      {row.f}
                    </td>
                    {cells.map((c, ci) => {
                      let cls = "px-3 py-2.5 text-center";
                      if (c.val === "Yes") cls += " text-emerald-400";
                      else if (c.val === "No") cls += " text-white/20";
                      else if (c.accent) cls += " text-emerald-300/80";
                      else cls += " text-white/50";
                      return <td key={ci} className={cls}>{c.val}</td>;
                    })}
                  </tr>
                );
              })}
            </Fragment>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// Helper needed for category separators
import { Fragment } from "react";

export default function Pricing() {
  const [annual, setAnnual] = useState(false);
  const [selectedTier, setSelectedTier] = useState(2);
  const [showTable, setShowTable] = useState(false);

  return (
    <section className="relative py-20 md:py-36 px-6 section-mesh overflow-hidden border-t border-white/[0.03]" id="pricing">
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-indigo-500/4 rounded-full blur-[150px] pointer-events-none" />
      <div className="absolute top-0 right-0 w-[300px] h-[300px] bg-emerald-500/5 rounded-full blur-[100px] pointer-events-none" />

      <div className="max-w-6xl mx-auto relative z-[1]">
        {/* ── Header ── */}
        <div className="text-center mb-10 md:mb-16">
          <motion.span
            initial={{ opacity: 0, y: 8 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.05 }}
            className="inline-block text-indigo-400/80 text-[10px] md:text-[11px] font-semibold tracking-[0.25em] uppercase mb-5"
          >
            Simple, Transparent Pricing
          </motion.span>
          <motion.h2
            initial={{ opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
            style={{ fontFamily: "'Instrument Serif', serif" }}
            className="text-[28px] md:text-[44px] font-medium tracking-[-0.01em] leading-[1.15] mb-6"
          >
            Choose the Right Plan for{" "}
            <span className="gradient-brand">Your Lending Business</span>
          </motion.h2>
          <motion.p
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            transition={{ delay: 0.15 }}
            className="text-white/50 text-sm md:text-base max-w-lg mx-auto mb-8 md:mb-10"
          >
            Start with <span className="text-emerald-400 font-semibold">2 months Silver FREE</span> — no credit card needed. Pick your plan after the trial.
          </motion.p>

          {/* ── Monthly/Annual Toggle ── */}
          <motion.div
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            className="flex items-center justify-center gap-3 text-sm mb-4"
          >
            <span className={"transition-colors duration-300 " + (annual ? "text-white/40" : "text-white/85")}>Monthly</span>
            <button
              onClick={() => setAnnual(!annual)}
              className={
                "relative w-12 h-6 rounded-full transition-all duration-300 " +
                (annual ? "bg-emerald-500 shadow-lg shadow-emerald-500/25" : "bg-white/10")
              }
              aria-label={annual ? "Switch to monthly" : "Switch to annual"}
            >
              <span className={"absolute top-1 left-1 w-4 h-4 rounded-full bg-white transition-all duration-300 shadow-sm " + (annual ? "left-7" : "left-1")} />
            </button>
            <span className={"transition-colors duration-300 " + (annual ? "text-white/85" : "text-white/40")}>
              Annual <span className="text-emerald-400/70 text-[10px]">(-10%)</span>
            </span>
          </motion.div>
        </div>

        {/* ════════════════════════════════ */}
        {/* MOBILE — Pill Tabs + Single Card  */}
        {/* ════════════════════════════════ */}
        <div className="md:hidden mb-10">
          <div className="flex justify-center mb-5">
            <div className="glass-pill inline-flex gap-1 p-1 bg-white/[0.03] border border-white/[0.05]">
              {tiers.map((t, i) => (
                <button key={i}
                  onClick={() => setSelectedTier(i)}
                  className={
                    "relative px-3 py-2 rounded-full text-[11px] font-semibold transition-all duration-300 min-h-[36px] whitespace-nowrap " +
                    (i === selectedTier ? "text-white shadow-lg shadow-indigo-500/20" : "text-white/40 hover:text-white/70")
                  }
                >
                  {i === selectedTier && (
                    <motion.span layoutId="activePill" className="absolute inset-0 rounded-full bg-gradient-to-r from-indigo-500 to-indigo-400" transition={{ type: "spring", stiffness: 380, damping: 30 }} />
                  )}
                  <span className="relative z-[1]">{t.name}</span>
                </button>
              ))}
            </div>
          </div>

          <AnimatePresence mode="wait">
            <motion.div key={selectedTier}
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              transition={{ duration: 0.3 }}
            >
              <TierCard t={tiers[selectedTier]} i={selectedTier} annual={annual} isMobile />
            </motion.div>
          </AnimatePresence>
        </div>

        {/* ════════════════════════════════ */}
        {/* DESKTOP — 4-Column Grid           */}
        {/* ════════════════════════════════ */}
        <div className="hidden md:grid md:grid-cols-4 gap-4 md:gap-5 items-start mb-14">
          {tiers.map((t, i) => (
            <TierCard key={i} t={t} i={i} annual={annual} />
          ))}
        </div>

        {/* ── Trust Bar ── */}
        <motion.div
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          transition={{ delay: 0.3 }}
          className="flex flex-wrap items-center justify-center gap-6 md:gap-12 mb-12"
        >
          {[
            { icon: "🔒", text: "No Credit Card Required" },
            { icon: "🚀", text: "2 Months Free Trial" },
            { icon: "🔄", text: "Cancel Anytime" },
            { icon: "📞", text: "Email Support Included" },
          ].map((item, i) => (
            <motion.div key={i}
              initial={{ opacity: 0, y: 8 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: 0.3 + i * 0.08 }}
              className="flex items-center gap-2 text-white/40 text-[12px]"
            >
              <span>{item.icon}</span>
              <span>{item.text}</span>
            </motion.div>
          ))}
        </motion.div>

        {/* ════════════════════════════════════════ */}
        {/* COMPARE ALL FEATURES — Collapsible Table  */}
        {/* ════════════════════════════════════════ */}
        <motion.div
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          transition={{ delay: 0.2 }}
          className="border-t border-white/[0.04] pt-10"
        >
          <button
            onClick={() => setShowTable(!showTable)}
            className="flex items-center justify-center gap-2 mx-auto text-white/50 hover:text-white/80 transition-all duration-300 group mb-6"
          >
            <span className="text-[13px] font-semibold">{showTable ? "Hide" : "Compare All Features"} — Full Breakdown</span>
            <motion.span animate={{ rotate: showTable ? 180 : 0 }} transition={{ duration: 0.3 }}>
              <ChevronDown className="w-4 h-4" />
            </motion.span>
          </button>

          <AnimatePresence>
            {showTable && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: "auto", opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
                className="overflow-hidden"
              >
                <div className="rounded-2xl border border-white/[0.04] bg-white/[0.01] p-4 md:p-6">
                  <div className="text-white/40 text-[11px] font-medium text-center mb-4">
                    7 categories · 36 features · See what each plan includes
                  </div>
                  <ComparisonTable />
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </motion.div>
      </div>
    </section>
  );
}
