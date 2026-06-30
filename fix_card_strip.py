"""
Add colored left accent strip to payment cards by changing BoxDecoration
from `color:` to `gradient:` that includes a ~4px colored strip on the left.

This approach requires ZERO widget tree changes - no new closing brackets needed.
Works the same at any screen width because the strip width scales with content.

Card width calculation: screen - 32px (ListView padding 16*2)
    Phone (360): ~328px  -> 4px = 1.22%
    Tablet (768): ~736px -> 4px = 0.54%
We use stops [0.0, 0.08, 0.10, 1.0] for ~3-4px strip.
"""

files = {
    'admin': 'lib/features/payments/presentation/pages/today_payments_page.dart',
    'branch': 'lib/features/branch_manager/presentation/pages/branch_today_payments_page.dart',
    'staff': 'lib/features/staff/presentation/pages/staff_today_payments_page.dart',
}

# For _PaymentCard: replace the BoxDecoration color with gradient
old_decoration_color = '''            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: payment.statusColor.withValues(alpha: isDark ? 0.15 : 0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : Colors.grey.shade100)
                      .withValues(alpha: isDark ? 0.25 : 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),'''

new_decoration_gradient = '''            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: payment.statusColor.withValues(alpha: isDark ? 0.15 : 0.08),
                width: 1.0,
              ),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  payment.typeColor,
                  payment.typeColor.withValues(alpha: 0.15),
                  isDark ? AppColors.cardDark : Colors.white,
                ],
                stops: const [0.0, 0.08, 0.085],
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : Colors.grey.shade100)
                      .withValues(alpha: isDark ? 0.25 : 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),'''

# For _GroupedOverdueCard: same but with group.typeColor
old_grouped_decoration = '''            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.error.withValues(alpha: isDark ? 0.18 : 0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : Colors.grey.shade100)
                      .withValues(alpha: isDark ? 0.25 : 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),'''

new_grouped_decoration = '''            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.error.withValues(alpha: isDark ? 0.18 : 0.08),
                width: 1.0,
              ),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  group.typeColor,
                  group.typeColor.withValues(alpha: 0.15),
                  isDark ? AppColors.cardDark : Colors.white,
                ],
                stops: const [0.0, 0.08, 0.085],
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : Colors.grey.shade100)
                      .withValues(alpha: isDark ? 0.25 : 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),'''

for name, path in files.items():
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    modifications = 0
    
    # Apply _PaymentCard decoration change
    c1 = content.count(old_decoration_color)
    if c1 > 0:
        content = content.replace(old_decoration_color, new_decoration_gradient)
        modifications += c1
    
    # Apply _GroupedOverdueCard decoration change
    c2 = content.count(old_grouped_decoration)
    if c2 > 0:
        content = content.replace(old_grouped_decoration, new_grouped_decoration)
        modifications += c2
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f'{name}: {modifications} decorations updated')

print()
print('Done.')
