import { useState, useRef } from "react";
import { motion } from "motion/react";
import {
  MapPin,
  WifiOff,
  Calendar,
  Shield,
  BarChart3,
  Trophy,
} from "lucide-react";

const features = [
  {
    icon: MapPin,
    title: "Complete Loan Records",
    desc: "Keep a full record of every loan you've given: borrower details, amount, interest rate, and term. Everything searchable in one place.",
  },
  {
    icon: WifiOff,
    title: "Works Offline, Syncs Later",
    desc: "Record loans and repayments even without internet. Everything syncs safely when you're back online.",
  },
  {
    icon: Calendar,
    title: "Interest & Repayment Tracker",
    desc: "Automatically calculate interest accrued and track repayments. Know exactly what's owed at any moment.",
  },
  {
    icon: Shield,
    title: "Your Data, Private & Secure",
    desc: "Your ledger is yours alone. Encrypted storage, PIN/biometric lock, and no one else can access your records.",
  },
  {
    icon: BarChart3,
    title: "Simple Portfolio Insights",
    desc: "See your total lent amount, outstanding balance, interest earned, and repayment rate — all updated in real time.",
  },
  {
    icon: Trophy,
    title: "Smart Reminders",
    desc: "Set optional SMS reminders for borrowers. They get a gentle nudge; you get paid on time.",
  },
];

/* per-feature palette */
const accents = [
  { bar: "bg-indigo-500/50", barFull: "bg-indigo-500", iconBg: "bg-indigo-500/10", iconBorder: "border-indigo-500/20", iconColor: "text-indigo-300", glow: "99,102,241" },
  { bar: "bg-cyan-500/50",   barFull: "bg-cyan-500",   iconBg: "bg-cyan-500/10",    iconBorder: "border-cyan-500/20",    iconColor: "text-cyan-300",    glow: "6,182,212" },
  { bar: "bg-emerald-500/50",barFull: "bg-emerald-500",iconBg: "bg-emerald-500/10", iconBorder: "border-emerald-500/20", iconColor: "text-emerald-300", glow: "16,185,129" },
  { bar: "bg-amber-500/50",  barFull: "bg-amber-500",  iconBg: "bg-amber-500/10",   iconBorder: "border-amber-500/20",   iconColor: "text-amber-300",   glow: "245,158,11" },
  { bar: "bg-rose-500/50",   barFull: "bg-rose-500",   iconBg: "bg-rose-500/10",    iconBorder: "border-rose-500/20",    iconColor: "text-rose-300",    glow: "244,63,94" },
  { bar: "bg-purple-500/50", barFull: "bg-purple-500", iconBg: "bg-purple-500/10",  iconBorder: "border-purple-500/20",  iconColor: "text-purple-300",  glow: "168,85,247" },
];

/* Desktop stagger */
const container = {
  hidden: {},
  show: { transition: { staggerChildren: 0.08 } },
};
const item = {
  hidden: { opacity: 0, y: 30 },
  show: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.6, ease: [0.16, 1, 0.3, 1] },
  },
};

/* Desktop 3D tilt */
function TiltCard({ children }) {
  const ref = useRef(null);
  const handleMouse = (e) => {
    const el = ref.current;
    if (!el) return;
    var r = el.getBoundingClientRect();
    var x = e.clientX - r.left;
    var y = e.clientY - r.top;
    el.style.transform =
      "perspective(800px) rotateX(" +
      ((y / r.height - 0.5) * -6) +
      "deg) rotateY(" +
      ((x / r.width - 0.5) * 6) +
      "deg) translateY(-8px) scale(1.02)";
  };
  const handleLeave = () => {
    if (ref.current) ref.current.style.transform = "";
  };
  return (
    <div ref={ref} onMouseMove={handleMouse} onMouseLeave={handleLeave} className="h-full">
      {children}
    </div>
  );
}

/* Mobile flip card */
function FlipCard({ feature, accent, isFlipped, onFlip, index }) {
  var Icon = feature.icon;

  return (
    <motion.div
      layout
      className="relative cursor-pointer"
      style={{ perspective: "1000px" }}
    >
      <motion.div
        className="relative w-full"
        style={{ transformStyle: "preserve-3d" }}
        animate={{ rotateY: isFlipped ? 180 : 0 }}
        transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
      >
        {/* ── FRONT FACE ── */}
        <div
          onClick={!isFlipped ? onFlip : undefined}
          className="relative rounded-2xl border border-white/[0.06] overflow-hidden bg-white/[0.01] flex flex-col items-center justify-center p-4 min-h-[136px]"
          style={{ backfaceVisibility: "hidden" }}
        >
          {/* accent top bar */}
          <div className={"absolute top-0 left-0 right-0 h-[2px] " + accent.barFull} />

          {/* floating icon */}
          <motion.div
            animate={{ y: [0, -4, 0] }}
            transition={{ duration: 3, repeat: Infinity, ease: "easeInOut", delay: index * 0.3 }}
            className={"w-9 h-9 rounded-xl border flex items-center justify-center mb-2 " +
              accent.iconBg + " " + accent.iconBorder}
          >
            <Icon className={"w-[18px] h-[18px] " + accent.iconColor} />
          </motion.div>

          <span className="text-white text-[11px] font-medium text-center leading-tight max-w-[90%]">
            {feature.title}
          </span>

          {/* tap hint dot */}
          {!isFlipped && (
            <motion.div
              className="absolute bottom-2 right-2 w-1.5 h-1.5 rounded-full"
              style={{ backgroundColor: "rgba(" + accent.glow + ",0.5)" }}
              animate={{ scale: [1, 1.6, 1], opacity: [0.5, 0, 0.5] }}
              transition={{ duration: 2.5, repeat: Infinity, ease: "easeInOut" }}
            />
          )}
        </div>

        {/* ── BACK FACE ── */}
        <div
          className="absolute inset-0 rounded-2xl border overflow-hidden bg-white/[0.01] flex flex-col"
          style={{
            backfaceVisibility: "hidden",
            transform: "rotateY(180deg)",
            borderColor: "rgba(" + accent.glow + ",0.2)",
          }}
        >
          <div className={"absolute top-0 left-0 right-0 h-[2px] " + accent.barFull} />

          {isFlipped && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.15, duration: 0.3 }}
              className="flex flex-col flex-1 p-4"
            >
              <p className="text-white/50 text-[11px] leading-relaxed flex-1">
                {feature.desc}
              </p>
              <button
                onClick={function (e) { e.stopPropagation(); onFlip(); }}
                className="mt-2 self-start text-[10px] font-medium tracking-wide transition-colors"
                style={{ color: "rgba(" + accent.glow + ",0.6)" }}
              >
                &larr; Back
              </button>
            </motion.div>
          )}
        </div>
      </motion.div>
    </motion.div>
  );
}

export default function Features() {
  var [flippedIndex, setFlippedIndex] = useState(null);

  var handleFlip = function (i) {
    setFlippedIndex(flippedIndex === i ? null : i);
  };

  return (
    <section className="relative py-20 md:py-36 px-6 section-mesh overflow-hidden" id="features">
      <div className="max-w-5xl mx-auto">
        {/* heading */}
        <div className="text-center mb-12 md:mb-20">
          <motion.span
            initial={{ opacity: 0, y: 8 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.05 }}
            className="inline-block text-indigo-400/80 text-[10px] md:text-[11px] font-medium tracking-[0.25em] uppercase mb-5"
          >
            Platform Capabilities
          </motion.span>
          <motion.h2
            initial={{ opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
            style={{ fontFamily: "'Instrument Serif', serif" }}
            className="text-[28px] md:text-[44px] font-medium tracking-[-0.01em] leading-[1.15]"
          >
            Everything a Money-Lender Needs,{" "}
            <span className="gradient-brand">All in One Place</span>
          </motion.h2>
          <motion.p
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            transition={{ delay: 0.15, duration: 0.5 }}
            className="text-white/60 text-sm max-w-lg mx-auto mt-4 leading-relaxed"
          >
            Purpose-built for individual money-lenders -- track loans, interest, and repayments without the paperwork.
          </motion.p>
        </div>

        {/* ═══════════════════════════════════ */}
        {/* MOBILE -- 2x3 Interactive Flip Grid */}
        {/* ═══════════════════════════════════ */}
        <div className="md:hidden">
          <div className="grid grid-cols-2 gap-3">
            {features.map(function (f, i) {
              return (
                <FlipCard
                  key={i}
                  feature={f}
                  accent={accents[i]}
                  isFlipped={flippedIndex === i}
                  onFlip={function () { handleFlip(i); }}
                  index={i}
                />
              );
            })}
          </div>

          {/* interaction hint */}
          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.8, duration: 0.5 }}
            className="text-center text-[10px] text-white/[0.12] font-medium tracking-wider uppercase mt-4"
          >
            Tap any card to flip
          </motion.p>
        </div>

        {/* ═══════════════════════════════════ */}
        {/* DESKTOP -- Enhanced 3-Column Grid  */}
        {/* ═══════════════════════════════════ */}
        <motion.div
          variants={container}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true, margin: "-40px" }}
          className="hidden md:grid md:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-5"
        >
          {features.map(function (f, i) {
            var c = accents[i];
            return (
              <motion.div key={i} variants={item}>
                <TiltCard>
                  <div className="glow-card rounded-2xl p-6 md:p-8 h-full flex flex-col group cursor-default relative overflow-hidden">
                    {/* accent top border -- reveals on hover */}
                    <motion.div
                      className={"absolute top-0 left-0 right-0 h-[2px] rounded-t-2xl origin-left opacity-0 group-hover:opacity-100 transition-opacity duration-500 " + c.barFull}
                    />

                    {/* icon */}
                    <div
                      className={
                        "w-10 h-10 md:w-12 md:h-12 rounded-2xl border flex items-center justify-center mb-4 md:mb-5 transition-all duration-500 " +
                        c.iconBg + " " + c.iconBorder +
                        " group-hover:bg-white/[0.03] group-hover:border-white/15"
                      }
                    >
                      <f.icon
                        className={
                          "w-[18px] h-[18px] md:w-5 md:h-5 transition-all duration-500 " +
                          c.iconColor + " group-hover:text-white"
                        }
                      />
                    </div>

                    {/* number badge */}
                    <span className="absolute top-5 right-6 text-[40px] font-serif font-bold text-white/[0.02] select-none leading-none">
                      0{i + 1}
                    </span>

                    {/* content */}
                    <h3 className="text-white font-semibold text-[15px] mb-2 relative z-[1]">{f.title}</h3>
                    <p className="text-white/60 text-[13px] leading-relaxed flex-1 relative z-[1]">{f.desc}</p>

                    {/* learn more */}
                    <div className="hidden md:flex items-center gap-1 mt-4 text-white/0 group-hover:text-white/30 transition-all duration-300 text-[12px] font-medium relative z-[1]">
                      Learn more
                      <span className="block w-3 h-[1px] bg-white/30" />
                    </div>
                  </div>
                </TiltCard>
              </motion.div>
            );
          })}
        </motion.div>
      </div>
    </section>
  );
}
