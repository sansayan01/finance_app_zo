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
      "10 Borrowers max",
      "Basic Loan Records",
      "Flat Interest Only",
      "1 Active Loan per Person",
      "1 Savings per Person",
      "Last 10 Transactions",
      "Basic Theme & Icon",
    ],
    missing: [
      "Offline Mode", "SMS Reminders", "Biometric Lock",
      "Portfolio Dashboard", "Statement Export", "UPI Payments",
    ],
    popular: false,
    trial: false,
    cta: "Get Started Free",
  },
  {
    name: "Bronze",
    monthly: "₹299",
    annual: "₹2,392",
    period: "/mo",
    color: "indigo",
    desc: "Solid toolkit for growing lenders. Track up to 50 borrowers.",
    features: [
      "50 Borrowers",
      "Flat + Compound Interest",
      "Multiple Loans per Person",
      "Multiple Savings per Person",
      "Offline Mode",
      "SMS Reminders (10/mo)",
      "PIN Lock",
      "Basic Portfolio Dashboard",
      "Monthly Trends Chart",
      "Bluetooth Receipt Print",
      "Payment Mode (Cash/UPI/Bank)",
    ],
    missing: [
      "Biometric Auth", "Unlimited SMS", "PAR Analytics",
      "Statement Export", "Date Freeze", "Location Tracking",
    ],
    popular: false,
    trial: false,
    cta: "Get Started",
  },
  {
    name: "Silver",
    monthly: "₹599",
    annual: "₹4,792",
    period: "/mo",
    color: "emerald",
    desc: "Everything a serious lender needs. 2 months FREE — then ₹599/mo.",
    features: [
      "200 Borrowers",
      "All Interest Types + Custom",
      "Multi-Frequency Schedules",
      "Loan Product Config",
      "Unlimited SMS Reminders",
      "Biometric + PIN Lock",
      "Advanced Portfolio Analytics",
      "PAR 30/60/90 Delinquency Tracking",
      "Transaction Export CSV/PDF",
      "Date Freeze (Admin)",
      "Agent GPS Location Tracking",
      "UPI Verification",
      "AI Hindi Assistant",
      "Full Quick Collect (Multi-Pay, Backdate)",
      "Savings Withdraw Request Workflow",
      "Security Shield & Activity Logs",
      "Google Drive Backup",
      "Staff Gamification & Streaks",
      "Multi-Branch Support",
    ],
    missing: [
      "Unlimited Borrowers", "API Access",
      "White-Label Branding", "On-Premise",
    ],
    popular: true,
    trial: true,
    trialDuration: "2 months FREE",
    cta: "Start Free Trial",
  },
  {
    name: "Enterprise",
    monthly: "Custom",
    annual: "Custom",
    period: "",
    color: "blue",
    desc: "For NBFCs and multi-branch lenders. Tailored to your needs.",
    features: [
      "Unlimited Borrowers",
      "Everything in Silver",
      "API Access & Integrations",
      "White-Label Branding",
      "Dedicated Account Manager",
      "Custom Integrations",
      "On-Premise Option",
      "Razorpay / PhonePe Gateways",
      "Two-Factor Authentication (2FA)",
      "IP Whitelisting",
      "Custom Report Generation",
      "SLA Guarantee",
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

// ─── FULL COMPARISON DATA (110 features in one table) ────────────────
const comparisonData = [
  { cat: "BORROWER MANAGEMENT", rows: [
    { f: "Max Borrowers", free: "10", bronze: "50", silver: "200", ent: "Unlimited" },
    { f: "Add / Edit / Remove Borrower", free: "✅", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "Borrower Loan History", free: "Current only", bronze: "All", silver: "All", ent: "All + Export" },
    { f: "Borrower Profile Photo", free: "❌", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "Bulk CSV Import", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Search & Filter Borrowers", free: "❌", bronze: "✅", silver: "✅", ent: "✅" },
  ]},
  { cat: "LOAN MANAGEMENT", rows: [
    { f: "Active Loans per Person", free: "1", bronze: "Multiple", silver: "Multiple", ent: "Multiple" },
    { f: "Flat Interest", free: "✅", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "Reducing / Compound Interest", free: "❌", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "Custom Interest Rates", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Collection Frequency", free: "Basic", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "Multi-Frequency Schedules", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Loan Product Config", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Pause / Resume Loan", free: "❌", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "Early Settlement (Pro-rated)", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Loan Statement Generate", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Portfolio Statement Generate", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Date Freeze (Admin Lock)", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "SMS Notification on Loan", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Payment Delete/Edit History", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
  ]},
  { cat: "SAVINGS MANAGEMENT", rows: [
    { f: "Savings Accounts per Person", free: "1", bronze: "Multiple", silver: "Multiple", ent: "Unlimited" },
    { f: "Daily Bachat Vault", free: "❌", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "Recurring Savings (RD)", free: "❌", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "Savings Statement Generate", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Withdraw Request Workflow", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Withdrawal Approval Queue", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Savings Product Config", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Savings SMS Notification", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Deposit Delete/Edit History", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
  ]},
  { cat: "COLLECTIONS & PAYMENTS", rows: [
    { f: "Record Repayment", free: "✅", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "Today's Payment Page", free: "Basic", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "Today's PDF Export", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Transaction History", free: "Last 10", bronze: "Full", silver: "Full", ent: "Full + Export" },
    { f: "Transaction Export CSV/PDF", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Transaction Delete/Edit", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Quick Collect — Single Payment", free: "✅", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "Quick Collect — Multi-Payment", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Quick Collect — Backdate", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Quick Collect — Date Picker", free: "❌", bronze: "Limited", silver: "Full", ent: "Full" },
    { f: "UPI Payment Collection", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "UPI Verification", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Bluetooth Receipt Print", free: "❌", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "Payment Modes (Cash/UPI/Bank)", free: "❌", bronze: "✅", silver: "✅", ent: "✅" },
  ]},
  { cat: "STAFF & BRANCH", rows: [
    { f: "Branches", free: "1", bronze: "Multiple", silver: "Multiple", ent: "Unlimited" },
    { f: "Branch Managers", free: "1", bronze: "Multiple", silver: "Multiple", ent: "Unlimited" },
    { f: "Collection Agents", free: "1", bronze: "Multiple", silver: "Multiple", ent: "Unlimited" },
    { f: "Staff Target Progress", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Staff Streaks & Gamification", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Staff Cash Deposit Submission", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Agent GPS Location Tracking", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Live Staff Map", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Staff Permissions (RBAC)", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Multi-Level Approval Workflow", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
  ]},
  { cat: "ORGANIZATION SETTINGS", rows: [
    { f: "Screen Icon Change", free: "✅", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "Basic Theme / Preset Colors", free: "✅", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "Legal / Display Name", free: "❌", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "GST / PAN Number", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "NBFC / License Registration", free: "❌", bronze: "❌", bronze: "❌", ent: "✅" },
    { f: "Address & Contact Info", free: "❌", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "Currency Selection", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Language / Locale", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Timezone", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Financial Year Start", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Custom Branding / Logo", free: "❌", bronze: "❌", bronze: "❌", ent: "✅" },
    { f: "White-Label Branding", free: "❌", bronze: "❌", bronze: "❌", ent: "✅" },
  ]},
  { cat: "INTEGRATIONS & APIs", rows: [
    { f: "Local SMS — Auto-send", free: "❌", bronze: "10/mo", silver: "Unlimited", ent: "Unlimited" },
    { f: "Local SMS — SIM Selection", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "SMTP / Resend Email Config", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "WhatsApp Business API", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "UPI Direct Payments (VPA)", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Razorpay / PhonePe Gateway", free: "❌", bronze: "❌", bronze: "❌", ent: "✅" },
    { f: "Payment Links", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Webhook URL Setup", free: "❌", bronze: "❌", bronze: "❌", ent: "✅" },
    { f: "Custom API Endpoints", free: "❌", bronze: "❌", bronze: "❌", ent: "✅" },
    { f: "Data Export API", free: "❌", bronze: "❌", bronze: "❌", ent: "✅" },
  ]},
  { cat: "SECURITY & COMPLIANCE", rows: [
    { f: "Password Login", free: "✅", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "PIN Lock", free: "❌", bronze: "✅", silver: "✅", ent: "✅" },
    { f: "Biometric Authentication", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "System Activity Logs", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Login Audit Trail", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Session Management", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Auto-Logout & Session Locks", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Two-Factor Authentication (2FA)", free: "❌", bronze: "❌", bronze: "❌", ent: "✅" },
    { f: "IP Whitelisting", free: "❌", bronze: "❌", bronze: "❌", ent: "✅" },
    { f: "Immutable Activity Logs", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Audit Log Retention (7yr)", free: "❌", bronze: "❌", bronze: "❌", ent: "✅" },
    { f: "Google Drive Backup", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Export Audit Report", free: "❌", bronze: "❌", bronze: "❌", ent: "✅" },
  ]},
  { cat: "REPORTS & ANALYTICS", rows: [
    { f: "Portfolio Summary Dashboard", free: "❌", bronze: "Basic", silver: "✅", ent: "✅" },
    { f: "Advanced Analytics", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "PAR 30/60/90 Delinquency", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Repayment Rate Tracking", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Monthly Trends Chart", free: "❌", bronze: "Basic", silver: "Detailed", ent: "Custom" },
    { f: "Cash Flow Trends", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Staff & Branch Reports", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Custom Report Generation", free: "❌", bronze: "❌", bronze: "❌", ent: "✅" },
    { f: "AI Hindi Assistant", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
  ]},
  { cat: "SUPPORT", rows: [
    { f: "Email Support", free: "48h", bronze: "24h", silver: "12h", ent: "4h" },
    { f: "Priority Chat Support", free: "❌", bronze: "❌", silver: "✅", ent: "✅" },
    { f: "Dedicated Account Manager", free: "❌", bronze: "❌", bronze: "❌", ent: "✅" },
    { f: "SLA Guarantee", free: "❌", bronze: "❌", bronze: "❌", ent: "✅" },
    { f: "On-Premise Deployment", free: "❌", bronze: "❌", bronze: "❌", ent: "✅" },
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
        <div className="text-emerald-400/60 text-[10px] mb-2">
          Save {Math.round(1 - parseInt(t.annual.replace(/[₹,]/g, "")) / (parseInt(t.monthly.replace(/[₹,]/g, "")) * 12) * 100)}% with annual
        </div>
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
          <li key={j} className="flex items-center gap-2 text-[12px] md:text-[13px] text-white/70">
            <span className="w-5 h-5 rounded-full bg-indigo-500/10 flex items-center justify-center shrink-0">
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
                const isBestFree = row.free === "✅" || row.free.includes("Basic");
                const cells = [
                  { key: 'free', val: row.free, accent: false },
                  { key: 'bronze', val: row.bronze, accent: false },
                  { key: 'silver', val: row.silver, accent: true },
                  { key: 'ent', val: row.ent, accent: false },
                ];
                return (
                  <tr key={ri} className="border-b border-white/[0.02] hover:bg-white/[0.02] transition-colors">
                    <td className="py-2.5 pr-4 text-white/60 sticky left-0 z-10 whitespace-nowrap" style={{ background: "var(--background)" }}>
                      {row.f}
                    </td>
                    {cells.map((c, ci) => {
                      let cls = "px-3 py-2.5 text-center whitespace-nowrap";
                      if (c.val === "✅") cls += " text-emerald-400";
                      else if (c.val === "❌") cls += " text-white/20";
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
              Annual <span className="text-emerald-400/70 text-[10px]">(-33%)</span>
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
            <span className="text-[13px] font-semibold">{showTable ? "Hide" : "Compare All 110 Features"} — Full Breakdown</span>
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
                    10 categories · 110 features · See what each plan includes
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