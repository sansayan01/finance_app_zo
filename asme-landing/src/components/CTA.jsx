import { useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "motion/react";
import { ArrowRight, Sparkles } from "lucide-react";

const proofs = [
  "Join 10,000+ money-lenders",
  "Replaces notebooks & spreadsheets",
  "4.9 average user rating",
  "Auto interest calculation",
];

export default function CTA() {
  const [proofIndex, setProofIndex] = useState(0);
  const intervalRef = useRef(null);

  useEffect(() => {
    intervalRef.current = setInterval(() => {
      setProofIndex((p) => (p + 1) % proofs.length);
    }, 3000);
    return () => clearInterval(intervalRef.current);
  }, []);

  return (
    <section className="relative py-20 md:py-36 px-6 overflow-hidden border-t border-white/[0.03]">
      <div className="absolute inset-0 bg-gradient-to-b from-indigo-500/[0.03] via-transparent to-transparent pointer-events-none" />
      <motion.div
        animate={{ scale: [1, 1.08, 1] }}
        transition={{ duration: 5, repeat: Infinity, ease: "ease-in-out" }}
        className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[700px] h-[400px] bg-indigo-500/5 rounded-full blur-[120px] pointer-events-none"
      />
      <div className="max-w-4xl mx-auto relative z-[1]">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
          className="liquid-glass rounded-3xl p-8 md:p-16 text-center relative overflow-hidden"
        >
          <motion.div
            animate={{ scale: [1, 1.15, 1], opacity: [0.5, 0.8, 0.5] }}
            transition={{ duration: 4, repeat: Infinity, ease: "ease-in-out" }}
            className="absolute -top-20 -right-20 w-40 h-40 bg-indigo-500/15 rounded-full blur-[60px] pointer-events-none"
          />
          <motion.div
            animate={{ scale: [1.15, 1, 1.15], opacity: [0.4, 0.7, 0.4] }}
            transition={{ duration: 4, repeat: Infinity, ease: "ease-in-out", delay: 0.5 }}
            className="absolute -bottom-20 -left-20 w-40 h-40 bg-cyan-500/10 rounded-full blur-[60px] pointer-events-none"
          />
          <div className="relative z-[1]">
            <motion.div
              initial={{ scale: 0 }}
              whileInView={{ scale: 1 }}
              viewport={{ once: true }}
              transition={{ delay: 0.2, type: "spring", stiffness: 200 }}
              className="hidden md:flex w-12 h-12 rounded-2xl bg-gradient-to-br from-indigo-500/20 to-indigo-400/10 border border-indigo-500/25 items-center justify-center mx-auto mb-6"
            >
              <Sparkles className="w-6 h-6 text-indigo-300" />
            </motion.div>
            <h2
              style={{ fontFamily: "\u0027Instrument Serif\u0027, serif" }}
              className="text-[28px] md:text-[44px] font-medium tracking-[-0.01em] leading-[1.15] mb-4"
            >
              Ready to Start Your{
              } <span className="gradient-brand">Digital Ledger</span>?
            </h2>
            <p className="text-white/70 text-sm md:text-base max-w-md mx-auto mb-6 leading-relaxed">
              Join thousands of money-lenders who've replaced their notebooks with MicroFlow Pro. Start with 2 months Silver FREE — no credit card required.
            </p>
            <div className="h-5 mb-8 flex items-center justify-center">
              <AnimatePresence mode="wait">
                <motion.span
                  key={proofIndex}
                  initial={{ opacity: 0, y: 8, filter: "blur(4px)" }}
                  animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
                  exit={{ opacity: 0, y: -8, filter: "blur(4px)" }}
                  transition={{ duration: 0.35, ease: [0.16, 1, 0.3, 1] }}
                  className="text-indigo-400/70 text-xs font-medium tracking-wide"
                >
                  {proofs[proofIndex]}
                </motion.span>
              </AnimatePresence>
            </div>
            <motion.a
              href="#"
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              className="btn-shimmer inline-flex items-center gap-2 px-8 py-3.5 rounded-full bg-gradient-to-r from-indigo-500 to-indigo-400 text-white text-[14px] font-medium hover:shadow-2xl hover:shadow-indigo-500/25 transition-all duration-300 cursor-pointer"
            >
              Start Free Trial
              <ArrowRight className="w-4 h-4" />
            </motion.a>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
