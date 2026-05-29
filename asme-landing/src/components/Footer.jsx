import { useState, useEffect, useRef, useCallback } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Building2, Banknote, ArrowUpRight, ShieldCheck } from "lucide-react";

var sections = [
  { title: "Product", links: ["Features", "Staff Portal", "Admin Dashboard", "Offline Sync", "API Reference"] },
  { title: "Company", links: ["About Us", "Security", "Privacy", "Terms", "Careers"] },
  { title: "Support", links: ["Help Center", "API Docs", "System Status", "Contact"] },
];

var socials = [
  { name: "Twitter", path: "M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" },
  { name: "LinkedIn", path: "M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z" },
  { name: "GitHub", path: "M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" },
  { name: "YouTube", path: "M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z" },
];

/* ── Follow-blob background ── */
function FollowBlob() {
  var ref = useRef(null);
  var [pos, setPos] = useState({ x: 50, y: 50 });
  var [isInside, setIsInside] = useState(false);
  var raf = useRef(null);

  var handleMove = useCallback(function (e) {
    if (raf.current) cancelAnimationFrame(raf.current);
    raf.current = requestAnimationFrame(function () {
      var rect = ref.current?.getBoundingClientRect();
      if (!rect) return;
      var x = ((e.clientX - rect.left) / rect.width) * 100;
      var y = ((e.clientY - rect.top) / rect.height) * 100;
      setPos({ x: Math.min(100, Math.max(0, x)), y: Math.min(100, Math.max(0, y)) });
    });
  }, []);

  return (
    <div
      ref={ref}
      className="absolute inset-0 overflow-hidden pointer-events-none"
      onPointerMove={handleMove}
      onPointerEnter={function () { setIsInside(true); }}
      onPointerLeave={function () { setIsInside(false); }}
    >
      {/* primary blob — follows pointer */}
      <motion.div
        className="absolute w-72 h-72 md:w-96 md:h-96 rounded-full opacity-0 pointer-events-none"
        style={{ background: "radial-gradient(circle, rgba(99,102,241,0.12), transparent 70%)" }}
        animate={isInside ? { left: pos.x + "%", top: pos.y + "%", opacity: 1 } : { opacity: 0 }}
        transition={{ type: "spring", stiffness: 80, damping: 25, mass: 1.2 }}
        style={{ transform: "translate(-50%, -50%)" }}
      />
      {/* secondary blob — trails behind with different physics */}
      <motion.div
        className="absolute w-48 h-48 md:w-64 md:h-64 rounded-full opacity-0 pointer-events-none"
        style={{ background: "radial-gradient(circle, rgba(6,182,212,0.08), transparent 70%)" }}
        animate={isInside ? { left: pos.x + "%", top: pos.y + "%", opacity: 1 } : { opacity: 0 }}
        transition={{ type: "spring", stiffness: 40, damping: 30, mass: 2, delay: 0.08 }}
        style={{ transform: "translate(-50%, -50%)" }}
      />
    </div>
  );
}

/* ── Counter ── */
function AnimatedCounter({ end, prefix, suffix, label, divisor, decimals }) {
  return (
    <div className="text-center">
      <CountUp end={end} prefix={prefix} suffix={suffix} divisor={divisor} decimals={decimals} />
      <p className="text-[11px] text-white/40 mt-1.5 leading-tight">{label}</p>
    </div>
  );
}

function CountUp({ end, prefix, suffix, divisor, decimals }) {
  var ref = useRef(null);
  var [count, setCount] = useState(0);
  var hasAnimated = useRef(false);

  useEffect(function () {
    var el = ref.current;
    if (!el || hasAnimated.current) return;
    var observer = new IntersectionObserver(function (entries) {
      if (entries[0].isIntersecting) {
        hasAnimated.current = true;
        var startTime = Date.now();
        var duration = 2200;
        function tick() {
          var elapsed = Date.now() - startTime;
          var progress = Math.min(elapsed / duration, 1);
          var eased = 1 - Math.pow(1 - progress, 3);
          setCount(Math.round(eased * end));
          if (progress < 1) requestAnimationFrame(tick);
        }
        requestAnimationFrame(tick);
        observer.disconnect();
      }
    }, { threshold: 0.3 });
    observer.observe(el);
    return function () { observer.disconnect(); };
  }, [end]);

  var display = divisor ? (count / divisor).toFixed(decimals) : count.toLocaleString();
  return (
    <span ref={ref} className="text-2xl font-semibold tracking-[-0.02em] text-white">
      {prefix}{display}
      <span className="text-sm text-indigo-300 ml-0.5 font-medium">{suffix}</span>
    </span>
  );
}

/* ── Mobile accordion ── */
function AccordionSection({ title, links }) {
  var [open, setOpen] = useState(false);
  return (
    <motion.div layout className="border-b border-white/[0.04] last:border-b-0">
      <button onClick={function () { setOpen(!open); }}
        className="flex items-center justify-between w-full py-3.5 text-indigo-400/60 text-[10px] font-semibold uppercase tracking-[0.15em]"
      >
        {title}
        <div className="w-3 h-3 relative flex items-center justify-center">
          <motion.span animate={{ rotate: open ? 180 : 0 }}
            transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
            className="absolute w-3 h-[1.5px] bg-white/20 rounded-full"
          />
          <motion.span animate={{ rotate: open ? 180 : 90 }}
            transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
            className="absolute h-3 w-[1.5px] bg-white/20 rounded-full"
          />
        </div>
      </button>
      <AnimatePresence initial={false}>
        {open && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            transition={{ duration: 0.25, ease: [0.16, 1, 0.3, 1] }}
          >
            <ul className="space-y-2 pb-3.5">
              {links.map(function (l, i) {
                return (
                  <motion.li key={l} initial={{ opacity: 0, x: -8 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: i * 0.04, duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
                  >
                    <a href="#" className="text-white/35 hover:text-white/80 transition-all duration-200 text-[13px] inline-block py-1">{l}</a>
                  </motion.li>
                );
              })}
            </ul>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}

export default function Footer() {
  var stats = [
    { end: 24, prefix: "\u20b9", suffix: "M+", label: "collected daily", divisor: 1, decimals: 1, icon: Banknote },
    { end: 1847, prefix: "", suffix: "+", label: "transactions / day", divisor: 0, decimals: 0, icon: ArrowUpRight },
    { end: 982, prefix: "", suffix: "%", label: "platform uptime", divisor: 10, decimals: 1, icon: ShieldCheck },
  ];

  return (
    <footer className="relative px-6 pt-16 md:pt-24 pb-10 overflow-hidden">
      {/* ambient glow */}
      <div className="absolute inset-0 bg-gradient-to-b from-indigo-500/[0.015] via-transparent to-transparent pointer-events-none" />
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[600px] h-[250px] bg-indigo-500/[0.04] rounded-full blur-[120px] pointer-events-none" />

      {/* interactive follow-blob layer */}
      <FollowBlob />

      <div className="max-w-6xl mx-auto relative z-[1]">
        {/* brand */}
        <div className="text-center mb-10">
          <a href="#" className="inline-flex items-center gap-2.5 mb-3">
            <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-indigo-500/25 to-indigo-400/10 border border-indigo-500/30 flex items-center justify-center shadow-lg shadow-indigo-500/10">
              <Building2 className="w-4 h-4 text-indigo-300" />
            </div>
            <span className="text-white font-semibold text-lg tracking-[-0.02em]">
              Micro<span className="text-indigo-400">Flow</span>
            </span>
          </a>
          <p style={{ fontFamily: "'Instrument Serif', serif" }}
            className="text-white/30 text-sm leading-relaxed max-w-xs mx-auto italic"
          >
            The intelligent platform for micro-finance institutions.
          </p>
        </div>

        {/* stats counters */}
        <motion.div
          initial={{ opacity: 0, y: 12 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }}
          transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
          className="grid grid-cols-3 gap-3 mb-10"
        >
          {stats.map(function (s, i) {
            var Icon = s.icon;
            return (
              <div key={i} className="rounded-xl border border-white/[0.04] bg-white/[0.01] p-3.5 md:p-4">
                <div className="w-7 h-7 rounded-lg bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center mx-auto mb-2.5">
                  <Icon className="w-3.5 h-3.5 text-indigo-300" />
                </div>
                <AnimatedCounter end={s.end} prefix={s.prefix} suffix={s.suffix} label={s.label} divisor={s.divisor} decimals={s.decimals} />
              </div>
            );
          })}
        </motion.div>

        {/* divider */}
        <div className="w-full h-px bg-gradient-to-r from-transparent via-white/[0.04] to-transparent mb-3 md:mb-14" />

        {/* mobile accordion */}
        <div className="md:hidden mb-10">
          {sections.map(function (s) { return <AccordionSection key={s.title} title={s.title} links={s.links} />; })}
        </div>

        {/* desktop grid */}
        <motion.div initial={{ opacity: 0, y: 16 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }}
          transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
          className="hidden md:grid md:grid-cols-3 gap-12 mb-14"
        >
          {sections.map(function (s) {
            return (
              <div key={s.title}>
                <h4 className="text-indigo-400/60 text-[10px] font-semibold uppercase tracking-[0.15em] mb-5">{s.title}</h4>
                <ul className="space-y-3.5">
                  {s.links.map(function (l) {
                    return (
                      <li key={l}>
                        <motion.a whileHover={{ x: 3 }} href="#"
                          className="text-white/35 hover:text-white/80 transition-all duration-200 text-[13px] inline-block">{l}</motion.a>
                      </li>
                    );
                  })}
                </ul>
              </div>
            );
          })}
        </motion.div>

        {/* bottom bar */}
        <motion.div initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }}
          className="pt-6 md:pt-8 border-t border-white/[0.03] flex flex-col md:flex-row items-center justify-between gap-5"
        >
          <p className="text-white/20 text-[12px] order-2 md:order-1">&copy; 2024&ndash;2026 MicroFlow Pro. All rights reserved.</p>
          <div className="flex items-center gap-3 order-1 md:order-2">
            {socials.map(function (s) {
              return (
                <motion.a key={s.name}
                  whileHover={{ scale: 1.18, y: -3 }} whileTap={{ scale: 0.92 }}
                  transition={{ type: "spring", stiffness: 400, damping: 15 }}
                  href="#" aria-label={s.name}
                  className="w-8 h-8 md:w-9 md:h-9 rounded-lg bg-white/[0.03] border border-white/[0.06] flex items-center justify-center text-white/30 hover:text-indigo-300 hover:border-indigo-500/25 hover:bg-indigo-500/10 transition-colors duration-300"
                >
                  <svg className="w-3.5 h-3.5 md:w-4 md:h-4" fill="currentColor" viewBox="0 0 24 24">
                    <path d={s.path} />
                  </svg>
                </motion.a>
              );
            })}
          </div>
        </motion.div>
      </div>
    </footer>
  );
}
