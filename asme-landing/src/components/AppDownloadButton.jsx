import { useState, useEffect } from "react";
import { motion } from "motion/react";
import { Download, Smartphone, Loader2, Sparkles, Star } from "lucide-react";

const GITHUB_API = "https://api.github.com/repos/sansayan01/finance_app_zo/releases/latest";
const CACHE_KEY = "microflow_latest_release";

export default function AppDownloadButton() {
  const [release, setRelease] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  useEffect(() => {
    const cached = sessionStorage.getItem(CACHE_KEY);
    if (cached) {
      try {
        const parsed = JSON.parse(cached);
        if (parsed.tag) {
          setRelease(parsed);
          setLoading(false);
          return;
        }
      } catch {}
    }

    fetch(GITHUB_API)
      .then((res) => {
        if (!res.ok) throw new Error("API error");
        return res.json();
      })
      .then((data) => {
        const tag = data.tag_name || "v1.0";
        const apkAsset = data.assets?.find(
          (a) => a.name === "app-release.apk"
        );
        const downloadUrl =
          apkAsset?.browser_download_url ||
          `https://github.com/sansayan01/finance_app_zo/releases/download/${tag}/app-release.apk`;

        const releaseData = { tag, downloadUrl };
        setRelease(releaseData);
        sessionStorage.setItem(CACHE_KEY, JSON.stringify(releaseData));
        setLoading(false);
      })
      .catch(() => {
        setError(true);
        setLoading(false);
      });
  }, []);

  if (loading) {
    return (
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        className="flex items-center justify-center gap-2 text-white/30 text-sm py-4"
      >
        <Loader2 className="w-4 h-4 animate-spin" />
        <span className="tracking-wide">Loading latest version...</span>
      </motion.div>
    );
  }

  const version = release?.tag?.replace(/^v/, "") || "";
  const url =
    release?.downloadUrl ||
    "https://github.com/sansayan01/finance_app_zo/releases/latest/download/app-release.apk";

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.7, duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
      className="flex flex-col items-center gap-3 pt-2 pb-3"
    >
      {/* ─── Glass Card Download Button ─── */}
      <motion.a
        href={url}
        download
        target="_blank"
        rel="noopener noreferrer"
        whileHover={{ scale: 1.03 }}
        whileTap={{ scale: 0.97 }}
        className="relative group"
      >
        {/* Static gradient border glow — clean, no rotation */}
        <div className="absolute -inset-[1px] rounded-2xl bg-gradient-to-r from-indigo-500/30 via-cyan-400/20 to-indigo-500/30 opacity-60 group-hover:opacity-100 blur-sm transition-all duration-500" />

        {/* Glass body */}
        <div className="relative flex items-center gap-4 px-6 py-3.5 rounded-2xl bg-white/[0.03] backdrop-blur-xl border border-white/[0.06] group-hover:bg-white/[0.05] group-hover:border-white/[0.15] transition-all duration-300">
          {/* Icon container with glow */}
          <div className="relative shrink-0">
            <div className="absolute inset-0 bg-indigo-500/20 blur-lg rounded-xl" />
            <div className="relative w-10 h-10 rounded-xl bg-gradient-to-br from-indigo-500/20 to-indigo-500/5 border border-indigo-400/20 flex items-center justify-center">
              <Smartphone className="w-5 h-5 text-indigo-300" />
            </div>
          </div>

          {/* Text */}
          <div className="flex flex-col items-start">
            <div className="flex items-center gap-2.5">
              <span className="text-white font-bold text-[15px] tracking-[-0.01em]">
                Download App
              </span>
              {/* "New" badge */}
              <span className="flex items-center gap-1 px-2 py-0.5 rounded-md bg-emerald-400/10 border border-emerald-400/15 text-[9px] font-bold text-emerald-300 uppercase tracking-wide">
                <Sparkles className="w-2.5 h-2.5" />
                Live
              </span>
            </div>
            {version && (
              <span className="text-white/35 text-[10px] font-medium -mt-0.5">
                v{version}
              </span>
            )}
          </div>

          {/* Download arrow */}
          <div className="shrink-0 w-9 h-9 rounded-full bg-white/[0.04] border border-white/[0.06] group-hover:bg-indigo-500/10 group-hover:border-indigo-400/20 transition-all duration-300 flex items-center justify-center">
            <Download className="w-4 h-4 text-white/40 group-hover:text-indigo-300 transition-colors" />
          </div>
        </div>
      </motion.a>

      {/* Subtext */}
      <motion.p
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1.1, duration: 0.5 }}
        className="text-white/15 text-[9px] font-medium flex items-center gap-2"
      >
        <span className="w-1 h-1 rounded-full bg-emerald-400/40" />
        Android APK
      </motion.p>
    </motion.div>
  );
}
