import { useState, useEffect, useCallback, useRef } from "react";
import { motion, AnimatePresence } from "motion/react";
import { ArrowRight, Check, ChevronDown, User, Building2, Sparkles } from "lucide-react";
import AppDownloadButton from "./AppDownloadButton";

const WEB_FALLBACK = "https://microflow-442f8.web.app";

/* ── Persona content ── */
var CONTENT = {
  agent: {
    label: "Field Agent",
    icon: User,
    wordList: ["collect payments", "track members", "record visits", "earn rewards", "work offline"],
    subtitle: "Field-first tools for collection agents. GPS check-ins, offline sync, and daily targets\u2014all in one app.",
    cta: "Get Early Access",
    pairs: [
      { problem: "Drowning in paperwork?", solution: "Collect digitally in seconds", stat: "92% faster collections" },
      { problem: "Wasting hours traveling?", solution: "GPS-verified field visits", stat: "40% fewer trips" },
      { problem: "Losing paper receipts?", solution: "Auto-generated digital receipts", stat: "100% receipt accuracy" },
      { problem: "Working without internet?", solution: "Offline-first sync engine", stat: "Works reliably on 2G" },
    ],
  },
  org: {
    label: "Organization",
    icon: Building2,
    wordList: ["manage micro-finance", "analyze portfolios", "oversee branches", "track disbursements", "monitor repayments"],
    subtitle: "Enterprise oversight for MFI leaders. Real-time analytics, role-based controls, and multi-branch dashboards.",
    cta: "Start Free Trial",
    pairs: [
      { problem: "Scattered across spreadsheets?", solution: "Unified real-time dashboard", stat: "All metrics in one view" },
      { problem: "No visibility into branches?", solution: "Multi-branch oversight hub", stat: "Monitor 50+ branches live" },
      { problem: "Manual reporting delays?", solution: "Automated analytics engine", stat: "Reports in under 2 clicks" },
      { problem: "Risk of fraud or errors?", solution: "Role-based security & audit", stat: "Enterprise-grade data RLS" },
    ],
  },
};

var WORD_COLORS = [
  "99,102,241",
  "6,182,212",
  "16,185,129",
  "245,158,11",
  "244,63,94",
];

/* ── Desktop word variants (3D vertical) ── */
var wordVariants = {
  enter: function (dir) {
    return { y: dir > 0 ? 28 : -28, opacity: 0, filter: "blur(5px)", rotateX: dir > 0 ? -12 : 12 };
  },
  center: {
    y: 0,
    opacity: 1,
    filter: "blur(0px)",
    rotateX: 0,
    transition: { duration: 0.5, ease: [0.16, 1, 0.3, 1] },
  },
  exit: function (dir) {
    return {
      y: dir > 0 ? -28 : 28,
      opacity: 0,
      filter: "blur(5px)",
      rotateX: dir > 0 ? 12 : -12,
      transition: { duration: 0.4, ease: [0.16, 1, 0.3, 1] },
    };
  },
};

/* ── Mobile transform variants ── */
var problemExit = {
  y: -24,
  opacity: 0,
  filter: "blur(5px)",
  scale: 0.9,
  transition: { duration: 0.3, ease: [0.16, 1, 0.3, 1] },
};
var solutionEnter = {
  y: 0,
  opacity: 1,
  filter: "blur(0px)",
  scale: 1,
  transition: { duration: 0.45, delay: 0.1, ease: [0.16, 1, 0.3, 1] },
};
var solutionExit = {
  y: 24,
  opacity: 0,
  filter: "blur(5px)",
  scale: 0.9,
  transition: { duration: 0.3, ease: [0.16, 1, 0.3, 1] },
};
var problemEnter = {
  y: 0,
  opacity: 1,
  filter: "blur(0px)",
  scale: 1,
  transition: { duration: 0.45, delay: 0.1, ease: [0.16, 1, 0.3, 1] },
};

/* ── Persona transition variants ── */
var personaVariants = {
  enter: { y: 20, opacity: 0, filter: "blur(3px)" },
  center: { y: 0, opacity: 1, filter: "blur(0px)", transition: { duration: 0.45, ease: [0.16, 1, 0.3, 1] } },
  exit: { y: -20, opacity: 0, filter: "blur(3px)", transition: { duration: 0.3, ease: [0.16, 1, 0.3, 1] } },
};

export default function Hero() {
  var [persona, setPersona] = useState("org");
  var [wordIndex, setWordIndex] = useState(0);
  var [wordDir, setWordDir] = useState(1);
  var [wordPaused, setWordPaused] = useState(false);
  var autoRef = useRef(null);

  /* ── Mobile transform state ── */
  var [pairIndex, setPairIndex] = useState(0);
  var [revealed, setRevealed] = useState(false);
  var currentPair = CONTENT[persona].pairs[pairIndex];

  /* ── CTA state ── */
  var [step, setStep] = useState("button");
  var [placeholder, setPlaceholder] = useState("");
  var [typedIndex, setTypedIndex] = useState(0);
  var [showSuccess, setShowSuccess] = useState(false);
  var inputRef = useRef(null);
  var resetTimerRef = useRef(null);

  var current = CONTENT[persona];
  var words = current.wordList;
  var pairs = current.pairs;

  /* ── Reset on persona change ── */
  useEffect(function () {
    setWordIndex(0);
    setWordDir(1);
    setPairIndex(0);
    setRevealed(false);
  }, [persona]);

  /* ── Desktop word auto-play ── */
  useEffect(function () {
    if (wordPaused || words.length === 0) return;
    autoRef.current = setInterval(function () {
      setWordDir(1);
      setWordIndex(function (prev) { return (prev + 1 + words.length) % words.length; });
    }, 4000);
    return function () { if (autoRef.current) clearInterval(autoRef.current); };
  }, [wordIndex, wordPaused, words.length]);

  /* ── Mobile transform auto-advance ── */
  useEffect(function () {
    if (wordPaused) return;
    var t = setTimeout(function () {
      if (!revealed) {
        setRevealed(true);
      } else {
        setRevealed(false);
        setPairIndex(function (p) { return (p + 1) % pairs.length; });
      }
    }, revealed ? 4000 : 3000);
    return function () { clearTimeout(t); };
  }, [pairIndex, revealed, wordPaused, pairs.length]);

  var advanceWord = function (dir) {
    setWordPaused(true);
    setWordDir(dir);
    setWordIndex(function (prev) { return (prev + dir + words.length) % words.length; });
    setTimeout(function () { setWordPaused(false); }, 6000);
  };

  var goToWord = function (i) {
    if (i === wordIndex) return;
    setWordPaused(true);
    setWordDir(i > wordIndex ? 1 : -1);
    setWordIndex(i);
    setTimeout(function () { setWordPaused(false); }, 6000);
  };

  /* ── Mobile: tap to transform ── */
  var handleTransformTap = function () {
    setWordPaused(true);
    if (!revealed) {
      setRevealed(true);
    } else {
      setRevealed(false);
      setPairIndex(function (p) { return (p + 1) % pairs.length; });
    }
    setTimeout(function () { setWordPaused(false); }, 6000);
  };

  /* ── Mobile: go to specific pair ── */
  var goToPair = function (i) {
    if (i === pairIndex && revealed) return;
    setWordPaused(true);
    setPairIndex(i);
    setRevealed(false);
    setTimeout(function () { setWordPaused(false); }, 6000);
  };

  /* ── CTA typewriter ── */
  useEffect(function () {
    if (step === "button") return;
    var text = step === "submitted" ? "We\u2019ll Send Onboarding Instructions" : "Enter Your Work Email For Early Access";
    if (typedIndex < text.length) {
      var t = setTimeout(function () {
        setPlaceholder(text.slice(0, typedIndex + 1));
        setTypedIndex(function (i) { return i + 1; });
      }, 60);
      return function () { clearTimeout(t); };
    }
  }, [step, typedIndex]);

  useEffect(function () {
    if (step === "email") { setPlaceholder(""); setTypedIndex(0); setShowSuccess(false); }
  }, [step]);

  useEffect(function () {
    if (step === "email" && typedIndex >= "Enter Your Work Email For Early Access".length) {
      if (inputRef.current) inputRef.current.focus();
    }
  }, [step, typedIndex]);

  useEffect(function () {
    if (step === "submitted") {
      setShowSuccess(true);
      setPlaceholder("We\u2019ll Send Onboarding Instructions");
      if (resetTimerRef.current) clearTimeout(resetTimerRef.current);
      resetTimerRef.current = setTimeout(function () {
        setStep("button"); setPlaceholder(""); setTypedIndex(0); setShowSuccess(false);
      }, 4000);
      return function () { if (resetTimerRef.current) clearTimeout(resetTimerRef.current); };
    }
  }, [step]);

  var handleGetStarted = useCallback(function () { window.location.href = WEB_FALLBACK; }, []);
  var handleSubmit = useCallback(function (e) { e.preventDefault(); setStep("submitted"); }, []);

  var switchPersona = function (p) {
    if (p === persona) return;
    setWordPaused(true);
    setPersona(p);
    setTimeout(function () { setWordPaused(false); }, 6000);
  };

  /* ── Current pair accent color ── */
  var pairAccent = WORD_COLORS[pairIndex % WORD_COLORS.length];

  return (
    <section className="relative flex-1 flex flex-col items-center justify-center px-6 overflow-hidden">
      {/* background color-shift overlay */}
      <motion.div
        key={persona + "-pair-" + (revealed ? "sol" : "prob") + pairIndex}
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.8 }}
        className="fixed inset-0 pointer-events-none z-[1]"
        style={{
          background: "radial-gradient(ellipse 80% 50% at 50% 40%, rgba(" + pairAccent + ",0.08), transparent 70%)",
        }}
      />

      <div className="relative z-10 text-center max-w-5xl mx-auto flex flex-col items-center justify-center w-full gap-5 md:gap-7">
        {/* ── Tagline ── */}
        <motion.p
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="text-white/60 text-[10px] md:text-[11px] font-medium tracking-[0.25em] uppercase"
        >
          <span className="inline-block px-3 py-1 rounded-full border border-white/[0.06] bg-white/[0.02] backdrop-blur-sm">
            The All-in-One Platform for MFIs &amp; Savings Groups
          </span>
        </motion.p>

        {/* ════════════════════════════════════ */}
        {/* PERSONA TOGGLE */}
        {/* ════════════════════════════════════ */}
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.15 }}
          className="flex p-1 rounded-full bg-white/[0.03] border border-white/[0.06] backdrop-blur-sm"
        >
          {["agent", "org"].map(function (p) {
            var PersonaIcon = CONTENT[p].icon;
            var isActive = persona === p;
            return (
              <button
                key={p}
                onClick={function () { switchPersona(p); }}
                className={
                  "relative flex items-center gap-1.5 px-3.5 sm:px-4 py-2 rounded-full text-[11px] sm:text-[12px] font-medium transition-all duration-300 min-h-[36px] cursor-pointer " +
                  (isActive ? " text-white" : " text-white/40 hover:text-white/70")
                }
              >
                {isActive && (
                  <motion.span
                    layoutId="personaPill"
                    className="absolute inset-0 rounded-full bg-gradient-to-r from-indigo-500 to-indigo-400 shadow-lg shadow-indigo-500/20"
                    transition={{ type: "spring", stiffness: 380, damping: 30 }}
                  />
                )}
                <PersonaIcon className="w-3.5 h-3.5 relative z-[1]" />
                <span className="relative z-[1]">{CONTENT[p].label}</span>
              </button>
            );
          })}
        </motion.div>

        {/* ════════════════════════════════════ */}
        {/* MOBILE: TRANSFORMATION INTERACTION */}
        {/* ════════════════════════════════════ */}
        <div className="block md:hidden w-full">
          <AnimatePresence mode="wait">
            <motion.h1
              key={persona + "-transform"}
              variants={personaVariants}
              initial="enter"
              animate="center"
              exit="exit"
              style={{ fontFamily: "\u0027Instrument Serif\u0027, serif" }}
              className="text-[clamp(28px,6.5vw,44px)] font-medium tracking-[-0.02em] leading-[1.15]"
            >
              <span className="bg-gradient-to-b from-white via-white/95 to-white/70 bg-clip-text text-transparent">
                The intelligent way to
              </span>
              <br />
              <span
                onClick={handleTransformTap}
                onMouseEnter={function () { setWordPaused(true); }}
                onMouseLeave={function () { setTimeout(function () { setWordPaused(false); }, 2000); }}
                className="relative inline-block w-full cursor-pointer select-none min-h-[1.4em]"
              >
                <AnimatePresence mode="popLayout">
                  {!revealed ? (
                    <motion.span
                      key={"prob-" + pairIndex}
                      initial={{ y: 24, opacity: 0, filter: "blur(4px)", scale: 0.92 }}
                      animate={problemEnter}
                      exit={problemExit}
                      className="inline-block text-white/80 text-[clamp(24px,6vw,40px)] font-medium"
                      style={{ fontStyle: "italic" }}
                    >
                      {currentPair.problem}
                    </motion.span>
                  ) : (
                    <motion.span
                      key={"sol-" + pairIndex}
                      initial={{ y: 24, opacity: 0, filter: "blur(4px)", scale: 0.92 }}
                      animate={solutionEnter}
                      exit={solutionExit}
                      className="inline-block gradient-brand text-[clamp(26px,6.5vw,42px)] font-medium leading-[1.2]"
                    >
                      {currentPair.solution}
                    </motion.span>
                  )}
                </AnimatePresence>
              </span>
            </motion.h1>
          </AnimatePresence>

          {/* ── Mobile: Animated stat line ── */}
          <AnimatePresence mode="wait">
            {revealed && (
              <motion.div
                key={"stat-" + pairIndex}
                initial={{ opacity: 0, y: 12, scale: 0.9 }}
                animate={{ opacity: 1, y: 0, scale: 1, transition: { duration: 0.4, delay: 0.25, ease: [0.16, 1, 0.3, 1] } }}
                exit={{ opacity: 0, y: -8, scale: 0.9, transition: { duration: 0.2 } }}
                className="mt-2"
              >
                <span
                  className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-semibold tracking-wide"
                  style={{
                    background: "rgba(" + pairAccent + ",0.12)",
                    color: "rgb(" + pairAccent + ")",
                    border: "1px solid rgba(" + pairAccent + ",0.2)",
                  }}
                >
                  <Sparkles className="w-3 h-3" />
                  {currentPair.stat}
                </span>
              </motion.div>
            )}
          </AnimatePresence>

          {/* ── Mobile: Progress dots ── */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.5 }}
            className="flex items-center justify-center gap-2 mt-3"
          >
            {pairs.map(function (_, i) {
              var isActive = i === pairIndex;
              var isPast = i < pairIndex;
              var accent = "rgba(" + WORD_COLORS[i % WORD_COLORS.length] + ",1)";
              return (
                <button
                  key={i}
                  onClick={function () { goToPair(i); }}
                  className="relative flex items-center cursor-pointer"
                  aria-label={"Go to benefit " + (i + 1)}
                >
                  <span
                    className="block rounded-full transition-all duration-500 ease-out"
                    style={{
                      width: isActive ? 28 : 6,
                      height: isActive ? 6 : 6,
                      background: isActive
                        ? accent
                        : isPast
                          ? "rgba(255,255,255,0.3)"
                          : "rgba(255,255,255,0.08)",
                    }}
                  />
                  {isActive && (
                    <motion.span
                      layoutId="mobilePairDot"
                      className="absolute inset-0 rounded-full"
                      style={{ backgroundColor: accent }}
                      transition={{ type: "spring", stiffness: 300, damping: 25 }}
                    />
                  )}
                </button>
              );
            })}
            <motion.span
              initial={{ opacity: 0 }}
              animate={{ opacity: revealed ? 0 : [0.6, 0.2, 0.6] }}
              transition={{ duration: 2, repeat: Infinity }}
              className="text-white/25 text-[9px] font-medium tracking-[0.1em] uppercase ml-1"
            >
              {revealed ? "" : "tap"}
            </motion.span>
          </motion.div>
        </div>

        {/* ════════════════════════════════════ */}
        {/* DESKTOP: WORD CAROUSEL */}
        {/* ════════════════════════════════════ */}
        <div className="hidden md:block w-full">
          <AnimatePresence mode="wait">
            <motion.h1
              key={persona}
              variants={personaVariants}
              initial="enter"
              animate="center"
              exit="exit"
              style={{ fontFamily: "\u0027Instrument Serif\u0027, serif" }}
              className="text-[clamp(30px,7vw,72px)] font-medium tracking-[-0.02em] leading-[1.08] max-w-4xl"
            >
              <span className="bg-gradient-to-b from-white via-white/95 to-white/70 bg-clip-text text-transparent">
                The intelligent way to
              </span>
              <br />
              <span
                className="relative inline-block cursor-pointer select-none"
                onClick={function () { advanceWord(1); }}
                onMouseEnter={function () { setWordPaused(true); }}
                onMouseLeave={function () { setTimeout(function () { setWordPaused(false); }, 2000); }}
                style={{ perspective: "600px" }}
              >
                <AnimatePresence mode="wait" custom={wordDir}>
                  <motion.span
                    key={persona + "-" + wordIndex}
                    custom={wordDir}
                    variants={wordVariants}
                    initial="enter"
                    animate="center"
                    exit="exit"
                    className="inline-block gradient-brand"
                    style={{ transformStyle: "preserve-3d", fontSize: "clamp(30px,7vw,72px)" }}
                  >
                    {words[wordIndex]}
                  </motion.span>
                </AnimatePresence>
              </span>
            </motion.h1>
          </AnimatePresence>

          {/* ── Desktop: Word indicator dots ── */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.5 }}
            className="flex items-center justify-center gap-1.5 -mt-1"
          >
            {words.map(function (_, i) {
              return (
                <button
                  key={i}
                  onClick={function () { goToWord(i); }}
                  className="relative h-1.5 rounded-full transition-all duration-500 ease-out cursor-pointer"
                  aria-label={"Switch to: " + words[i]}
                  style={{
                    width: i === wordIndex ? 22 : 4,
                    backgroundColor: i === wordIndex ? "rgba(" + WORD_COLORS[wordIndex] + ",0.8)" : "rgba(255,255,255,0.08)",
                  }}
                >
                  {i === wordIndex && (
                    <motion.span
                      layoutId="wordDot"
                      className="absolute inset-0 rounded-full"
                      style={{ backgroundColor: "rgba(" + WORD_COLORS[wordIndex] + ",1)" }}
                      transition={{ type: "spring", stiffness: 300, damping: 25 }}
                    />
                  )}
                </button>
              );
            })}
          </motion.div>
        </div>

        {/* ── Subtitle (persona-aware) ── */}
        <AnimatePresence mode="wait">
          <motion.p
            key={"sub-" + persona}
            variants={personaVariants}
            initial="enter"
            animate="center"
            exit="exit"
            className="text-white/60 text-sm md:text-base max-w-xl leading-relaxed"
          >
            {current.subtitle}
          </motion.p>
        </AnimatePresence>

        {/* ── CTA — redirects to web app login ── */}
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.4 }}
          className="min-h-[50px] mt-1 w-full max-w-[380px] mx-auto"
        >
          <motion.a
            href={WEB_FALLBACK}
            target="_blank"
            rel="noopener noreferrer"
            initial={{ scale: 0.95, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ duration: 0.2 }}
            className="block btn-shimmer w-full py-3.5 text-[14px] font-medium rounded-full bg-gradient-to-r from-indigo-500 to-indigo-400 text-white hover:shadow-2xl hover:shadow-indigo-500/25 hover:scale-[1.03] transition-all duration-300 text-center"
          >
            {current.cta}
          </motion.a>
        </motion.div>

        {/* ── Video link ── */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.7 }}
        >
          <a
            href="/docs"
            className="inline-flex items-center gap-1.5 text-white/30 md:text-white/40 hover:text-white/70 transition-all duration-300 text-[12px] md:text-[13px] font-medium tracking-wide py-2"
          >
            Watch How It Works
            <ArrowRight className="w-3 h-3 md:w-3.5 md:h-3.5" />
          </a>
        </motion.div>

        {/* ── App Download Button (auto-fetches latest version from GitHub) ── */}
        <AppDownloadButton />
      </div>

      {/* ── Scroll indicator ── */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1.2 }}
        className="hidden md:flex absolute bottom-8 left-1/2 -translate-x-1/2 flex-col items-center gap-2 text-white/20"
      >
        <span className="text-[9px] font-medium tracking-[0.15em] uppercase">Scroll</span>
        <ChevronDown className="w-4 h-4 animate-bounce" />
      </motion.div>
    </section>
  );
}
