import { motion } from "motion/react";
import Navbar from "./Navbar";
import Footer from "./Footer";

// Shared layout for legal pages (Privacy, Terms).
// Content is passed as a prop so the same styling wraps both pages.
export default function LegalPage({ title, updated, children }) {
  return (
    <main className="relative bg-black min-h-screen w-screen flex flex-col selection:bg-indigo-500/30 selection:text-white overflow-x-hidden">
      <Navbar />

      <section className="relative z-[2] max-w-3xl mx-auto px-6 pt-32 pb-24">
        <motion.div
          initial={{ opacity: 0, y: 14 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
        >
          <h1 className="text-3xl md:text-4xl font-semibold tracking-[-0.02em] text-white mb-2">
            {title}
          </h1>
          <p className="text-white/30 text-sm mb-10">
            Last updated: {updated}
          </p>

          <div className="space-y-8 text-white/70 text-[15px] leading-relaxed">
            {children}
          </div>
        </motion.div>
      </section>

      <Footer />
    </main>
  );
}

export function LegalSection({ title, children }) {
  return (
    <div>
      <h2 className="text-lg font-semibold text-white tracking-[-0.01em] mb-3">
        {title}
      </h2>
      <div className="text-white/60 leading-relaxed whitespace-pre-line">
        {children}
      </div>
    </div>
  );
}
