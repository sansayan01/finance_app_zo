import { NavLink, Link, Outlet, useLocation } from "react-router-dom";
import {
  BookOpen, Shield, Users, UserCircle, Smartphone,
  ChevronLeft, Play, Menu, X, Globe, Wallet, BarChart3
} from "lucide-react";
import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "motion/react";
import DocsBackground from "../../components/DocsBackground";
import { docsContent, languages } from "./data/docsContent";

export default function DocsLayout() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [lang, setLang] = useState(localStorage.getItem("docs_lang") || "en");
  const location = useLocation();

  useEffect(() => { setSidebarOpen(false); }, [location.pathname]);

  // Fallback to English if translation for chosen language is missing
  const t = docsContent[lang] || docsContent.en;

  const portalsList = [
    { path: "/docs", label: t.common.allGuides, icon: BookOpen, end: true },
    { path: "/docs/getting-started", label: t.home.portals.admin.title, icon: Shield },
    { path: "/docs/managing-borrowers", label: t.home.portals.manager.title, icon: Users },
    { path: "/docs/recording-loans", label: "Recording Loans", icon: Wallet },
    { path: "/docs/tracking-repayments", label: "Tracking Repayments", icon: BarChart3 },
    { path: "/docs/sms-reminders", label: "SMS Reminders", icon: UserCircle },
    { path: "/docs/portfolio-insights", label: "Portfolio Insights", icon: Smartphone },
  ];

  return (
    <div className="relative min-h-screen text-white overflow-x-hidden">
      {/* ─── Custom Animated Space Background (Tarakta Varakta!) ─── */}
      <DocsBackground />

      {/* Cyber Grid over overlay for styling */}
      <div className="fixed inset-0 z-[2] pointer-events-none" />

      {/* Noise texture overlay */}
      <div className="noise-overlay !z-[3]" />

      {/* Floating orbs */}
      <div className="fixed inset-0 z-[2] pointer-events-none overflow-hidden">
        <div className="floating-orb-docs" />
        <div className="floating-orb-docs" />
        <div className="floating-orb-docs" />
      </div>

      {/* Large glow domes */}
      <div className="fixed top-0 right-0 w-[600px] h-[600px] -translate-y-1/3 translate-x-1/4 z-[2] pointer-events-none">
        <div className="w-full h-full rounded-full bg-indigo-500 blur-[150px] opacity-[0.06]" />
      </div>
      <div className="fixed bottom-0 left-0 w-[500px] h-[500px] translate-y-1/3 -translate-x-1/4 z-[2] pointer-events-none">
        <div className="w-full h-full rounded-full bg-cyan-500 blur-[120px] opacity-[0.04]" />
      </div>

      {/* ─── Docs Header ─── */}
      <header className="relative z-40 fixed top-0 left-0 right-0 frosted-header">
        <div className="absolute inset-x-0 bottom-0 h-px bg-gradient-to-r from-transparent via-indigo-500/15 to-transparent" />
        <div className="max-w-7xl mx-auto px-4 h-14 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <button
              onClick={() => setSidebarOpen(!sidebarOpen)}
              className="md:hidden text-white/60 hover:text-white p-1 cursor-pointer"
            >
              {sidebarOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
            </button>
            <NavLink to="/" className="flex items-center gap-2 text-secondary hover:text-primary transition-colors">
              <ChevronLeft className="w-4 h-4" />
              <span className="text-sm">{t.common.backToHome}</span>
            </NavLink>
            <span className="text-white/8">/</span>
            <span className="text-sm font-medium text-primary tracking-wide">{t.common.documentation}</span>
          </div>

          <div className="flex items-center gap-4">
            {/* Language Selector Dropdown */}
            <div className="relative flex items-center gap-1.5 bg-white/[0.03] border border-white/[0.06] rounded-xl px-2.5 py-1.5 hover:bg-white/[0.05] transition-all">
              <Globe className="w-3.5 h-3.5 text-indigo-400" />
              <select
                value={lang}
                onChange={(e) => {
                  setLang(e.target.value);
                  localStorage.setItem("docs_lang", e.target.value);
                }}
                className="bg-transparent text-white/80 text-xs font-semibold focus:outline-none cursor-pointer pr-4 appearance-none relative"
                style={{
                  backgroundImage: `url("data:image/svg+xml;charset=UTF-8,%3Csvg xmlns='http://www.w3.org/2000/svg' width='10' height='10' viewBox='0 0 24 24' fill='none' stroke='white' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'%3E%3C/polyline%3E%3C/svg%3E")`,
                  backgroundRepeat: "no-repeat",
                  backgroundPosition: "right center",
                }}
              >
                {languages.map((l) => (
                  <option key={l.code} value={l.code} className="bg-neutral-950 text-white py-1">
                    {l.nativeName}
                  </option>
                ))}
              </select>
            </div>

            <a
              href="https://www.youtube.com/@Microflow_Pro"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-2 text-xs px-3.5 py-1.5 rounded-full bg-red-500/10 border border-red-500/20 text-red-400 hover:bg-red-500/20 hover:text-red-300 transition-all font-medium"
            >
              <Play className="w-3 h-3 fill-red-400" />
              <span className="hidden sm:inline">{t.common.youtube}</span>
            </a>
          </div>
        </div>
      </header>

      {/* ─── Sidebar + Content ─── */}
      <div className="relative z-10 flex pt-14 min-h-screen">
        {/* Sidebar Overlay (mobile) */}
        <AnimatePresence>
          {sidebarOpen && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 bg-black/70 z-30 md:hidden"
              onClick={() => setSidebarOpen(false)}
            />
          )}
        </AnimatePresence>

        {/* Sidebar — glass with floating feel */}
        <aside className={`
          fixed top-14 left-0 z-30 h-[calc(100vh-3.5rem)]
          w-64 frosted-sidebar overflow-y-auto transition-transform duration-300
          ${sidebarOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0'}
        `}>
          <div className="absolute inset-0 z-0 dot-grid pointer-events-none" />
          <div className="absolute inset-y-0 right-0 w-px bg-gradient-to-b from-transparent via-indigo-500/10 to-transparent" />

          <div className="relative z-10 p-4 space-y-1">
            {/* Logo section */}
            <div className="flex items-center gap-2.5 px-3 pb-4 pt-1">
              <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-indigo-500/15 to-violet-500/5 border border-indigo-500/10 flex items-center justify-center">
                <BookOpen className="w-3.5 h-3.5 text-indigo-300" />
              </div>
              <span className="text-sm font-semibold text-secondary">{t.common.portalGuides}</span>
            </div>

            <div className="text-[10px] font-semibold text-tertiary uppercase tracking-[0.15em] px-3 pb-1.5">
              {t.common.portals}
            </div>
            {portalsList.map((p) => (
              <NavLink
                key={p.path}
                to={p.path}
                end={p.end}
                className={({ isActive }) =>
                  `flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-200 ${
                    isActive
                      ? 'bg-indigo-500/8 text-primary border border-indigo-500/10'
                      : 'text-secondary hover:text-white/70 hover:bg-white/[0.02] border border-transparent'
                  }`
                }
              >
                <p.icon className="w-4 h-4 shrink-0" />
                {p.label}
              </NavLink>
            ))}

            <div className="doc-divider !my-4" />

            <div className="text-[10px] font-semibold text-tertiary uppercase tracking-[0.15em] px-3 pb-1.5">
              {t.common.quickLinks}
            </div>
            <QuickLink href="/docs/recording-loans" icon={Play} label={t.common.watchVideo}>
              {lang === "hi" ? "पहला ऋण कैसे बनाएं" : lang === "bn" ? "প্রথম ঋণ তৈরি" : "Create a Loan"}
            </QuickLink>
            <QuickLink href="/docs/managing-borrowers" icon={Play} label={t.common.watchVideo}>
              {lang === "hi" ? "उधारी कैसे जोड़ें" : lang === "bn" ? "ধারক যোগ করুন" : "Add a Borrower"}
            </QuickLink>
            <QuickLink href="/docs/tracking-repayments" icon={Play} label={t.common.watchVideo}>
              {lang === "hi" ? "भुगतान कैसे दर्ज करें" : lang === "bn" ? "পেমেন্ট লগ করুন" : "Record a Repayment"}
            </QuickLink>
            <QuickLink href="/docs/portfolio-insights" icon={Play} label={t.common.watchVideo}>
              {lang === "hi" ? "पोर्टफोलियो देखें" : lang === "bn" ? "পোর্টফোলিও দেখুন" : "View Portfolio"}
            </QuickLink>
          </div>
        </aside>

        {/* Main Content */}
        <main className="flex-1 min-w-0 md:ml-64">
          <div className="relative">
            {/* Subtle top gradient — indigo glow */}
            <div className="absolute top-0 inset-x-0 h-32 bg-gradient-to-b from-indigo-500/[0.03] via-indigo-500/[0.01] to-transparent pointer-events-none" />

            <div className="relative max-w-4xl mx-auto px-4 sm:px-8 lg:px-10 py-8 sm:py-12">
              {/* Pass the lang state to subpages via React context context flow */}
              <Outlet context={{ lang }} />
            </div>
          </div>
        </main>
      </div>
    </div>
  );
}

function QuickLink({ href, icon: Icon, children }) {
  return (
    <Link
      to={href}
      className="flex items-center gap-3 px-3 py-2 rounded-xl text-sm text-white/35 hover:text-indigo-300 hover:bg-indigo-500/5 transition-all duration-200"
    >
      <Icon className="w-3 h-3" />
      {children}
    </Link>
  );
}
