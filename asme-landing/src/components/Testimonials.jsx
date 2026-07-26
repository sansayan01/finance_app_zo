import { useState, useEffect, useCallback, useRef } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Star, Quote, ChevronLeft, ChevronRight } from "lucide-react";

const testimonials = [
  {
    quote:
      "I used to track 40+ borrowers in a dusty notebook — interest calculations were a nightmare. MicroFlow Pro replaced all of it. I can see who owes what, how much interest has accrued, and when payments are due, all in one place.",
    author: "Ramesh Kumar",
    role: "Local Lender, Delhi",
    initials: "RP",
  },
  {
    quote:
      "Before this app, I was juggling WhatsApp messages, paper receipts, and mental math. Now every loan, interest rate, and repayment is organized automatically. My borrowers even trust me more because I can show them exact balances instantly.",
    author: "Sunita Devi",
    role: "Small-Scale Lender, Mumbai",
    initials: "SK",
  },
  {
    quote:
      "I lend to 25+ people in my community \u2014 friends, neighbours, small shop owners. Managing interest and repayments used to take hours every weekend. Now it takes minutes. The offline mode is a lifesaver since my area has spotty connectivity.",
    author: "Amit Sharma",
    role: "Part-Time Lender, Bangalore",
    initials: "AM",
  },
];

/* ── Slide variants (direction-aware) ── */
const slideVariants = {
  enter: (dir) => ({ x: dir > 0 ? 280 : -280, opacity: 0, scale: 0.96 }),
  center: {
    x: 0,
    opacity: 1,
    scale: 1,
    transition: { duration: 0.4, ease: [0.16, 1, 0.3, 1] },
  },
  exit: (dir) => ({
    x: dir > 0 ? -280 : 280,
    opacity: 0,
    scale: 0.96,
    transition: { duration: 0.3, ease: [0.16, 1, 0.3, 1] },
  }),
};

/* ── Star stagger ── */
const starContainerVariants = {
  hidden: {},
  visible: { transition: { staggerChildren: 0.08, delayChildren: 0.15 } },
};
const starItemVariants = {
  hidden: { opacity: 0, scale: 0, rotate: -45 },
  visible: {
    opacity: 1,
    scale: 1,
    rotate: 0,
    transition: { type: "spring", stiffness: 280, damping: 14 },
  },
};

export default function Testimonials() {
  const [[current, direction], setPage] = useState([0, 1]);
  const [isPaused, setIsPaused] = useState(false);
  const autoTimerRef = useRef(null);

  /* ── Auto-play ── */
  const advance = useCallback(() => {
    setPage(([prev]) => [(prev + 1 + testimonials.length) % testimonials.length, 1]);
  }, []);

  useEffect(() => {
    if (isPaused) {
      if (autoTimerRef.current) clearInterval(autoTimerRef.current);
      return;
    }
    autoTimerRef.current = setInterval(advance, 5000);
    return () => {
      if (autoTimerRef.current) clearInterval(autoTimerRef.current);
    };
  }, [isPaused, advance]);

  /* ── Navigation ── */
  const paginate = (newDir) => {
    setIsPaused(true);
    const total = testimonials.length;
    setPage(([prev]) => [(prev + newDir + total) % total, newDir]);
    setTimeout(() => setIsPaused(false), 3000);
  };

  const goTo = (index) => {
    if (index === current) return;
    setIsPaused(true);
    setPage([index, index > current ? 1 : -1]);
    setTimeout(() => setIsPaused(false), 3000);
  };

  /* ── Drag handler ── */
  const handleDragEnd = (_, info) => {
    const threshold = 50;
    if (info.offset.x < -threshold) paginate(1);
    else if (info.offset.x > threshold) paginate(-1);
  };

  const t = testimonials[current];

  return (
    <section
      className="relative py-20 md:py-36 px-6 overflow-hidden border-t border-white/[0.03]"
      id="testimonials"
    >
      {/* Background glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[400px] bg-indigo-500/3 rounded-full blur-[120px] pointer-events-none" />

      <div className="max-w-6xl mx-auto relative z-[1]">
        {/* ── Heading ── */}
        <div className="text-center mb-12 md:mb-20">
          <motion.span
            initial={{ opacity: 0, y: 8 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.05 }}
            className="inline-block text-indigo-400/80 text-[10px] font-medium tracking-[0.25em] uppercase mb-5"
          >
            Trusted by Lenders
          </motion.span>
          <motion.h2
            initial={{ opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
            style={{ fontFamily: "'Instrument Serif', serif" }}
            className="text-[28px] md:text-[44px] font-medium tracking-[-0.01em] leading-[1.15]"
          >
            Trusted by <span className="gradient-brand">Money-Lenders</span>
          </motion.h2>
        </div>

        {/* ════════════════════════════════════ */}
        {/* MOBILE — Swipeable Card Carousel     */}
        {/* ════════════════════════════════════ */}
        <div className="md:hidden">
          <div
            onMouseEnter={() => setIsPaused(true)}
            onMouseLeave={() => setTimeout(() => setIsPaused(false), 2000)}
          >
            {/* Card stage */}
            <div className="relative px-7">
              {/* Left nav arrow */}
              <button
                onClick={() => paginate(-1)}
                className="absolute left-0 top-1/2 -translate-y-1/2 z-10 w-8 h-8 rounded-full bg-white/[0.04] border border-white/[0.06] flex items-center justify-center text-white/40 hover:text-white hover:bg-white/[0.08] hover:border-white/[0.12] transition-all duration-300 backdrop-blur-sm"
                aria-label="Previous testimonial"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>

              {/* Card with AnimatePresence */}
              <AnimatePresence mode="wait" custom={direction}>
                <motion.div
                  key={current}
                  custom={direction}
                  variants={slideVariants}
                  initial="enter"
                  animate="center"
                  exit="exit"
                  drag="x"
                  dragConstraints={{ left: 0, right: 0 }}
                  dragElastic={0.12}
                  onDragStart={() => setIsPaused(true)}
                  onDragEnd={handleDragEnd}
                  className="relative rounded-2xl p-6 bg-white/[0.01] border border-white/[0.06] select-none cursor-grab active:cursor-grabbing overflow-hidden"
                >
                  {/* Animated gradient top border */}
                  <motion.div
                    className="absolute top-0 left-0 right-0 h-[2px] rounded-t-2xl origin-left"
                    style={{
                      background:
                        "linear-gradient(90deg, #8b5cf6, #a78bfa, #67e8f9, #8b5cf6)",
                      backgroundSize: "300% 100%",
                    }}
                    animate={{ backgroundPosition: ["0% 0%", "100% 0%", "0% 0%"] }}
                    transition={{ duration: 6, repeat: Infinity, ease: "linear" }}
                  />

                  {/* Background quote watermark */}
                  <Quote className="absolute top-3 right-3 w-20 h-20 text-white/[0.025] pointer-events-none" />

                  {/* Animated stars */}
                  <motion.div
                    key={`stars-${current}`}
                    variants={starContainerVariants}
                    initial="hidden"
                    animate="visible"
                    className="flex gap-1 mb-4 relative z-[1]"
                  >
                    {[...Array(5)].map((_, j) => (
                      <motion.div key={j} variants={starItemVariants}>
                        <Star className="w-4 h-4 text-amber-400/80 fill-amber-400/80" />
                      </motion.div>
                    ))}
                  </motion.div>

                  {/* Quote text */}
                  <blockquote className="text-white/70 text-[13px] leading-relaxed mb-6 relative z-[1]">
                    &ldquo;{t.quote}&rdquo;
                  </blockquote>

                  {/* Author row */}
                  <div className="flex items-center gap-3 pt-4 border-t border-white/[0.04] relative z-[1]">
                    <div className="relative shrink-0">
                      <div className="w-10 h-10 rounded-full bg-gradient-to-br from-indigo-500 to-indigo-400 flex items-center justify-center text-white text-[12px] font-semibold shadow-lg shadow-indigo-500/20">
                        {t.initials}
                      </div>
                      {/* Breathing pulse ring */}
                      <motion.span
                        className="absolute inset-0 rounded-full border border-indigo-400/25"
                        animate={{
                          scale: [1, 1.35, 1],
                          opacity: [0.5, 0, 0.5],
                        }}
                        transition={{
                          duration: 2.8,
                          repeat: Infinity,
                          ease: "easeInOut",
                        }}
                      />
                    </div>
                    <div className="min-w-0">
                      <div className="text-white text-[13px] font-medium truncate">
                        {t.author}
                      </div>
                      <div className="text-white/30 text-[11px] mt-0.5 truncate">
                        {t.role}
                      </div>
                    </div>
                  </div>

                  {/* Drag hint — subtle fade */}
                  <motion.div
                    className="absolute bottom-3 right-4 text-[10px] text-white/15 font-medium tracking-wider uppercase"
                    initial={{ opacity: 0.6 }}
                    animate={{ opacity: [0.6, 0.15, 0.6] }}
                    transition={{ duration: 3, repeat: Infinity, ease: "easeInOut" }}
                  >
                    Swipe
                  </motion.div>
                </motion.div>
              </AnimatePresence>

              {/* Right nav arrow */}
              <button
                onClick={() => paginate(1)}
                className="absolute right-0 top-1/2 -translate-y-1/2 z-10 w-8 h-8 rounded-full bg-white/[0.04] border border-white/[0.06] flex items-center justify-center text-white/40 hover:text-white hover:bg-white/[0.08] hover:border-white/[0.12] transition-all duration-300 backdrop-blur-sm"
                aria-label="Next testimonial"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>

            {/* Progress dots */}
            <div className="flex justify-center items-center gap-2 mt-6">
              {testimonials.map((_, i) => (
                <button
                  key={i}
                  onClick={() => goTo(i)}
                  className="relative h-2 rounded-full transition-all duration-500 ease-out"
                  aria-label={`Go to testimonial ${i + 1}`}
                  style={{
                    width: i === current ? 28 : 6,
                    backgroundColor:
                      i === current
                        ? "rgba(139, 92, 246, 0.9)"
                        : "rgba(255, 255, 255, 0.1)",
                  }}
                >
                  {i === current && (
                    <motion.span
                      layoutId="dotActive"
                      className="absolute inset-0 rounded-full bg-indigo-500"
                      transition={{ type: "spring", stiffness: 300, damping: 25 }}
                    />
                  )}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* ════════════════════════════════════ */}
        {/* DESKTOP — Enhanced 3-Column Grid     */}
        {/* ════════════════════════════════════ */}
        <div className="hidden md:grid md:grid-cols-3 gap-4 md:gap-5">
          {testimonials.map((t, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, y: 24 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{
                duration: 0.6,
                ease: [0.16, 1, 0.3, 1],
                delay: i * 0.1,
              }}
              className="glass-card rounded-2xl p-6 md:p-8 flex flex-col group cursor-default relative overflow-hidden"
            >
              {/* Gradient accent top border — appears on hover */}
              <motion.div
                className="absolute top-0 left-0 right-0 h-[2px] rounded-t-2xl origin-left"
                style={{
                  background:
                    "linear-gradient(90deg, #8b5cf6, #a78bfa, #67e8f9, #8b5cf6)",
                  backgroundSize: "300% 100%",
                  opacity: 0,
                }}
                whileHover={{ opacity: 1, backgroundPosition: ["0% 0%", "100% 0%"] }}
                transition={{ duration: 0.5, ease: "easeOut" }}
              />

              {/* Background quote watermark */}
              <Quote className="absolute top-4 right-4 w-14 h-14 text-white/[0.025] pointer-events-none" />

              {/* Stars */}
              <div className="flex gap-1 mb-4 md:mb-5 relative z-[1]">
                {[...Array(5)].map((_, j) => (
                  <Star
                    key={j}
                    className="w-3.5 h-3.5 text-amber-400/70 fill-amber-400/70"
                  />
                ))}
              </div>

              {/* Quote */}
              <blockquote className="text-white/70 text-[13px] leading-relaxed flex-1 mb-6 relative z-[1]">
                &ldquo;{t.quote}&rdquo;
              </blockquote>

              {/* Author */}
              <div className="flex items-center gap-3 pt-4 border-t border-white/[0.04] group-hover:border-indigo-500/10 transition-colors duration-300 relative z-[1]">
                <div className="relative shrink-0">
                  <div className="w-10 h-10 rounded-full bg-gradient-to-br from-indigo-500 to-indigo-400 flex items-center justify-center text-white text-[12px] font-semibold shadow-lg shadow-indigo-500/20">
                    {t.initials}
                  </div>
                </div>
                <div className="min-w-0">
                  <div className="text-white text-[13px] font-medium truncate">
                    {t.author}
                  </div>
                  <div className="text-white/30 text-[11px] mt-0.5 truncate">
                    {t.role}
                  </div>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
