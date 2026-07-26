import { useEffect, useState } from "react";
import { Routes, Route } from "react-router-dom";
import { motion, AnimatePresence } from "motion/react";
import { ChevronUp } from "lucide-react";
import BackgroundVideo from "./components/BackgroundVideo";
import Navbar from "./components/Navbar";
import Hero from "./components/Hero";
import Features from "./components/Features";
import TrustMarquee from "./components/TrustMarquee";
import Stats from "./components/Stats";
import HowItWorks from "./components/HowItWorks";
import Testimonials from "./components/Testimonials";
import Pricing from "./components/Pricing";
import FAQ from "./components/FAQ";
import CTA from "./components/CTA";
import Footer from "./components/Footer";
import ConfirmPage from "./pages/ConfirmPage";
import PrivacyPage from "./pages/PrivacyPage";
import TermsPage from "./pages/TermsPage";
import AboutPage from "./pages/AboutPage";
import SecurityPage from "./pages/SecurityPage";
import ContactPage from "./pages/ContactPage";
import HelpCenterPage from "./pages/HelpCenterPage";
import BlogPage from "./pages/BlogPage";
import StatusPage from "./pages/StatusPage";
import DocsLayout from "./pages/docs/DocsLayout";
import DocsHome from "./pages/docs/DocsHome";
import GettingStartedGuide from "./pages/docs/guides/GettingStartedGuide";
import BorrowersGuide from "./pages/docs/guides/BorrowersGuide";
import RepaymentsGuide from "./pages/docs/guides/RepaymentsGuide";
import LoansGuide from "./pages/docs/guides/LoansGuide";
import SMSRemindersGuide from "./pages/docs/guides/SMSRemindersGuide";
import PortfolioInsightsGuide from "./pages/docs/guides/PortfolioInsightsGuide";

export default function App() {
  const [backTop, setBackTop] = useState(false);

  useEffect(() => {
    const onScroll = () => {
      setBackTop(window.scrollY > 600);
      const h = document.documentElement;
      const pct = (window.scrollY / (h.scrollHeight - h.clientHeight)) * 100;
      const bar = document.getElementById("scroll-bar");
      if (bar) bar.style.width = pct + "%";
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const scrollToTop = () => window.scrollTo({ top: 0, behavior: "smooth" });

  return (
    <Routes>
      <Route path="/confirm" element={<ConfirmPage />} />
      <Route path="/privacy" element={<PrivacyPage />} />
      <Route path="/terms" element={<TermsPage />} />
      <Route path="/about" element={<AboutPage />} />
      <Route path="/security" element={<SecurityPage />} />
      <Route path="/contact" element={<ContactPage />} />
      <Route path="/help" element={<HelpCenterPage />} />
      <Route path="/blog" element={<BlogPage />} />
      <Route path="/status" element={<StatusPage />} />

      {/* Docs section — clean layout with sidebar */}
      <Route path="/docs" element={<DocsLayout />}>
        <Route index element={<DocsHome />} />
        <Route path="getting-started" element={<GettingStartedGuide />} />
        <Route path="managing-borrowers" element={<BorrowersGuide />} />
        <Route path="recording-loans" element={<LoansGuide />} />
        <Route path="tracking-repayments" element={<RepaymentsGuide />} />
        <Route path="sms-reminders" element={<SMSRemindersGuide />} />
        <Route path="portfolio-insights" element={<PortfolioInsightsGuide />} />
      </Route>

      <Route path="*" element={
    <main className="relative bg-black min-h-screen w-screen flex flex-col selection:bg-indigo-500/30 selection:text-white overflow-x-hidden">
      {/* Full-page fixed video background — same as hero, visible across all sections */}
      <BackgroundVideo />

      {/* Dark gradient overlay — ensures text readability while letting video ambiance through */}
      <div className="fixed inset-0 z-[1] pointer-events-none bg-gradient-to-b from-black/30 via-black/50 to-black/80" />

      {/* Floating animated orbs */}
      <div className="fixed inset-0 z-0 pointer-events-none">
        <div className="floating-orb" />
        <div className="floating-orb" />
        <div className="floating-orb" />
      </div>

      {/* Subtle noise texture */}
      <div className="noise-overlay" />

      {/* Scroll progress bar */}
      <div id="scroll-progress">
        <div className="bar" id="scroll-bar" />
      </div>

      {/* Navbar — fixed at top */}
      <Navbar />

      {/* Hero Section */}
      <section className="relative min-h-[100dvh] w-screen flex flex-col overflow-hidden shrink-0 z-[2]">
        <Hero />
      </section>

      {/* Scrollable Content — semi-transparent bg lets video show through */}
      <div className="relative z-[2] bg-black/40 backdrop-blur-[1px]">
        <Features />
        <TrustMarquee />
        <Stats />
        <HowItWorks />
        <Testimonials />
        <Pricing />
        <FAQ />
        <CTA />
        <Footer />
      </div>

      {/* Back to top */}
      <AnimatePresence>
        {backTop && (
          <motion.button
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.8 }}
            transition={{ duration: 0.2 }}
            onClick={scrollToTop}
            className="back-to-top !opacity-100 !pointer-events-auto"
            aria-label="Back to top"
          >
            <ChevronUp className="w-5 h-5" />
          </motion.button>
        )}
      </AnimatePresence>
    </main>
      } />
    </Routes>
  );
}
