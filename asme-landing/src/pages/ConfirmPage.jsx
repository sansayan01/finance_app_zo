import { useEffect, useState, useMemo } from "react";
import { motion } from "motion/react";
import {
  CheckCircle2, AlertCircle, Smartphone, ArrowRight,
  Sparkles,
} from "lucide-react";

const DEEP_LINK = "com.microflow.pro://";

function getTokensFromHash() {
  const h = window.location.hash.slice(1);
  if (!h) return {};
  const p = new URLSearchParams(h);
  return { accessToken: p.get("access_token"), refreshToken: p.get("refresh_token"), type: p.get("type") };
}
function getQuery() {
  return Object.fromEntries(new URLSearchParams(window.location.search));
}
function isMobile() {
  return /Android|iPhone|iPad|iPod|webOS|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
}

const fadeUp = {
  hidden: { opacity: 0, y: 20 },
  visible: (i) => ({
    opacity: 1, y: 0,
    transition: { duration: 0.5, delay: i * 0.08, ease: [0.16, 1, 0.3, 1] },
  }),
};
const scaleIn = {
  hidden: { opacity: 0, scale: 0.8 },
  visible: {
    opacity: 1, scale: 1,
    transition: { duration: 0.5, type: "spring", stiffness: 200, damping: 18 },
  },
};

export default function ConfirmPage() {
  const tokens = useMemo(() => getTokensFromHash(), []);
  const query = useMemo(() => getQuery(), []);
  const hasTokens = Boolean(tokens.accessToken && tokens.refreshToken);
  const hasError = Boolean(query.error);
  const orgName = query.org_name || null;
  const [countdown, setCountdown] = useState(8);

  useEffect(() => {
    if (!hasTokens || hasError || !isMobile()) return;
    if (countdown <= 0) { window.location.href = DEEP_LINK; return; }
    const t = setTimeout(() => setCountdown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [countdown, hasTokens, hasError]);

  const openApp = () => { window.location.href = DEEP_LINK; };

  /* ── Success / Neutral ── */
  if (!hasError) {
    const verified = hasTokens;
    return (
      <div className="min-h-screen bg-[#f8f9fb] flex items-center justify-center px-5">
        {/* Soft blurs */}
        <div className="fixed inset-0 pointer-events-none">
          <div className="absolute top-[-15%] left-[-8%] w-[500px] h-[500px] rounded-full bg-indigo-100/40 blur-[100px]" />
          <div className="absolute bottom-[-10%] right-[-5%] w-[400px] h-[400px] rounded-full bg-emerald-100/25 blur-[80px]" />
        </div>

        <motion.div
          initial="hidden" animate="visible"
          className="relative z-10 w-full max-w-[440px]"
        >
          {/* Card */}
          <div className="bg-white rounded-[1.5rem] p-8 md:p-10 shadow-[0_8px_40px_-12px_rgba(0,0,0,0.06)] border border-slate-200/60 text-center">
            {/* Heading */}
            <motion.h1
              variants={fadeUp} custom={0}
              className="text-[28px] md:text-[32px] font-bold tracking-[-0.03em] text-slate-900 mb-3"
            >
              Welcome to MicroFlow Pro.
            </motion.h1>

            <motion.p variants={fadeUp} custom={1} className="text-slate-500 text-[15px] leading-relaxed mb-5">
              Your account has been verified successfully.
            </motion.p>

            {/* Verified icon */}
            <motion.div variants={scaleIn} className="mb-5">
              <div className="w-[64px] h-[64px] rounded-[1.1rem] bg-gradient-to-br from-emerald-400 to-emerald-500 flex items-center justify-center mx-auto shadow-lg shadow-emerald-500/15">
                <CheckCircle2 className="w-8 h-8 text-white" strokeWidth={2} />
              </div>
            </motion.div>

            <motion.p variants={fadeUp} custom={3} className="text-slate-400 text-[13px] leading-relaxed max-w-[330px] mx-auto">
              You can now sign in to the app to manage your organization, track collections, and monitor your portfolio.
            </motion.p>

            {orgName && (
              <motion.p variants={fadeUp} custom={3.5} className="text-emerald-600 text-[13px] font-semibold flex items-center justify-center gap-1.5 mt-4 mb-1">
                <Sparkles className="w-3.5 h-3.5" />
                Welcome to {orgName}
              </motion.p>
            )}

            {/* Open App */}
            <motion.div variants={fadeUp} custom={4} className="mt-7">
              <button
                onClick={openApp}
                className="w-full py-4 px-6 rounded-2xl bg-slate-900 text-white text-[15px] font-semibold hover:bg-slate-800 active:scale-[0.98] transition-all duration-200 cursor-pointer flex items-center justify-center gap-2.5 shadow-[0_2px_16px_rgba(0,0,0,0.1)]"
              >
                <Smartphone className="w-[18px] h-[18px]" />
                Login Now
                {isMobile() && verified && countdown > 0 && (
                  <span className="text-white/50 text-[13px] font-normal ml-0.5">({countdown}s)</span>
                )}
              </button>
            </motion.div>
          </div>

          {/* Footer */}
          <motion.p variants={fadeUp} custom={6} className="text-center mt-5">
            <a href="/" className="text-slate-400 hover:text-slate-600 transition-colors text-[11px] font-medium">
              microflow-pro.vercel.app
            </a>
          </motion.p>
        </motion.div>
      </div>
    );
  }

  /* ── Error ── */
  return (
    <div className="min-h-screen bg-[#f8f9fb] flex items-center justify-center px-5">
      <div className="fixed inset-0 pointer-events-none">
        <div className="absolute top-[-15%] left-[-8%] w-[400px] h-[400px] rounded-full bg-red-100/25 blur-[80px]" />
      </div>
      <motion.div initial="hidden" animate="visible" className="relative z-10 w-full max-w-[400px] text-center">
        <div className="bg-white rounded-[1.5rem] p-8 md:p-10 shadow-[0_8px_40px_-12px_rgba(0,0,0,0.06)] border border-slate-200/60">
          <motion.div variants={scaleIn} className="mx-auto mb-5 w-14 h-14 rounded-2xl bg-red-50 border border-red-200/60 flex items-center justify-center">
            <AlertCircle className="w-7 h-7 text-red-500" />
          </motion.div>
          <motion.h1 variants={fadeUp} custom={1} className="text-[26px] font-bold tracking-[-0.025em] text-slate-900 mb-2">
            Verification Failed
          </motion.h1>
          <motion.p variants={fadeUp} custom={2} className="text-slate-500 text-[14px] leading-relaxed mb-7">
            {query.error_description
              ? decodeURIComponent(query.error_description).replace(/\+/g, " ")
              : "The verification link has expired or is invalid."}
          </motion.p>
          <motion.a variants={fadeUp} custom={3} href="/"
            className="inline-flex items-center gap-2 px-6 py-3 rounded-xl bg-slate-900 text-white text-[13px] font-semibold hover:bg-slate-800 transition-colors duration-200">
            Back to Home <ArrowRight className="w-3.5 h-3.5" />
          </motion.a>
        </div>
      </motion.div>
    </div>
  );
}
