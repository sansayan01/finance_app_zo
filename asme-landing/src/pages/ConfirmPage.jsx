import { useEffect, useState, useMemo } from "react";
import { motion } from "motion/react";
import { CheckCircle2, AlertCircle, Smartphone, Download, ArrowRight, Mail, Sparkles } from "lucide-react";

/* ── Config ── */
const DEEP_LINK = "com.microflow.pro://";
const PLAY_STORE = "https://play.google.com/store/apps/details?id=com.microflow.pro";
const APP_STORE = "https://apps.apple.com/app/microflow-pro/id6474879480";

/* ── Helpers ── */
function getTokensFromHash() {
  const hash = window.location.hash.slice(1);
  if (!hash) return {};
  const params = new URLSearchParams(hash);
  return { accessToken: params.get("access_token"), refreshToken: params.get("refresh_token"), type: params.get("type") };
}

function getQueryParams() {
  return Object.fromEntries(new URLSearchParams(window.location.search));
}

function isMobile() {
  return /Android|iPhone|iPad|iPod|webOS|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
}

function openApp() { window.location.href = DEEP_LINK; }

/* ── Animations ── */
const fadeUp = {
  hidden: { opacity: 0, y: 24, filter: "blur(8px)" },
  visible: (i) => ({
    opacity: 1, y: 0, filter: "blur(0px)",
    transition: { duration: 0.7, delay: i * 0.1, ease: [0.16, 1, 0.3, 1] },
  }),
};

const scaleBounce = {
  hidden: { opacity: 0, scale: 0.5 },
  visible: {
    opacity: 1, scale: 1,
    transition: { duration: 0.6, type: "spring", stiffness: 200, damping: 15 },
  },
};

export default function ConfirmPage() {
  const tokens = useMemo(() => getTokensFromHash(), []);
  const query = useMemo(() => getQueryParams(), []);

  const hasTokens = Boolean(tokens.accessToken && tokens.refreshToken);
  const hasError = Boolean(query.error);
  const orgName = query.org_name || null;

  const [countdown, setCountdown] = useState(8);

  /* ── Auto-open on mobile ── */
  useEffect(() => {
    if (!hasTokens || hasError || !isMobile()) return;
    if (countdown <= 0) { openApp(); return; }
    const t = setTimeout(() => setCountdown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [countdown, hasTokens, hasError]);

  /* ═══════════════════════════════════════════ */
  /* SUCCESS STATE */
  /* ═══════════════════════════════════════════ */
  if (hasTokens) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center px-5 relative overflow-hidden">
        {/* ── Background layers ── */}
        <div className="fixed inset-0 pointer-events-none">
          <div className="absolute inset-0" style={{
            background: "radial-gradient(ellipse 70% 50% at 50% 20%, hsla(160,80%,50%,0.07), transparent 60%), radial-gradient(ellipse 60% 40% at 20% 80%, hsla(263,90%,65%,0.05), transparent 50%), radial-gradient(ellipse 50% 35% at 85% 70%, hsla(187,90%,45%,0.04), transparent 50%)"
          }} />
          <div className="floating-orb" style={{ width: 400, height: 400, top: "-5%", left: "-5%", background: "hsl(160,80%,50%)", opacity: 0.03, animationDuration: "28s" }} />
          <div className="floating-orb" style={{ width: 300, height: 300, bottom: "-8%", right: "-5%", background: "hsl(263,90%,65%)", opacity: 0.025, animationDuration: "24s", animationDelay: "-8s" }} />
        </div>

        <div className="noise-overlay" />

        {/* ── Card ── */}
        <motion.div
          initial="hidden" animate="visible"
          className="relative z-10 w-full max-w-[420px]"
        >
          <div className="liquid-glass rounded-3xl p-8 md:p-10 text-center relative overflow-hidden">
            {/* Glow accent behind icon */}
            <div className="absolute top-0 left-1/2 -translate-x-1/2 -translate-y-1/2 w-48 h-48 rounded-full"
              style={{ background: "radial-gradient(circle, hsla(160,80%,50%,0.15), transparent 70%)" }} />

            {/* ── Success icon ── */}
            <motion.div variants={scaleBounce} custom={0} className="relative mx-auto mb-6 w-20 h-20">
              <div className="absolute inset-0 rounded-full bg-emerald-500/10 blur-xl" />
              <div className="relative w-full h-full rounded-full bg-gradient-to-br from-emerald-500/20 to-teal-500/10 border border-emerald-500/25 flex items-center justify-center">
                <motion.div
                  initial={{ scale: 0, rotate: -90 }}
                  animate={{ scale: 1, rotate: 0 }}
                  transition={{ delay: 0.4, duration: 0.5, type: "spring", stiffness: 200 }}
                >
                  <CheckCircle2 className="w-10 h-10 text-emerald-400" />
                </motion.div>
              </div>
            </motion.div>

            {/* ── Headline ── */}
            <motion.h1
              variants={fadeUp} custom={1}
              style={{ fontFamily: "'Instrument Serif', serif" }}
              className="text-[32px] md:text-[38px] font-medium leading-tight mb-2"
            >
              <span className="bg-gradient-to-b from-white via-white/95 to-white/70 bg-clip-text text-transparent">
                Email Verified!
              </span>
            </motion.h1>

            <motion.p variants={fadeUp} custom={2} className="text-white/45 text-[14px] leading-relaxed mb-1">
              Your account has been confirmed successfully.
            </motion.p>

            {orgName && (
              <motion.p variants={fadeUp} custom={2.5} className="text-emerald-400/70 text-[13px] font-medium flex items-center justify-center gap-1.5 mb-6">
                <Sparkles className="w-3.5 h-3.5" />
                Welcome to {orgName}
              </motion.p>
            )}
            {!orgName && <div className="mb-6" />}

            {/* ── Open App Button ── */}
            <motion.div variants={fadeUp} custom={3}>
              <button
                onClick={openApp}
                className="btn-shimmer w-full py-4 rounded-2xl bg-gradient-to-r from-indigo-500 to-indigo-400 text-white text-[15px] font-semibold hover:shadow-2xl hover:shadow-indigo-500/25 hover:scale-[1.02] transition-all duration-300 cursor-pointer flex items-center justify-center gap-2.5"
              >
                <Smartphone className="w-4 h-4" />
                Open MicroFlow Pro
                {isMobile() && countdown > 0 && (
                  <span className="text-white/50 text-xs font-normal">({countdown}s)</span>
                )}
              </button>
            </motion.div>

            {/* ── Store links ── */}
            <motion.div variants={fadeUp} custom={4} className="flex items-center justify-center gap-3 mt-4">
              <a href={PLAY_STORE} target="_blank" rel="noopener noreferrer"
                className="inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-white/[0.03] border border-white/[0.06] text-white/35 hover:text-white/70 hover:border-white/[0.12] transition-all duration-300 text-[12px] font-medium">
                <Download className="w-3 h-3" /> Play Store
              </a>
              <a href={APP_STORE} target="_blank" rel="noopener noreferrer"
                className="inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-white/[0.03] border border-white/[0.06] text-white/35 hover:text-white/70 hover:border-white/[0.12] transition-all duration-300 text-[12px] font-medium">
                <Download className="w-3 h-3" /> App Store
              </a>
            </motion.div>

            {/* ── Desktop hint ── */}
            {!isMobile() && (
              <motion.p variants={fadeUp} custom={5} className="mt-6 text-white/20 text-[11px] leading-relaxed">
                Open the link on your phone to continue in the app.
              </motion.p>
            )}
          </div>

          {/* ── Footer ── */}
          <motion.p variants={fadeUp} custom={6} className="text-center mt-6">
            <a href="/" className="text-white/15 hover:text-white/35 transition-colors text-[11px] font-medium tracking-wide">
              microflow-pro.vercel.app
            </a>
          </motion.p>
        </motion.div>
      </div>
    );
  }

  /* ═══════════════════════════════════════════ */
  /* ERROR STATE */
  /* ═══════════════════════════════════════════ */
  if (hasError) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center px-5 relative overflow-hidden">
        <BackgroundEffects />
        <motion.div initial="hidden" animate="visible" className="relative z-10 w-full max-w-[420px]">
          <div className="liquid-glass rounded-3xl p-8 md:p-10 text-center">
            <motion.div variants={scaleBounce} custom={0} className="mx-auto mb-6 w-20 h-20 rounded-full bg-red-500/10 border border-red-500/20 flex items-center justify-center">
              <AlertCircle className="w-10 h-10 text-red-400" />
            </motion.div>

            <motion.h1 variants={fadeUp} custom={1} style={{ fontFamily: "'Instrument Serif', serif" }}
              className="text-[32px] font-medium leading-tight mb-3">
              <span className="bg-gradient-to-b from-white via-white/95 to-white/70 bg-clip-text text-transparent">
                Verification Failed
              </span>
            </motion.h1>

            <motion.p variants={fadeUp} custom={2} className="text-white/45 text-[14px] leading-relaxed mb-8">
              {query.error_description
                ? decodeURIComponent(query.error_description).replace(/\+/g, " ")
                : "The verification link has expired or is invalid."}
            </motion.p>

            <motion.a variants={fadeUp} custom={3} href="/"
              className="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-white/[0.04] border border-white/[0.08] text-white/60 hover:text-white hover:border-white/[0.15] transition-all duration-300 text-[13px] font-medium">
              Back to Home <ArrowRight className="w-3.5 h-3.5" />
            </motion.a>
          </div>
        </motion.div>
      </div>
    );
  }

  /* ═══════════════════════════════════════════ */
  /* NEUTRAL STATE (direct visit) */
  /* ═══════════════════════════════════════════ */
  return (
    <div className="min-h-screen bg-black flex items-center justify-center px-5 relative overflow-hidden">
      <BackgroundEffects />
      <motion.div initial="hidden" animate="visible" className="relative z-10 w-full max-w-[420px]">
        <div className="liquid-glass rounded-3xl p-8 md:p-10 text-center">
          <motion.div variants={scaleBounce} custom={0} className="mx-auto mb-6 w-20 h-20 rounded-full bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center">
            <Mail className="w-10 h-10 text-indigo-400" />
          </motion.div>

          <motion.h1 variants={fadeUp} custom={1} style={{ fontFamily: "'Instrument Serif', serif" }}
            className="text-[32px] font-medium leading-tight mb-3">
            <span className="bg-gradient-to-b from-white via-white/95 to-white/70 bg-clip-text text-transparent">
              Check Your Email
            </span>
          </motion.h1>

          <motion.p variants={fadeUp} custom={2} className="text-white/45 text-[14px] leading-relaxed mb-8">
            We've sent a verification link to your email.<br />Click it to confirm your account.
          </motion.p>

          <motion.a variants={fadeUp} custom={3} href="/"
            className="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-white/[0.04] border border-white/[0.08] text-white/60 hover:text-white hover:border-white/[0.15] transition-all duration-300 text-[13px] font-medium">
            Back to Home <ArrowRight className="w-3.5 h-3.5" />
          </motion.a>
        </div>

        <motion.p variants={fadeUp} custom={4} className="text-center mt-6">
          <a href="/" className="text-white/15 hover:text-white/35 transition-colors text-[11px] font-medium tracking-wide">
            microflow-pro.vercel.app
          </a>
        </motion.p>
      </motion.div>
    </div>
  );
}

/* ── Shared background ── */
function BackgroundEffects() {
  return (
    <>
      <div className="fixed inset-0 pointer-events-none">
        <div className="absolute inset-0" style={{
          background: "radial-gradient(ellipse 60% 50% at 50% 0%, hsla(263,90%,65%,0.06), transparent 60%), radial-gradient(ellipse 50% 40% at 80% 100%, hsla(187,90%,45%,0.04), transparent 60%)"
        }} />
        <div className="floating-orb" />
        <div className="floating-orb" />
      </div>
      <div className="noise-overlay" />
    </>
  );
}
