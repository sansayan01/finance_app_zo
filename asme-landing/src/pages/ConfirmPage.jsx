import { useEffect, useState, useMemo } from "react";
import { motion, AnimatePresence } from "motion/react";
import { CheckCircle2, AlertCircle, ExternalLink, Smartphone, Download, ArrowRight } from "lucide-react";

/* ── Deep link & store config ── */
const DEEP_LINK = "com.microflow.pro://";
const PLAY_STORE = "https://play.google.com/store/apps/details?id=com.microflow.pro";
const APP_STORE = "https://apps.apple.com/app/microflow-pro/id6474879480"; // placeholder — update with real ID

/* ── Helpers ── */
function getTokensFromHash() {
  const hash = window.location.hash.slice(1); // strip '#'
  if (!hash) return {};
  const params = new URLSearchParams(hash);
  return {
    accessToken: params.get("access_token"),
    refreshToken: params.get("refresh_token"),
    type: params.get("type"),
  };
}

function getQueryParams() {
  return Object.fromEntries(new URLSearchParams(window.location.search));
}

function isMobile() {
  return /Android|iPhone|iPad|iPod|webOS|BlackBerry|IEMobile|Opera Mini/i.test(
    navigator.userAgent
  );
}

function openApp() {
  window.location.href = DEEP_LINK;
}

/* ── Animations ── */
const fadeUp = {
  hidden: { opacity: 0, y: 20, filter: "blur(6px)" },
  visible: (i) => ({
    opacity: 1,
    y: 0,
    filter: "blur(0px)",
    transition: { duration: 0.6, delay: i * 0.12, ease: [0.16, 1, 0.3, 1] },
  }),
};

const scaleIn = {
  hidden: { opacity: 0, scale: 0.6 },
  visible: {
    opacity: 1,
    scale: 1,
    transition: { duration: 0.5, ease: [0.16, 1, 0.3, 1] },
  },
};

export default function ConfirmPage() {
  const tokens = useMemo(() => getTokensFromHash(), []);
  const query = useMemo(() => getQueryParams(), []);

  /* ── Determine state ── */
  const hasTokens = Boolean(tokens.accessToken && tokens.refreshToken);
  const hasError = Boolean(query.error);
  const isSignup = tokens.type === "signup" || query.type === "signup";
  const orgName = query.org_name || null;

  const [countdown, setCountdown] = useState(8);

  /* ── Auto-open on mobile after countdown ── */
  useEffect(() => {
    if (!hasTokens || hasError || !isMobile()) return;
    if (countdown <= 0) {
      openApp();
      return;
    }
    const t = setTimeout(() => setCountdown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [countdown, hasTokens, hasError]);

  /* ════════════════════════════════════════════ */
  /* ERROR STATE */
  /* ════════════════════════════════════════════ */
  if (hasError) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center px-6">
        <BackgroundEffects />
        <motion.div
          initial="hidden"
          animate="visible"
          className="relative z-10 text-center max-w-md mx-auto"
        >
          <motion.div variants={scaleIn} custom={0} className="mb-6 inline-flex">
            <div className="w-20 h-20 rounded-full bg-red-500/10 border border-red-500/20 flex items-center justify-center">
              <AlertCircle className="w-10 h-10 text-red-400" />
            </div>
          </motion.div>

          <motion.h1
            variants={fadeUp}
            custom={1}
            style={{ fontFamily: "'Instrument Serif', serif" }}
            className="text-3xl md:text-4xl font-medium text-white mb-4"
          >
            Verification Failed
          </motion.h1>

          <motion.p variants={fadeUp} custom={2} className="text-white/50 text-sm leading-relaxed mb-8">
            {query.error_description
              ? decodeURIComponent(query.error_description).replace(/\+/g, " ")
              : "The verification link has expired or is invalid. Please try signing up again."}
          </motion.p>

          <motion.a
            variants={fadeUp}
            custom={3}
            href="/"
            className="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-white/[0.04] border border-white/[0.08] text-white/70 hover:text-white hover:border-white/[0.15] transition-all duration-300 text-sm font-medium"
          >
            Back to Home
            <ArrowRight className="w-3.5 h-3.5" />
          </motion.a>
        </motion.div>
      </div>
    );
  }

  /* ════════════════════════════════════════════ */
  /* SUCCESS STATE */
  /* ════════════════════════════════════════════ */
  if (hasTokens) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center px-6">
        <BackgroundEffects />
        <motion.div
          initial="hidden"
          animate="visible"
          className="relative z-10 text-center max-w-lg mx-auto"
        >
          {/* ── Checkmark ── */}
          <motion.div variants={scaleIn} custom={0} className="mb-6 inline-flex">
            <div className="w-24 h-24 rounded-full bg-gradient-to-br from-emerald-500/20 to-cyan-500/10 border border-emerald-500/25 flex items-center justify-center shadow-lg shadow-emerald-500/10">
              <motion.div
                initial={{ scale: 0, rotate: -45 }}
                animate={{ scale: 1, rotate: 0 }}
                transition={{ delay: 0.3, duration: 0.5, type: "spring", stiffness: 200 }}
              >
                <CheckCircle2 className="w-12 h-12 text-emerald-400" />
              </motion.div>
            </div>
          </motion.div>

          {/* ── Heading ── */}
          <motion.h1
            variants={fadeUp}
            custom={1}
            style={{ fontFamily: "'Instrument Serif', serif" }}
            className="text-4xl md:text-5xl font-medium text-white mb-3"
          >
            Email Verified!
          </motion.h1>

          <motion.p variants={fadeUp} custom={2} className="text-white/50 text-sm leading-relaxed mb-2">
            Your email has been confirmed successfully.
          </motion.p>

          {orgName && (
            <motion.p variants={fadeUp} custom={2.5} className="text-indigo-400/80 text-sm font-medium mb-8">
              Welcome to {orgName}
            </motion.p>
          )}

          {!orgName && <div className="mb-8" />}

          {/* ── Open App Button ── */}
          <motion.div variants={fadeUp} custom={3} className="flex flex-col items-center gap-4">
            <button
              onClick={openApp}
              className="btn-shimmer group relative w-full max-w-xs py-4 text-[15px] font-semibold rounded-2xl bg-gradient-to-r from-indigo-500 to-indigo-400 text-white hover:shadow-2xl hover:shadow-indigo-500/25 hover:scale-[1.02] transition-all duration-300 cursor-pointer flex items-center justify-center gap-2.5"
            >
              <Smartphone className="w-4.5 h-4.5" />
              Open MicroFlow Pro
              {isMobile() && countdown > 0 && (
                <span className="text-white/50 text-xs font-normal ml-1">
                  ({countdown}s)
                </span>
              )}
            </button>

            {/* ── Store links ── */}
            <div className="flex items-center gap-3">
              <a
                href={PLAY_STORE}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-white/[0.03] border border-white/[0.06] text-white/40 hover:text-white/70 hover:border-white/[0.12] transition-all duration-300 text-xs font-medium"
              >
                <Download className="w-3 h-3" />
                Play Store
              </a>
              <a
                href={APP_STORE}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-white/[0.03] border border-white/[0.06] text-white/40 hover:text-white/70 hover:border-white/[0.12] transition-all duration-300 text-xs font-medium"
              >
                <Download className="w-3 h-3" />
                App Store
              </a>
            </div>
          </motion.div>

          {/* ── Desktop hint ── */}
          {!isMobile() && (
            <motion.p
              variants={fadeUp}
              custom={4}
              className="mt-8 text-white/25 text-xs leading-relaxed max-w-xs mx-auto"
            >
              Open the link on your phone to continue in the app, or download it from the stores above.
            </motion.p>
          )}

          {/* ── Footer link ── */}
          <motion.div variants={fadeUp} custom={5} className="mt-10">
            <a
              href="/"
              className="text-white/20 hover:text-white/40 transition-colors text-xs font-medium"
            >
              microflow-pro.vercel.app
            </a>
          </motion.div>
        </motion.div>
      </div>
    );
  }

  /* ════════════════════════════════════════════ */
  /* NEUTRAL STATE (direct visit, no tokens) */
  /* ════════════════════════════════════════════ */
  return (
    <div className="min-h-screen bg-black flex items-center justify-center px-6">
      <BackgroundEffects />
      <motion.div
        initial="hidden"
        animate="visible"
        className="relative z-10 text-center max-w-md mx-auto"
      >
        <motion.div variants={scaleIn} custom={0} className="mb-6 inline-flex">
          <div className="w-20 h-20 rounded-full bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center">
            <Smartphone className="w-10 h-10 text-indigo-400" />
          </div>
        </motion.div>

        <motion.h1
          variants={fadeUp}
          custom={1}
          style={{ fontFamily: "'Instrument Serif', serif" }}
          className="text-3xl md:text-4xl font-medium text-white mb-4"
        >
          Check Your Email
        </motion.h1>

        <motion.p variants={fadeUp} custom={2} className="text-white/50 text-sm leading-relaxed mb-8">
          Please check your inbox and click the verification link to confirm your account.
        </motion.p>

        <motion.a
          variants={fadeUp}
          custom={3}
          href="/"
          className="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-white/[0.04] border border-white/[0.08] text-white/70 hover:text-white hover:border-white/[0.15] transition-all duration-300 text-sm font-medium"
        >
          Back to Home
          <ArrowRight className="w-3.5 h-3.5" />
        </motion.a>
      </motion.div>
    </div>
  );
}

/* ── Shared background (matches landing page) ── */
function BackgroundEffects() {
  return (
    <>
      {/* Gradient mesh */}
      <div className="fixed inset-0 pointer-events-none z-0">
        <div
          className="absolute inset-0"
          style={{
            background:
              "radial-gradient(ellipse 60% 50% at 50% 0%, hsla(263,90%,65%,0.06), transparent 60%), radial-gradient(ellipse 50% 40% at 80% 100%, hsla(187,90%,45%,0.04), transparent 60%)",
          }}
        />
      </div>

      {/* Floating orbs */}
      <div className="fixed inset-0 pointer-events-none z-0">
        <div className="floating-orb" />
        <div className="floating-orb" />
      </div>

      {/* Noise */}
      <div className="noise-overlay" />
    </>
  );
}
