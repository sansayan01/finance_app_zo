import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Plus } from "lucide-react";

const tags = ["\uD83D\uDCBC", "\uD83C\uDFAF", "\uD83D\uDCE1", "\uD83D\uDCCD", "\uD83D\uDD12", "\uD83D\uDCAC"];
const tagAccents = [
  "border-indigo-500/15 bg-indigo-500/8",
  "border-cyan-500/15 bg-cyan-500/8",
  "border-emerald-500/15 bg-emerald-500/8",
  "border-amber-500/15 bg-amber-500/8",
  "border-rose-500/15 bg-rose-500/8",
  "border-violet-500/15 bg-violet-500/8",
];
const ansLineColors = [
  "#818cf8", "#22d3ee", "#34d399", "#f59e0b", "#f43f5e", "#a78bfa",
];

const faqs = [
  { q: "What is MicroFlow Pro?", a: "MicroFlow Pro is a comprehensive SaaS platform designed for MFIs and Savings Groups. It enables field staff to manage collections, track members, and sync data \u2014 even without internet." },
  { q: "Can I try before buying?", a: "Absolutely! We offer a 14-day free trial with full access to all Professional plan features. No credit card required." },
  { q: "Does it work without internet?", a: "Yes! Our Offline-First Engine lets staff record collections, log visits, and capture GPS data entirely offline. Everything syncs automatically when connectivity is restored." },
  { q: "How does GPS tracking work?", a: "Every collection and visit is tagged with precise GPS coordinates. Branch managers can verify staff presence via the dashboard, ensuring accountability." },
  { q: "Is my data secure?", a: "Security is our top priority. We use enterprise-grade Row Level Security, end-to-end encryption, and branch-level data isolation to protect your information." },
  { q: "What support options are available?", a: "All plans include email support. Professional and Enterprise plans include priority support with dedicated account management and SLA guarantees." },
];

export default function FAQ() {
  const [openIndex, setOpenIndex] = useState(null);
  const toggle = (i) => setOpenIndex(openIndex === i ? null : i);

  return (
    <section className="relative py-20 md:py-36 px-6 overflow-hidden border-t border-white/[0.03]" id="faq">
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[400px] h-[300px] bg-indigo-500/3 rounded-full blur-[100px] pointer-events-none" />
      <div className="max-w-3xl mx-auto relative z-[1]">
        <div className="text-center mb-10 md:mb-14">
          <motion.span
            initial={{ opacity: 0, y: 8 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.05 }}
            className="inline-block text-indigo-400/80 text-[10px] font-medium tracking-[0.25em] uppercase mb-5"
          >
            Got Questions?
          </motion.span>
          <motion.h2
            initial={{ opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
            style={{ fontFamily: "\u0027Instrument Serif\u0027, serif" }}
            className="text-[28px] md:text-[44px] font-medium tracking-[-0.01em] leading-[1.15]"
          >
            Frequently Asked <span className="gradient-brand">Questions</span>
          </motion.h2>
        </div>
        <div className="space-y-2.5">
          {faqs.map((faq, i) => {
            const isOpen = openIndex === i;
            return (
              <motion.div
                key={i}
                initial={{ opacity: 0, y: 12 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.4, delay: i * 0.04 }}
                className={
                  "rounded-xl border transition-all duration-300 overflow-hidden " +
                  (isOpen
                    ? "border-white/[0.08] bg-white/[0.02] shadow-lg shadow-indigo-500/5"
                    : "border-white/[0.04] hover:border-white/[0.08] bg-white/[0.01]")
                }
              >
                <button
                  onClick={() => toggle(i)}
                  className="w-full flex items-center gap-3 px-5 md:px-6 py-4 md:py-5 text-left min-h-[52px]"
                >
                  <span
                    className={
                      "shrink-0 w-8 h-8 rounded-lg flex items-center justify-center text-sm border transition-all duration-300 " +
                      tagAccents[i] +
                      (isOpen ? " scale-110 shadow-sm" : "")
                    }
                    style={{ filter: isOpen ? "saturate(1.2)" : "saturate(0.6)" }}
                  >
                    {tags[i]}
                  </span>
                  <span
                    className={
                      "flex-1 text-[14px] leading-snug font-medium transition-colors duration-300 " +
                      (isOpen ? "text-white" : "text-white/70")
                    }
                  >
                    {faq.q}
                  </span>
                  <motion.span
                    animate={{ rotate: isOpen ? 135 : 0 }}
                    transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
                    className={
                      "shrink-0 w-7 h-7 rounded-full flex items-center justify-center transition-all duration-300 " +
                      (isOpen
                        ? "bg-indigo-500/15 text-indigo-300"
                        : "bg-white/[0.03] text-white/30")
                    }
                  >
                    <Plus className="w-3.5 h-3.5" />
                  </motion.span>
                </button>
                <AnimatePresence initial={false}>
                  {isOpen && (
                    <motion.div
                      key="answer"
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: "auto", opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
                      className="overflow-hidden"
                    >
                      <div className="px-5 md:px-6 pb-4 md:pb-5">
                        <motion.div
                          initial={{ scaleX: 0 }}
                          animate={{ scaleX: 1 }}
                          transition={{ duration: 0.4, delay: 0.1 }}
                          className="h-[2px] rounded-full mb-3 origin-left"
                          style={{
                            background: "linear-gradient(90deg, " + ansLineColors[i] + ", transparent)",
                          }}
                        />
                        <motion.p
                          initial={{ opacity: 0, y: 6 }}
                          animate={{ opacity: 1, y: 0 }}
                          transition={{ duration: 0.3, delay: 0.12 }}
                          className="text-white/60 text-[13px] leading-relaxed"
                        >
                          {faq.a}
                        </motion.p>
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </motion.div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
