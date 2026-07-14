import { useOutletContext } from "react-router-dom";
import LessonCard from "../components/LessonCard";
import { docsContent } from "../data/docsContent";

export default function ExecutiveAdminGuide() {
  const { lang } = useOutletContext();
  const t = docsContent[lang] || docsContent.en;

  return (
    <div className="space-y-8">
      {/* Page Header */}
      <div>
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-indigo-500/20 to-purple-500/10 border border-indigo-500/20 flex items-center justify-center">
            <span className="text-lg">🛡️</span>
          </div>
          <div>
            <h1 className="text-2xl font-bold text-white">{t.executiveAdmin.title}</h1>
            <p className="text-white/40 text-xs mt-0.5">{t.executiveAdmin.lessons.length} {t.common.lessons}</p>
          </div>
        </div>
        <p className="text-white/50 text-sm leading-relaxed">
          {t.executiveAdmin.desc}
        </p>
      </div>

      {/* Lessons */}
      <div className="space-y-3">
        {t.executiveAdmin.lessons.map((lesson, i) => (
          <LessonCard key={i} {...lesson} />
        ))}
      </div>
    </div>
  );
}
