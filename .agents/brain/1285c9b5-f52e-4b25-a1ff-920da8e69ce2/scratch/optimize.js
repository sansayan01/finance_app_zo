const fs = require('fs');

const filePath = 'd:\\Projects\\finance_app_zo\\lib\\features\\loans\\presentation\\pages\\loan_detail_page.dart';
let content = fs.readFileSync(filePath, 'utf8');

// Regex to find the staff notes ListView
// It starts with ListView.separated( around line 3810
// We look for shrinkWrap: true and notes.length
const staffNotesRegex = /ListView\.separated\(\s*shrinkWrap: true,\s*physics: const NeverScrollableScrollPhysics\(\),\s*itemCount: notes\.length,\s*separatorBuilder: \(_, __\) => const SizedBox\(height: 10\),\s*itemBuilder: \(context, index\) \{[\s\S]*?\}\s*,\s*\)/;

const replacement = `Column(
                  children: [
                    for (int i = 0; i < notes.length; i++) ...[
                      Builder(builder: (context) {
                        final note = notes[i];
                        final text = note['text'] as String;
                        final isLatest = note['isLatest'] as bool;
                        
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isLatest 
                                ? const Color(0xFF5E5CE6).withValues(alpha: 0.08)
                                : theme.colorScheme.surface.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: isLatest 
                                ? Border.all(color: const Color(0xFF5E5CE6).withValues(alpha: 0.2))
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isLatest ? const Color(0xFF5E5CE6) : theme.dividerColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isLatest ? 'LATEST UPDATE' : 'PAST NOTE',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1,
                                          color: isLatest ? const Color(0xFF5E5CE6) : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    note['date'] as String,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                text,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.5,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundColor: const Color(0xFF5E5CE6).withValues(alpha: 0.1),
                                    child: Text(
                                      (note['author'] as String)[0],
                                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF5E5CE6)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    note['author'] as String,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      if (i < notes.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                )`;

const normalizedContent = content.replace(/\r\n/g, '\n');
if (staffNotesRegex.test(normalizedContent)) {
  const newContent = normalizedContent.replace(staffNotesRegex, replacement);
  fs.writeFileSync(filePath, newContent, 'utf8');
  console.log('Replaced staff notes ListView (Regex)');
} else {
  console.log('Staff notes ListView not found via Regex');
  // Log the first part of what we expect to help debug
  const start = normalizedContent.indexOf('ListView.separated(');
  if (start !== -1) {
    console.log('Found a ListView.separated at index', start);
    console.log('Context:', normalizedContent.substring(start, start + 200));
  }
}
