import { motion } from "motion/react";
import Navbar from "../components/Navbar";
import Footer from "../components/Footer";

export default function StatusPage() {
  const today = new Date().toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });

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
            System Status
          </h1>
          <p className="text-white/30 text-sm mb-10">
            Last checked: {today}
          </p>

          <div className="space-y-4">
            <div className="border border-white/[0.06] rounded-xl p-5 flex items-center gap-4">
              <div className="w-3 h-3 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.5)]" />
              <div>
                <h3 className="text-white font-medium">All Systems Operational</h3>
                <p className="text-white/40 text-sm mt-0.5">
                  API, databases, and backup services are running normally.
                </p>
              </div>
            </div>
          </div>

          <div className="mt-6 text-white/40 text-sm space-y-1">
            <p>Uptime: 99.9%</p>
            <p>Monitoring: Active across all regions</p>
          </div>

          <p className="text-white/30 text-xs pt-8">
            Experience an issue?{" "}
            <a href="mailto:support@microflow.pro" className="text-indigo-400 hover:text-indigo-300">
              Let us know
            </a>
            .
          </p>
        </motion.div>
      </section>

      <Footer />
    </main>
  );
}
