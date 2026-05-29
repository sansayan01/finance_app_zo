import { useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Users, Building2, IndianRupee, Star } from "lucide-react";

const icons = [Users, Building2, IndianRupee, Star];

function Burst({ active, accent }) {
  if (!active) return null;
  return (
    <div className="absolute inset-0 flex items-center justify-center pointer-events-none z-[5]">
      {[...Array(10)].map((_, i) => {
        const angle = (i / 10) * 360;
        const dist = 28 + Math.random() * 18;
        return (
          <motion.div
            key={i}
            initial={{ x: 0, y: 0, opacity: 1, scale: 1 }}
            animate={{
              x: Math.cos((angle * Math.PI) / 180) * dist,
              y: Math.sin((angle * Math.PI) / 180) * dist,
              opacity: 0,
              scale: 0.3,
            }}
            transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
            className="absolute w-[5px] h-[5px] rounded-full"
            style={{ background: accent }}
          />
        );
      })}
    </div>
  );
}

function Counter({ end, suffix, label, icon: Icon, accent, delay }) {
  const [count, setCount] = useState(0);
  const [celebrated, setCelebrated] = useState(false);
  const [showDetail, setShowDetail] = useState(false);
  const ref = useRef(null);
  const counted = useRef(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const obs = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && !counted.current) {
          counted.current = true;
          const duration = 2200;
          const start = performance.now();
          const step = (now) => {
            const t = Math.min((now - start) / duration, 1);
            const eased = 1 - Math.pow(1 - t, 3);
            setCount(Math.round(eased * end));
            if (t < 1) requestAnimationFrame(step);
          };
          requestAnimationFrame(step);
          obs.unobserve(el);
        }
      },
      { threshold: 0.4 },
    );
    obs.observe(el);
    return () => obs.disconnect();
  }, [end]);

  const fmt = (n) => {
    if (end >= 1000) return n.toLocaleString("en-IN");
    return n.toFixed(1);
  };

  const handleTap = () => {
    setCelebrated(true);
    setShowDetail((p) => !p);
    setTimeout(() => setCelebrated(false), 700);
  };

  const detailTexts = {
    "Active Members Served": "Growing 15% MoM across 40+ districts",
    "MFI Partners": "Including top 10 MFIs in India",
    "Collections Managed": "99.2% on-time repayment rate",
    "Average User Rating": "Based on 2,400+ verified reviews",
  };

  return (
    <motion.div
      ref={ref}
      initial={{ opacity: 0, y: 24, scale: 0.92 }}
      whileInView={{ opacity: 1, y: 0, scale: 1 }}
      viewport={{ once: true }}
      transition={{ delay: delay * 0.1, duration: 0.55, ease: [0.16, 1, 0.3, 1] }}
      onClick={handleTap}
      className="group relative cursor-pointer select-none"
    >
      <motion.div
        whileTap={{ scale: 0.94 }}
        className="relative rounded-2xl border border-white/[0.04] bg-white/[0.01] px-5 py-6 md:px-6 md:py-7 overflow-hidden transition-all duration-500 hover:border-white/[0.08]"
      >
        <div
          className="absolute -inset-2 opacity-0 group-hover:opacity-100 transition-opacity duration-700 blur-2xl pointer-events-none"
          style={{ background: "radial-gradient(600px circle at 50% 50%, " + accent + "18, transparent 70%)" }}
        />
        <div
          className="absolute top-0 left-0 right-0 h-[2px] opacity-60"
          style={{ background: "linear-gradient(90deg, " + accent + ", transparent)" }}
        />
        <Burst active={celebrated} accent={accent} />
        <div className="relative z-[1]">
          <motion.div
            whileHover={{ rotate: [0, -8, 8, 0], scale: 1.1 }}
            transition={{ duration: 0.4 }}
            className="w-10 h-10 md:w-12 md:h-12 rounded-xl flex items-center justify-center mb-3 md:mb-4"
            style={{ background: accent + "15", border: "1px solid " + accent + "25" }}
          >
            <Icon className="w-5 h-5 md:w-6 md:h-6" style={{ color: accent }} />
          </motion.div>
          <motion.div
            animate={celebrated ? { scale: [1, 1.18, 1] } : {}}
            transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
            className="counter-value text-2xl md:text-[40px] font-semibold tracking-[-0.03em] bg-gradient-to-b from-white via-white/90 to-white/60 bg-clip-text text-transparent leading-none mb-1"
          >
            {fmt(count)}{suffix}
          </motion.div>
          <p className="text-white/50 text-[10px] md:text-[11px] uppercase tracking-[0.08em] font-medium">{label}</p>
          <AnimatePresence>
            {showDetail && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: "auto", opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
                className="overflow-hidden md:!hidden"
              >
                <div className="h-px bg-white/[0.06] my-3" />
                <p className="text-white/40 text-[12px] leading-relaxed">{detailTexts[label] || ""}</p>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </motion.div>
    </motion.div>
  );
}

const stats = [
  { end: 10000, suffix: "+", label: "Active Members Served", accent: "#a78bfa" },
  { end: 500, suffix: "+", label: "MFI Partners", accent: "#22d3ee" },
  { end: 50, suffix: "Cr+", label: "Collections Managed", accent: "#34d399" },
  { end: 49, suffix: "\u2605", label: "Average User Rating", accent: "#fbbf24" },
];

export default function Stats() {
  return (
    <section className="relative py-16 md:py-32 px-6 overflow-hidden">
      <div className="absolute bottom-0 inset-x-0 h-px bg-gradient-to-r from-transparent via-white/[0.04] to-transparent" />
      <div className="absolute inset-0 bg-gradient-to-b from-indigo-500/[0.02] via-transparent to-transparent pointer-events-none" />
      <div className="max-w-5xl mx-auto relative z-[1]">
        <div className="text-center mb-10 md:mb-14">
          <motion.span
            initial={{ opacity: 0, y: 8 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="inline-block text-indigo-400/80 text-[10px] font-medium tracking-[0.25em] uppercase mb-3"
          >
            Our Impact
          </motion.span>
          <motion.h2
            initial={{ opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
            style={{ fontFamily: "\u0027Instrument Serif\u0027, serif" }}
            className="text-[28px] md:text-[40px] font-medium tracking-[-0.01em]"
          >
            Trusted at <span className="gradient-brand">Scale</span>
          </motion.h2>
          <motion.p
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            transition={{ delay: 0.2 }}
            className="text-white/40 text-xs mt-3 max-w-xs mx-auto md:hidden"
          >
            Tap any card to celebrate the impact
          </motion.p>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 md:gap-8">
          {stats.map((s, i) => (
            <Counter key={i} end={s.end} suffix={s.suffix} label={s.label} icon={icons[i]} accent={s.accent} delay={i} />
          ))}
        </div>
      </div>
    </section>
  );
}
