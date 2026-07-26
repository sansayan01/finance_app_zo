import { motion } from "motion/react";
import Navbar from "../components/Navbar";
import Footer from "../components/Footer";

export default function BlogPage() {
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
            Blog
          </h1>
          <p className="text-white/30 text-sm mb-10">
            Coming soon
          </p>

          <div className="border border-white/[0.06] rounded-xl p-8 text-center">
            <div className="text-4xl mb-4 opacity-20">&#9998;</div>
            <p className="text-white/50 text-[15px] leading-relaxed max-w-md mx-auto">
              We're working on sharing practical tips, guides, and insights for
              money-lenders. From managing borrower relationships to optimizing
              your collections — it'll be here soon.
            </p>
          </div>

          <p className="text-white/30 text-xs pt-8">
            Want to be notified when we publish?{" "}
            <a href="mailto:hello@microflow.pro" className="text-indigo-400 hover:text-indigo-300">
              Say hello
            </a>
            .
          </p>
        </motion.div>
      </section>

      <Footer />
    </main>
  );
}
