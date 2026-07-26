import { useOutletContext } from "react-router-dom";
import LessonCard from "../components/LessonCard";
import { docsContent } from "../data/docsContent";

export default function PortfolioInsightsGuide() {
  const { lang } = useOutletContext();
  const t = docsContent[lang] || docsContent.en;

  return (
    <div className="space-y-8">
      <div>
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-indigo-500/15 to-cyan-500/8 border border-indigo-500/10 flex items-center justify-center">
            <span className="text-lg">📈</span>
          </div>
          <div>
            <h1 className="text-2xl font-bold text-primary">{t.portfolioInsights.title}</h1>
            <p className="text-tertiary text-xs mt-0.5">{t.portfolioInsights.lessons.length} {t.common.lessons}</p>
          </div>
        </div>
        <p className="text-secondary text-sm leading-relaxed">
          {t.portfolioInsights.desc}
        </p>
      </div>

      <div className="space-y-3">
        {t.portfolioInsights.lessons.map((lesson, i) => (
          <LessonCard key={i} {...lesson} />
        ))}
      </div>
    </div>
  );
}
