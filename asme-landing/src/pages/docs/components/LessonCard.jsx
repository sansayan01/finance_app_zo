import { Play, ChevronDown } from "lucide-react";
import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";

/**
 * LessonCard — har topic ke liye video + text lesson ek saath.
 *
 * Props:
 *   title       — Topic name (e.g. "Daily Collection Kaise Karein")
 *   videoId     — YouTube video ID (null jab video nahi hai)
 *   steps       — Array of step objects: { label, desc? }
 *   note        — Optional tip/warning
 *   icon        — Emoji string (optional)
 *   accent      — border color class (default: indigo)
 */
export default function LessonCard({ title, videoId, steps, note, icon, accent }) {
  const [expanded, setExpanded] = useState(false);

  const borderAccent = accent || "border-indigo-500/15";
  const bgAccent = accent?.replace("border-", "bg-").replace("/15", "/8") || "bg-indigo-500/8";

  return (
    <div
      className={`lesson-card relative border ${borderAccent} transition-all duration-300 overflow-hidden ${
        expanded ? "lesson-card-expanded" : ""
      }`}
    >
      {/* Left accent bar — visible when expanded */}
      <div
        className={`absolute left-0 top-0 bottom-0 w-0.5 rounded-r-full transition-all duration-500 ${
          expanded ? "bg-gradient-to-b from-indigo-400 to-cyan-400 opacity-70" : "opacity-0"
        }`}
      />

      {/* Top gradient shimmer on expand */}
      <AnimatePresence>
        {expanded && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="absolute top-0 inset-x-0 h-px bg-gradient-to-r from-transparent via-indigo-400/25 to-transparent pointer-events-none"
          />
        )}
      </AnimatePresence>

      {/* Header (clickable) */}
      <button
        onClick={() => setExpanded(!expanded)}
        className="w-full flex items-center justify-between p-4 sm:p-5 text-left cursor-pointer relative z-10"
      >
        <div className="flex items-center gap-3 min-w-0">
          {icon && (
            <span className="shrink-0 w-9 h-9 rounded-xl bg-white/[0.03] border border-white/[0.06] flex items-center justify-center text-base">
              {icon}
            </span>
          )}
          <h3 className="text-primary font-semibold text-sm sm:text-base leading-snug">{title}</h3>
        </div>
        <div className={`shrink-0 w-7 h-7 rounded-full flex items-center justify-center transition-all duration-300 ${
          expanded ? "bg-indigo-500/12" : "bg-white/[0.03]"
        }`}>
          <ChevronDown
            className={`w-3.5 h-3.5 transition-all duration-300 ${
              expanded ? "text-indigo-300 rotate-180" : "text-tertiary"
            }`}
          />
        </div>
      </button>

      {/* Expanded Content */}
      <AnimatePresence>
        {expanded && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
            className="overflow-hidden"
          >
            <div className="px-4 sm:px-5 pb-5 space-y-5 relative z-10">
              {/* Video Embed */}
              {videoId && (
                <div className="relative aspect-video rounded-xl overflow-hidden bg-black/40 border border-white/[0.06] shadow-lg">
                  <iframe
                    src={`https://www.youtube.com/embed/${videoId}`}
                    title={title}
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                    allowFullScreen
                    className="w-full h-full"
                  />
                </div>
              )}

              {/* Steps */}
              {steps && steps.length > 0 && (
                <div className="space-y-2.5">
                  <div className="text-[10px] font-semibold text-tertiary uppercase tracking-[0.15em]">
                    Step-by-Step Guide
                  </div>
                  {steps.map((step, i) => (
                    <div key={i} className="flex gap-3 p-3 rounded-xl bg-white/[0.015] border border-white/[0.03]">
                      <span className="shrink-0 w-6 h-6 rounded-full bg-gradient-to-br from-indigo-500/12 to-indigo-500/5 border border-indigo-500/10 flex items-center justify-center text-[11px] font-semibold text-indigo-300">
                        {i + 1}
                      </span>
                      <div className="pt-0.5 min-w-0">
                        <span className="text-primary text-sm">{step.label}</span>
                        {step.desc && (
                          <p className="text-secondary text-xs mt-1 leading-relaxed">{step.desc}</p>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {/* Note / Tip */}
              {note && (
                <div className="flex gap-2.5 p-3.5 rounded-xl bg-gradient-to-br from-amber-500/5 to-amber-500/[0.02] border border-amber-500/10">
                  <span className="shrink-0 text-sm mt-0.5">💡</span>
                  <span className="text-amber-200/70 text-xs leading-relaxed">{note}</span>
                </div>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
