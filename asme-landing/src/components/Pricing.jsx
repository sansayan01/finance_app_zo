import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Check } from "lucide-react";

const tiers = [
  {
    name: "Starter",
    monthly: "\u20b9999",
    annual: "\u20b97,999",
    period: "/mo",
    desc: "For new lenders starting out.",
    features: [
      "Up to 50 Borrowers",
      "Single Ledger",
      "Basic Interest Calculator",
      "SMS Reminders",
      "Email Support",
    ],
    popular: false,
    cta: "Get Started",
  },
  {
    name: "Professional",
    monthly: "\u20b92,999",
    annual: "\u20b923,999",
    period: "/mo",
    desc: "For active lenders with growing books.",
    features: [
      "Up to 500 Borrowers",
      "Advanced Analytics",
      "Offline Mode",
      "Priority Support",
      "Custom Interest Rates",
    ],
    popular: true,
    cta: "Start Free Trial",
  },
  {
    name: "Enterprise",
    monthly: "Custom",
    annual: "Custom",
    period: "",
    desc: "For established lenders managing large books.",
    features: [
      "Unlimited Borrowers",
      "Dedicated Support",
      "Custom Integrations",
      "On-Premise Option",
    ],
    popular: false,
    cta: "Contact Sales",
  },
];

/* ── Stagger variants for mobile card features ── */
const featureListVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.06, delayChildren: 0.12 },
  },
};

const featureItemVariants = {
  hidden: { opacity: 0, x: -14 },
  visible: {
    opacity: 1,
    x: 0,
    transition: { duration: 0.35, ease: [0.16, 1, 0.3, 1] },
  },
};

/* ── Card variants for mobile AnimatePresence ── */
const cardVariants = {
  enter: { opacity: 0, y: 24, scale: 0.96 },
  center: { opacity: 1, y: 0, scale: 1, transition: { duration: 0.4, ease: [0.16, 1, 0.3, 1] } },
  exit: { opacity: 0, y: -16, scale: 0.96, transition: { duration: 0.25, ease: [0.16, 1, 0.3, 1] } },
};

export default function Pricing() {
  const [annual, setAnnual] = useState(false);
  const [selectedTier, setSelectedTier] = useState(1); // Professional preselected

  return (
    <section
      className="relative py-20 md:py-36 px-6 section-mesh overflow-hidden border-t border-white/[0.03]"
      id="pricing"
    >
      {/* Background glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-indigo-500/4 rounded-full blur-[150px] pointer-events-none" />

      <div className="max-w-5xl mx-auto relative z-[1]">
        {/* ── Header ── */}
        <div className="text-center mb-10 md:mb-14">
          <motion.span
            initial={{ opacity: 0, y: 8 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.05 }}
            className="inline-block text-indigo-400/80 text-[10px] md:text-[11px] font-medium tracking-[0.25em] uppercase mb-5"
          >
            Simple Pricing
          </motion.span>
          <motion.h2
            initial={{ opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
            style={{ fontFamily: "'Instrument Serif', serif" }}
            className="text-[28px] md:text-[44px] font-medium tracking-[-0.01em] leading-[1.15] mb-6"
          >
            Transparent <span className="gradient-brand">Pricing</span>
          </motion.h2>
          <motion.p
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            transition={{ delay: 0.15 }}
            className="text-white/50 text-sm mt-3 max-w-md mx-auto"
          >
            Affordable plans for every money-lender. Start free, upgrade when you need more.
          </motion.p>

          {/* ── Annual/Monthly Toggle ── */}
          <motion.div
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            className="flex items-center justify-center gap-3 text-sm"
          >
            <span className={"transition-colors duration-300 " + (annual ? "text-white/40" : "text-white/85")}>
              Monthly
            </span>
            <button
              onClick={() => setAnnual(!annual)}
              className={
                "relative w-12 h-6 rounded-full transition-all duration-300 " +
                (annual ? "bg-indigo-500 shadow-lg shadow-indigo-500/25" : "bg-white/10")
              }
              aria-label={annual ? "Switch to monthly billing" : "Switch to annual billing"}
            >
              <span
                className={
                  "absolute top-1 left-1 w-4 h-4 rounded-full bg-white transition-all duration-300 shadow-sm " +
                  (annual ? "left-7" : "left-1")
                }
              />
            </button>
            <span className={"transition-colors duration-300 " + (annual ? "text-white/85" : "text-white/40")}>
              Annual
            </span>
          </motion.div>
        </div>

        {/* ════════════════════════════════════════ */}
        {/* MOBILE LAYOUT — Pill Tabs + Single Card */}
        {/* ════════════════════════════════════════ */}
        <div className="md:hidden">
          {/* Pill-shaped tab bar */}
          <div className="flex justify-center mb-6">
            <div className="glass-pill inline-flex gap-1 p-1 bg-white/[0.03] border border-white/[0.05]">
              {tiers.map((t, i) => (
                <button
                  key={i}
                  onClick={() => setSelectedTier(i)}
                  className={
                    "relative px-4 py-2 rounded-full text-[12px] font-medium transition-all duration-300 min-h-[36px] " +
                    (i === selectedTier
                      ? "text-white shadow-lg shadow-indigo-500/20"
                      : "text-white/40 hover:text-white/70")
                  }
                >
                  {i === selectedTier && (
                    <motion.span
                      layoutId="activePill"
                      className="absolute inset-0 rounded-full bg-gradient-to-r from-indigo-500 to-indigo-400"
                      transition={{ type: "spring", stiffness: 380, damping: 30 }}
                    />
                  )}
                  <span className="relative z-[1]">{t.name}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Single animated card */}
          <AnimatePresence mode="wait">
            <motion.div
              key={selectedTier}
              variants={cardVariants}
              initial="enter"
              animate="center"
              exit="exit"
              className={
                "relative rounded-2xl p-6 flex flex-col " +
                (tiers[selectedTier].popular
                  ? "bg-gradient-to-b from-indigo-500/[0.07] to-transparent border border-indigo-500/25"
                  : "border border-white/[0.04] bg-white/[0.01]")
              }
            >
              {/* Popular badge */}
              {tiers[selectedTier].popular && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-4 py-1 rounded-full bg-gradient-to-r from-indigo-500 to-indigo-400 text-white text-[9px] font-semibold uppercase tracking-[0.08em] shadow-lg shadow-indigo-500/30 whitespace-nowrap">
                  Most Popular
                </div>
              )}

              {/* Plan name */}
              <div className="text-white/40 text-[11px] font-medium uppercase tracking-[0.08em] mb-2">
                {tiers[selectedTier].name}
              </div>

              {/* Price with AnimatePresence for annual/monthly switch */}
              <AnimatePresence mode="wait">
                <motion.div
                  key={annual ? "a-mobile" : "m-mobile"}
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -8 }}
                  transition={{ duration: 0.2 }}
                  className="mb-1"
                >
                  <span className="text-3xl font-semibold tracking-[-0.03em] text-white">
                    {annual ? tiers[selectedTier].annual : tiers[selectedTier].monthly}
                  </span>
                  {tiers[selectedTier].period && (
                    <span className="text-white/30 text-sm ml-1">
                      {annual ? "/yr" : tiers[selectedTier].period}
                    </span>
                  )}
                </motion.div>
              </AnimatePresence>

              <p className="text-white/50 text-[12px] mt-1 mb-6">{tiers[selectedTier].desc}</p>

              {/* Staggered features */}
              <motion.ul
                key={`feat-${selectedTier}`}
                variants={featureListVariants}
                initial="hidden"
                animate="visible"
                className="space-y-3 mb-8 flex-1"
              >
                {tiers[selectedTier].features.map((f, j) => (
                  <motion.li
                    key={j}
                    variants={featureItemVariants}
                    className="flex items-center gap-2.5 text-[13px] text-white/70"
                  >
                    <span className="w-5 h-5 rounded-full bg-indigo-500/10 flex items-center justify-center shrink-0">
                      <Check className="w-3 h-3 text-indigo-400" />
                    </span>
                    {f}
                  </motion.li>
                ))}
              </motion.ul>

              <button
                className={
                  "w-full py-3 min-h-[44px] rounded-full text-[13px] font-medium transition-all duration-300 btn-shimmer " +
                  (tiers[selectedTier].popular
                    ? "bg-gradient-to-r from-indigo-500 to-indigo-400 text-white hover:shadow-xl hover:shadow-indigo-500/20 hover:scale-[1.02]"
                    : "border border-white/[0.1] text-white/70 hover:border-white/30 hover:bg-white/[0.02] hover:text-white/90")
                }
              >
                {tiers[selectedTier].cta}
              </button>
            </motion.div>
          </AnimatePresence>
        </div>

        {/* ════════════════════════════════ */}
        {/* DESKTOP LAYOUT — 3-Column Grid  */}
        {/* ════════════════════════════════ */}
        <div className="hidden md:grid md:grid-cols-3 gap-4 md:gap-5 items-start">
          {tiers.map((t, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, y: 24 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1], delay: i * 0.1 }}
              className={
                "relative rounded-2xl p-6 md:p-8 flex flex-col transition-all duration-500 group " +
                (t.popular
                  ? "bg-gradient-to-b from-indigo-500/[0.07] to-transparent border border-indigo-500/25 hover:border-indigo-400/40 hover:shadow-2xl hover:shadow-indigo-500/10"
                  : "border border-white/[0.04] hover:border-white/[0.1] bg-white/[0.01]")
              }
            >
              {/* Popular badge */}
              {t.popular && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-4 py-1 rounded-full bg-gradient-to-r from-indigo-500 to-indigo-400 text-white text-[9px] font-semibold uppercase tracking-[0.08em] shadow-lg shadow-indigo-500/30 whitespace-nowrap">
                  Most Popular
                </div>
              )}

              {/* Plan name */}
              <div className="text-white/40 text-[11px] font-medium uppercase tracking-[0.08em] mb-2">{t.name}</div>

              {/* Price */}
              <AnimatePresence mode="wait">
                <motion.div
                  key={annual ? "a" + i : "m" + i}
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -8 }}
                  transition={{ duration: 0.2 }}
                  className="mb-1"
                >
                  <span className="text-3xl md:text-[42px] font-semibold tracking-[-0.03em] text-white">
                    {annual ? t.annual : t.monthly}
                  </span>
                  {t.period && (
                    <span className="text-white/30 text-sm ml-1">{annual ? "/yr" : t.period}</span>
                  )}
                </motion.div>
              </AnimatePresence>

              <p className="text-white/50 text-[12px] mt-1 mb-6">{t.desc}</p>

              {/* Static feature list (desktop uses group-hover, not stagger) */}
              <ul className="space-y-3 mb-8 flex-1">
                {t.features.map((f, j) => (
                  <li
                    key={j}
                    className="flex items-center gap-2.5 text-[13px] text-white/70 group-hover:text-white/75 transition-colors duration-300"
                  >
                    <span className="w-5 h-5 rounded-full bg-indigo-500/10 flex items-center justify-center shrink-0">
                      <Check className="w-3 h-3 text-indigo-400" />
                    </span>
                    {f}
                  </li>
                ))}
              </ul>

              <button
                className={
                  "w-full py-3 md:py-2.5 min-h-[44px] rounded-full text-[13px] font-medium transition-all duration-300 btn-shimmer " +
                  (t.popular
                    ? "bg-gradient-to-r from-indigo-500 to-indigo-400 text-white hover:shadow-xl hover:shadow-indigo-500/20 hover:scale-[1.02]"
                    : "border border-white/[0.1] text-white/70 hover:border-white/30 hover:bg-white/[0.02] hover:text-white/90")
                }
              >
                {t.cta}
              </button>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
