import { useOutletContext } from "react-router-dom";
import LessonCard from "../components/LessonCard";
import { docsContent } from "../data/docsContent";

export default function CustomerGuide() {
  const { lang } = useOutletContext();
  const t = docsContent[lang] || docsContent.en;

  return (
    <div className="space-y-8">
      {/* Page Header */}
      <div>
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-green-500/20 to-emerald-500/10 border border-green-500/20 flex items-center justify-center">
            <span className="text-lg">📱</span>
          </div>
          <div>
            <h1 className="text-2xl font-bold text-white">{t.customer.title}</h1>
            <p className="text-white/40 text-xs mt-0.5">{t.customer.lessons.length} {t.common.lessons}</p>
          </div>
        </div>
        <p className="text-white/50 text-sm leading-relaxed">
          {t.customer.desc}
        </p>
      </div>

      {/* Lessons */}
      <div className="space-y-3">
        {t.customer.lessons.map((lesson, i) => (
          <LessonCard key={i} {...lesson} />
        ))}
      </div>
    </div>
  );
}
