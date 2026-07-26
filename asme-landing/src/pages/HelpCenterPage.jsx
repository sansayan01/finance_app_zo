import { motion } from "motion/react";
import { Link } from "react-router-dom";
import Navbar from "../components/Navbar";
import Footer from "../components/Footer";

const topics = [
  {
    title: "Getting Started",
    description: "Installation, account setup, and your first steps with MicroFlow Pro.",
    route: "/docs/getting-started",
  },
  {
    title: "Managing Borrowers",
    description: "Add, edit, and organize borrower information in your ledger.",
    route: "/docs/managing-borrowers",
  },
  {
    title: "Recording Loans",
    description: "Create loans, set interest terms, and track disbursements.",
    route: "/docs/recording-loans",
  },
  {
    title: "Tracking Repayments",
    description: "Log repayments, view schedules, and manage overdue accounts.",
    route: "/docs/tracking-repayments",
  },
  {
    title: "SMS Reminders",
    description: "Set up automatic payment reminders for your borrowers.",
    route: "/docs/sms-reminders",
  },
  {
    title: "Portfolio Insights",
    description: "Understand your lending portfolio with reports and analytics.",
    route: "/docs/portfolio-insights",
  },
];

export default function HelpCenterPage() {
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
            Help Center
          </h1>
          <p className="text-white/30 text-sm mb-10">
            Browse our documentation to find answers and learn how to get the
            most out of MicroFlow Pro.
          </p>

          <div className="space-y-4">
            {topics.map((topic) => (
              <Link
                key={topic.route}
                to={topic.route}
                className="block group"
              >
                <div className="border border-white/[0.06] rounded-xl p-5 hover:border-indigo-500/30 hover:bg-white/[0.02] transition-all duration-200">
                  <h3 className="text-white font-medium mb-1 group-hover:text-indigo-400 transition-colors">
                    {topic.title}
                  </h3>
                  <p className="text-white/40 text-sm">{topic.description}</p>
                </div>
              </Link>
            ))}
          </div>

          <p className="text-white/30 text-xs pt-8">
            Can't find what you need?{" "}
            <Link to="/contact" className="text-indigo-400 hover:text-indigo-300">
              Contact our support team
            </Link>
            .
          </p>
        </motion.div>
      </section>

      <Footer />
    </main>
  );
}
