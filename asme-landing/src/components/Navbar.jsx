import { useState, useEffect } from "react";
import { motion } from "motion/react";
import { Building2, Menu, X } from "lucide-react";

const links = [
  { href: "#features", label: "Features" },
  { href: "#how-it-works", label: "How It Works" },
  { href: "#pricing", label: "Pricing" },
  { href: "#faq", label: "FAQ" },
];

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const scrollTo = (id) => {
    if (mobileOpen) setMobileOpen(false);
    const el = document.getElementById(id);
    if (!el) return;
    const offset = 80;
    const top = el.getBoundingClientRect().top + window.scrollY - offset;
    window.scrollTo({ top, behavior: "smooth" });
  };

  return (
    <motion.nav
      initial={{ y: -20, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      className="fixed top-0 left-0 right-0 z-50 px-4 md:px-6 py-4"
    >
      <div className={"liquid-glass rounded-full px-5 md:px-6 py-2.5 md:py-3 flex items-center justify-between max-w-5xl mx-auto transition-all duration-500 " + (scrolled ? "shadow-lg shadow-indigo-500/5" : "")}>
        {/* Logo */}
        <a href="#" className="flex items-center gap-2 group">
          <div className="w-8 h-8 rounded-lg bg-indigo-500/15 border border-indigo-500/25 flex items-center justify-center group-hover:border-indigo-400/40 transition-all duration-300">
            <Building2 className="w-4 h-4 text-indigo-300" />
          </div>
          <span className="text-white font-semibold text-lg tracking-[-0.02em]">
            Micro<span className="text-indigo-400">Flow</span>
          </span>
        </a>

        {/* Desktop nav links */}
        <div className="hidden md:flex items-center gap-1">
          {links.map((l) => (
            <button key={l.href} onClick={() => scrollTo(l.href.slice(1))}
              className="px-3.5 py-1.5 text-white/60 hover:text-white text-sm font-medium rounded-full hover:bg-white/[0.04] transition-all duration-300 cursor-pointer"
            >
              {l.label}
            </button>
          ))}
        </div>

        {/* Desktop right */}
        <div className="hidden md:flex items-center gap-3">
          <button className="text-white/60 hover:text-white/90 transition-colors text-sm font-medium cursor-pointer px-3 py-1.5">
            Sign Up
          </button>
          <button className="bg-white/[0.04] backdrop-blur-sm rounded-full px-5 py-1.5 text-sm font-medium text-white/85 hover:text-white border border-white/[0.06] hover:border-white/[0.12] transition-all duration-300 cursor-pointer">
            Login
          </button>
        </div>

        {/* Mobile menu button */}
        <button className="md:hidden text-white/70 hover:text-white transition-colors cursor-pointer p-1" onClick={() => setMobileOpen(!mobileOpen)} aria-label="Menu">
          {mobileOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
        </button>
      </div>

      {/* Mobile menu */}
      {mobileOpen && (
        <motion.div
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="md:hidden mt-2 liquid-glass rounded-2xl p-4 max-w-5xl mx-auto"
        >
          <div className="flex flex-col gap-1">
            {links.map((l) => (
              <button key={l.href} onClick={() => scrollTo(l.href.slice(1))}
                className="w-full text-left px-4 py-2.5 text-white/70 hover:text-white text-sm rounded-xl hover:bg-white/[0.03] transition-all duration-300 cursor-pointer"
              >
                {l.label}
              </button>
            ))}
            <div className="h-px bg-white/[0.04] my-2" />
            <a href="#" className="px-4 py-2.5 text-white/70 hover:text-white text-sm rounded-xl hover:bg-white/[0.03] transition-all duration-300">Sign Up</a>
            <a href="#" className="px-4 py-2.5 text-white text-sm rounded-xl bg-indigo-500/15 border border-indigo-500/25 text-center mt-1">Login</a>
          </div>
        </motion.div>
      )}
    </motion.nav>
  );
}
