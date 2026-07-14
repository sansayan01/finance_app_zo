import { Link, useOutletContext } from "react-router-dom";
import {
  Shield, Users, UserCircle, Smartphone,
  Play, FileText, BookOpen, ArrowRight
} from "lucide-react";
import { docsContent } from "./data/docsContent";

export default function DocsHome() {
  const { lang } = useOutletContext();

  // Fallback to English if translation is missing
  const t = docsContent[lang] || docsContent.en;

  const portalCards = [
    {
      title: t.home.portals.admin.title,
      desc: t.home.portals.admin.desc,
      icon: Shield,
      path: "/docs/executive-admin",
      iconWrap: "icon-wrap-indigo",
      lessonsCount: 7,
    },
    {
      title: t.home.portals.manager.title,
      desc: t.home.portals.manager.desc,
      icon: Users,
      path: "/docs/branch-manager",
      iconWrap: "icon-wrap-cyan",
      lessonsCount: 4,
    },
    {
      title: t.home.portals.agent.title,
      desc: t.home.portals.agent.desc,
      icon: UserCircle,
      path: "/docs/collection-agent",
      iconWrap: "icon-wrap-amber",
      lessonsCount: 4,
    },
    {
      title: t.home.portals.customer.title,
      desc: t.home.portals.customer.desc,
      icon: Smartphone,
      path: "/docs/customer",
      iconWrap: "icon-wrap-green",
      lessonsCount: 3,
    },
  ];

  return (
    <div className="space-y-16">
      {/* ─── Hero ─── */}
      <div className="relative">
        <div className="absolute -top-8 -left-8 w-32 h-32 bg-indigo-500/10 blur-[60px] rounded-full pointer-events-none" />

        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-indigo-500/15 to-indigo-500/5 border border-indigo-500/15 flex items-center justify-center">
            <BookOpen className="w-5 h-5 text-indigo-300" />
          </div>
          <div>
            <h1 className="text-2xl sm:text-3xl font-bold text-white tracking-tight">
              {t.home.title}
            </h1>
            <p className="text-white/30 text-xs mt-0.5">{t.home.subtitle}</p>
          </div>
        </div>

        <p className="text-white/45 text-sm sm:text-base leading-relaxed max-w-2xl">
          {t.home.desc}
        </p>

        {/* Stat pills */}
        <div className="flex flex-wrap gap-3 mt-6">
          <div className="flex items-center gap-2 px-3.5 py-2 rounded-full bg-white/[0.03] border border-white/[0.05]">
            <span className="w-1.5 h-1.5 rounded-full bg-indigo-400" />
            <span className="text-xs text-white/50"><strong className="text-white/70">22</strong> {t.common.lessons}</span>
          </div>
          <div className="flex items-center gap-2 px-3.5 py-2 rounded-full bg-white/[0.03] border border-white/[0.05]">
            <span className="w-1.5 h-1.5 rounded-full bg-cyan-400" />
            <span className="text-xs text-white/50"><strong className="text-white/70">4</strong> {t.common.portals}</span>
          </div>
          <div className="flex items-center gap-2 px-3.5 py-2 rounded-full bg-white/[0.03] border border-white/[0.05]">
            <span className="w-1.5 h-1.5 rounded-full bg-red-400" />
            <span className="text-xs text-white/50"><strong className="text-white/70">Video</strong> tutorials</span>
          </div>
        </div>
      </div>

      {/* ─── Portal Cards Grid ─── */}
      <div>
        <div className="flex items-center gap-2 mb-5">
          <div className="h-px flex-1 bg-gradient-to-r from-indigo-500/10 to-transparent" />
          <span className="text-[10px] font-semibold text-white/20 uppercase tracking-[0.2em]">{t.common.selectPortal}</span>
          <div className="h-px flex-1 bg-gradient-to-l from-indigo-500/10 to-transparent" />
        </div>

        <div className="grid sm:grid-cols-2 gap-4">
          {portalCards.map((card) => (
            <Link
              key={card.path}
              to={card.path}
              className="group relative rounded-2xl border border-white/[0.04] bg-white/[0.01] hover:bg-white/[0.02] transition-all duration-500 overflow-hidden"
            >
              {/* Hover glow */}
              <div className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-500 pointer-events-none">
                <div className="absolute -top-20 -right-20 w-40 h-40 bg-indigo-500/10 blur-[60px] rounded-full" />
              </div>

              {/* Border glow on hover */}
              <div className="absolute inset-0 rounded-2xl opacity-0 group-hover:opacity-100 transition-opacity duration-500 pointer-events-none ring-1 ring-indigo-500/10 ring-inset" />

              <div className="relative p-5 sm:p-6">
                <div className="flex items-start gap-4">
                  <div className={`shrink-0 w-11 h-11 rounded-xl ${card.iconWrap} flex items-center justify-center border`}>
                    <card.icon className="w-5 h-5 text-white/80" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <h3 className="text-white font-semibold text-base mb-1.5 group-hover:text-indigo-200 transition-colors">
                      {card.title}
                    </h3>
                    <p className="text-white/40 text-sm leading-relaxed">{card.desc}</p>
                  </div>
                </div>

                <div className="flex items-center justify-between mt-4 pt-4 border-t border-white/[0.03]">
                  <div className="flex items-center gap-2 text-xs text-white/25">
                    <Play className="w-3 h-3" />
                    <span>{card.lessonsCount} {t.common.lessons}</span>
                  </div>
                  <span className="text-xs text-white/20 group-hover:text-indigo-300 transition-colors flex items-center gap-1">
                    {t.common.openGuideAction} <ArrowRight className="w-3 h-3" />
                  </span>
                </div>
              </div>
            </Link>
          ))}
        </div>
      </div>

      {/* ─── Popular Guides ─── */}
      <div>
        <div className="flex items-center gap-2 mb-5">
          <FileText className="w-4 h-4 text-indigo-400" />
          <span className="text-sm font-medium text-white/60">{t.common.popularGuides}</span>
        </div>
        <div className="grid sm:grid-cols-2 gap-2.5">
          {t.home.topics.map((topic, i) => (
            <Link
              key={i}
              to={topic.path}
              className="flex items-center gap-3 px-4 py-3 rounded-xl bg-white/[0.01] border border-white/[0.04] hover:border-indigo-500/12 hover:bg-indigo-500/[0.02] text-white/50 hover:text-white/80 text-sm transition-all duration-200 group"
            >
              <span className="text-base">{topic.label.split(" ")[0]}</span>
              <span className="flex-1">{topic.label.replace(/^[^\s]+\s/, "")}</span>
              <ArrowRight className="w-3 h-3 text-white/15 group-hover:text-indigo-300 transition-colors shrink-0" />
            </Link>
          ))}
        </div>
      </div>

      {/* ─── YouTube CTA ─── */}
      <div className="relative rounded-2xl overflow-hidden border border-red-500/10 bg-gradient-to-br from-red-500/[0.03] to-transparent">
        <div className="absolute -top-10 -right-10 w-32 h-32 bg-red-500/10 blur-[50px] rounded-full pointer-events-none" />

        <div className="relative p-6 sm:p-8 flex flex-col sm:flex-row items-start sm:items-center gap-5">
          <div className="shrink-0 w-14 h-14 rounded-2xl bg-red-500/10 border border-red-500/15 flex items-center justify-center">
            <Play className="w-6 h-6 fill-red-400 text-red-400" />
          </div>
          <div className="flex-1 min-w-0">
            <h3 className="text-white font-semibold text-lg mb-1">{t.common.youtubeCtaTitle}</h3>
            <p className="text-white/45 text-sm leading-relaxed">
              {t.common.youtubeCtaDesc}
            </p>
          </div>
          <a
            href="https://www.youtube.com/@Microflow_Pro"
            target="_blank"
            rel="noopener noreferrer"
            className="shrink-0 inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-red-500/10 border border-red-500/20 text-red-400 hover:bg-red-500/20 transition-all text-sm font-medium"
          >
            <Play className="w-4 h-4 fill-red-400" />
            {t.common.subscribe}
          </a>
        </div>
      </div>
    </div>
  );
}
