import { Fragment, useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Building2, Users, MapPin, ArrowRight, Check } from "lucide-react";

const steps = [
  {
    icon: Building2,
    title: "Create Your Organization",
    desc: "Sign up in under 2 minutes. Configure branches, assign staff roles, and set up loan products with flexible interest models.",
  },
  {
    icon: Users,
    title: "Add Members & Disburse",
    desc: "Register members, create savings accounts, and disburse loans with automated EMI schedules. All data syncs to the cloud instantly.",
  },
  {
    icon: MapPin,
    title: "Go to the Field",
    desc: "Staff collect payments with GPS verification. Offline mode queues transactions. Data syncs automatically when connectivity returns.",
  },
];

/* ── Per-step accent styles ── */
const stepStyles = [
  {
    accent: "from-violet-500 to-violet-400",
    border: "border-violet-500/20",
    iconBg: "bg-violet-500/10",
    iconBorder: "border-violet-500/25",
    iconColor: "text-violet-300",
    textAccent: "text-violet-400",
    cardBg: "from-violet-500/[0.06]",
    code: "01",
  },
  {
    accent: "from-cyan-500 to-cyan-400",
    border: "border-cyan-500/20",
    iconBg: "bg-cyan-500/10",
    iconBorder: "border-cyan-500/25",
    iconColor: "text-cyan-300",
    textAccent: "text-cyan-400",
    cardBg: "from-cyan-500/[0.06]",
    code: "02",
  },
  {
    accent: "from-amber-500 to-amber-400",
    border: "border-amber-500/20",
    iconBg: "bg-amber-500/10",
    iconBorder: "border-amber-500/25",
    iconColor: "text-amber-300",
    textAccent: "text-amber-400",
    cardBg: "from-amber-500/[0.06]",
    code: "03",
  },
];

/* ── Card slide variants (direction-aware) ── */
const slideVariants = {
  enter: (dir) => ({ x: dir > 0 ? 280 : -280, opacity: 0 }),
  center: {
    x: 0,
    opacity: 1,
    transition: { duration: 0.4, ease: [0.16, 1, 0.3, 1] },
  },
  exit: (dir) => ({
    x: dir > 0 ? -280 : 280,
    opacity: 0,
    transition: { duration: 0.3, ease: [0.16, 1, 0.3, 1] },
  }),
};

/* ── Text stagger ── */
const textContainerVariants = {
  hidden: {},
  visible: { transition: { staggerChildren: 0.1, delayChildren: 0.2 } },
};
const textItemVariants = {
  hidden: { opacity: 0, y: 12 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.35, ease: [0.16, 1, 0.3, 1] },
  },
};

export default function HowItWorks() {
  const [step, setStep] = useState(1);
  const [direction, setDirection] = useState(1);

  const next = () => {
    if (step >= 3) return;
    setDirection(1);
    setStep((s) => s + 1);
  };

  const prev = () => {
    if (step <= 1) return;
    setDirection(-1);
    setStep((s) => s - 1);
  };

  const goTo = (s) => {
    if (s === step) return;
    setDirection(s > step ? 1 : -1);
    setStep(s);
  };

  const s = steps[step - 1];
  const style = stepStyles[step - 1];

  const handleDragEnd = (_, info) => {
    const threshold = 40;
    if (info.offset.x < -threshold) next();
    if (info.offset.x > threshold) prev();
  };

  return (
    <section
      className="relative py-20 md:py-36 px-6 section-mesh overflow-hidden border-t border-white/[0.03]"
      id="how-it-works"
    >
      <div className="max-w-5xl mx-auto">
        {/* ── Heading ── */}
        <div className="text-center mb-12 md:mb-20">
          <motion.span
            initial={{ opacity: 0, y: 8 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.05 }}
            className="inline-block text-indigo-400/80 text-[10px] font-medium tracking-[0.25em] uppercase mb-5"
          >
            Three Simple Steps
          </motion.span>
          <motion.h2
            initial={{ opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
            style={{ fontFamily: "'Instrument Serif', serif" }}
            className="text-[28px] md:text-[44px] font-medium tracking-[-0.01em] leading-[1.15]"
          >
            Get Started in <span className="gradient-brand">Three Steps</span>
          </motion.h2>
        </div>

        {/* ════════════════════════════════════ */}
        {/* MOBILE — Interactive Walkthrough     */}
        {/* ════════════════════════════════════ */}
        <div className="md:hidden">
          {/* ── Progress Stepper ── */}
          <div className="flex items-center justify-center mb-8 px-4">
            {[1, 2, 3].map((sNum, i) => (
              <Fragment key={sNum}>
                {i > 0 && (
                  <motion.div
                    className="flex-1 h-[2px] rounded-full mx-1.5"
                    animate={{
                      background:
                        sNum <= step
                          ? "linear-gradient(90deg, #8b5cf6, #a78bfa)"
                          : "rgba(255,255,255,0.06)",
                    }}
                    transition={{ duration: 0.4 }}
                  />
                )}
                <button
                  onClick={() => goTo(sNum)}
                  className="relative w-9 h-9 rounded-full flex items-center justify-center text-[12px] font-semibold transition-all duration-300 shrink-0"
                  style={{
                    background:
                      sNum <= step
                        ? "linear-gradient(135deg, #8b5cf6, #7c3aed)"
                        : "transparent",
                    border:
                      sNum <= step
                        ? "none"
                        : "1.5px solid rgba(255,255,255,0.1)",
                    color:
                      sNum <= step
                        ? "#fff"
                        : "rgba(255,255,255,0.3)",
                    boxShadow:
                      sNum <= step
                        ? "0 4px 16px rgba(139,92,246,0.3)"
                        : "none",
                  }}
                  aria-label={`Go to step ${sNum}`}
                >
                  {sNum < step ? (
                    <Check className="w-3.5 h-3.5" />
                  ) : (
                    sNum
                  )}
                  {sNum === step && (
                    <motion.span
                      className="absolute inset-0 rounded-full border-2 border-indigo-400/30"
                      animate={{
                        scale: [1, 1.35, 1],
                        opacity: [0.5, 0, 0.5],
                      }}
                      transition={{
                        duration: 2,
                        repeat: Infinity,
                        ease: "easeInOut",
                      }}
                    />
                  )}
                </button>
              </Fragment>
            ))}
          </div>

          {/* ── Animated Card ── */}
          <AnimatePresence mode="wait" custom={direction}>
            <motion.div
              key={step}
              custom={direction}
              variants={slideVariants}
              initial="enter"
              animate="center"
              exit="exit"
              drag="x"
              dragConstraints={{ left: 0, right: 0 }}
              dragElastic={0.1}
              onDragEnd={handleDragEnd}
              className={
                "relative rounded-2xl border overflow-hidden bg-gradient-to-b " +
                style.cardBg +
                " to-transparent " +
                style.border +
                " select-none cursor-grab active:cursor-grabbing"
              }
            >
              {/* Gradient accent top bar */}
              <div
                className={
                  "absolute top-0 left-0 right-0 h-[2px] bg-gradient-to-r " +
                  style.accent +
                  " to-transparent"
                }
              />

              {/* Content */}
              <div className="px-5 py-7 md:px-6 md:py-8 text-center">
                {/* Icon with spring entrance */}
                <motion.div
                  initial={{ scale: 0, rotate: -90 }}
                  animate={{ scale: 1, rotate: 0 }}
                  transition={{
                    type: "spring",
                    stiffness: 200,
                    damping: 15,
                    delay: 0.05,
                  }}
                  className={
                    "inline-flex items-center justify-center w-16 h-16 rounded-2xl border backdrop-blur-sm mb-3 " +
                    style.iconBg +
                    " " +
                    style.iconBorder
                  }
                >
                  <s.icon className={"w-7 h-7 " + style.iconColor} />
                </motion.div>

                {/* Step code */}
                <div
                  className={
                    style.textAccent +
                    " text-[10px] font-mono tracking-[0.2em] mb-3"
                  }
                >
                  {style.code}
                </div>

                {/* Title & description stagger */}
                <motion.div
                  variants={textContainerVariants}
                  initial="hidden"
                  animate="visible"
                >
                  <motion.h3
                    variants={textItemVariants}
                    className="text-white font-semibold text-[17px] mb-3"
                  >
                    {s.title}
                  </motion.h3>
                  <motion.p
                    variants={textItemVariants}
                    className="text-white/60 text-[13px] leading-relaxed max-w-xs mx-auto"
                  >
                    {s.desc}
                  </motion.p>
                </motion.div>

                {/* ── Navigation ── */}
                <div className="flex items-center justify-between mt-8 pt-3">
                  {step > 1 ? (
                    <button
                      onClick={prev}
                      className="flex items-center gap-1.5 text-white/40 hover:text-white/70 text-[12px] font-medium transition-colors duration-200 py-2"
                    >
                      <ArrowRight className="w-3.5 h-3.5 rotate-180" />
                      Back
                    </button>
                  ) : (
                    <div />
                  )}

                  <button
                    onClick={next}
                    className={
                      "flex items-center gap-1.5 px-5 py-2.5 rounded-full bg-gradient-to-r " +
                      style.accent +
                      " text-white text-[12px] font-semibold shadow-lg transition-all duration-300 hover:shadow-xl hover:scale-[1.03] active:scale-[0.97]"
                    }
                  >
                    {step < 3 ? (
                      <>
                        Next
                        <ArrowRight className="w-3.5 h-3.5" />
                      </>
                    ) : (
                      <>
                        Get Started
                        <Check className="w-3.5 h-3.5" />
                      </>
                    )}
                  </button>
                </div>
              </div>
            </motion.div>
          </AnimatePresence>
        </div>

        {/* ════════════════════════════════════ */}
        {/* DESKTOP — Enhanced 3-Column Grid     */}
        {/* ════════════════════════════════════ */}
        <div className="hidden md:grid md:grid-cols-3 gap-8 md:gap-14 relative">
          {/* Animated connecting line */}
          <div className="absolute top-[54px] left-[16.66%] right-[16.66%] h-[1.5px] overflow-hidden">
            <div className="absolute inset-0 bg-gradient-to-r from-indigo-500/10 via-indigo-400/25 to-indigo-500/10" />
            <motion.div
              initial={{ x: "-100%" }}
              whileInView={{ x: "100%" }}
              viewport={{ once: true }}
              transition={{ duration: 1.8, ease: [0.16, 1, 0.3, 1] }}
              className="absolute inset-0 bg-gradient-to-r from-transparent via-indigo-400 to-transparent"
            />
          </div>

          {steps.map((s, i) => {
            const st = stepStyles[i];
            return (
              <motion.div
                key={i}
                initial={{ opacity: 0, y: 30 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-40px" }}
                transition={{
                  duration: 0.6,
                  ease: [0.16, 1, 0.3, 1],
                  delay: i * 0.15,
                }}
                className="text-center relative group"
              >
                {/* Step number circle */}
                <div className="relative z-10 inline-flex mb-6 md:mb-7">
                  <div
                    className={
                      "w-12 h-12 md:w-14 md:h-14 rounded-full bg-gradient-to-br to-transparent flex items-center justify-center backdrop-blur-sm group-hover:scale-110 group-hover:shadow-lg transition-all duration-500 " +
                      st.iconBg +
                      " " +
                      st.iconBorder
                    }
                  >
                    <span className="text-white font-semibold text-base md:text-lg">
                      {i + 1}
                    </span>
                  </div>
                  {/* Pulsing ring — desktop only */}
                  <div
                    className="hidden md:block absolute inset-0 rounded-full border border-indigo-500/10 animate-ping opacity-30"
                    style={{ animationDuration: "3s" }}
                  />
                </div>

                {/* Icon box */}
                <div
                  className={
                    "w-10 h-10 md:w-11 md:h-11 rounded-xl border flex items-center justify-center mx-auto mb-4 md:mb-5 transition-all duration-300 " +
                    st.iconBg +
                    " " +
                    st.iconBorder
                  }
                >
                  <s.icon className={"w-[18px] h-[18px] md:w-5 md:h-5 " + st.iconColor} />
                </div>

                <h3 className="text-white font-semibold text-[15px] mb-3">
                  {s.title}
                </h3>
                <p className="text-white/60 text-[13px] leading-relaxed max-w-xs md:max-w-[270px] mx-auto">
                  {s.desc}
                </p>
              </motion.div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
