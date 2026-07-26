import { useMemo } from "react";

export default function DocsBackground() {
  const gradientStyle = useMemo(() => ({
    background: `
      radial-gradient(ellipse 60% 35% at 15% 0%, rgba(79, 70, 229, 0.08), transparent 70%),
      radial-gradient(ellipse 50% 30% at 85% 100%, rgba(6, 182, 212, 0.05), transparent 70%),
      radial-gradient(ellipse 40% 40% at 50% 50%, rgba(79, 70, 229, 0.04), transparent 60%),
      linear-gradient(180deg, #030508 0%, #0C1018 50%, #030508 100%)
    `,
  }), []);

  return (
    <div className="fixed inset-0 z-0 overflow-hidden pointer-events-none" style={gradientStyle}>
      {/* Aurora glow domes — app-aligned */}
      <div className="absolute top-0 right-0 w-[600px] h-[600px] -translate-y-1/3 translate-x-1/4 opacity-[0.07]">
        <div className="w-full h-full rounded-full bg-indigo-500 blur-[150px]" />
      </div>
      <div className="absolute bottom-0 left-0 w-[500px] h-[500px] translate-y-1/3 -translate-x-1/4 opacity-[0.05]">
        <div className="w-full h-full rounded-full bg-cyan-500 blur-[120px]" />
      </div>
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[400px] h-[400px] opacity-[0.03]">
        <div className="w-full h-full rounded-full bg-violet-500 blur-[100px]" />
      </div>

      {/* Dot grid overlay */}
      <div className="absolute inset-0 opacity-[0.03] dot-grid pointer-events-none" />

      {/* Subtle noise texture */}
      <div className="absolute inset-0 opacity-[0.015] noise-overlay pointer-events-none" />
    </div>
  );
}
