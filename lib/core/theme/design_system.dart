import 'package:flutter/material.dart';

class D {
  D._();

  static const Color accent = Color(0xFF06B6D4);
  static const Color accentLight = Color(0xFF22D3EE);

  static Color bg(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? const Color(0xFF070B11)
      : const Color(0xFFF1F5F9);
  static Color surface(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : Colors.white;
  static Color border(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.06);
  static Color text(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF0F172A);
  static Color muted(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.4)
          : Colors.black.withValues(alpha: 0.4);
  static Color dim(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.25)
      : Colors.black.withValues(alpha: 0.25);
  static Color fill(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? const Color(0xFF1F2532)
      : const Color(0xFFF1F5F9);
  static Color iconMuted(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.35)
          : Colors.black.withValues(alpha: 0.3);

  static EdgeInsets padding(double p) => EdgeInsets.all(p);
  static EdgeInsets hPadding = const EdgeInsets.symmetric(horizontal: 24);
  static EdgeInsets vPadding = const EdgeInsets.symmetric(vertical: 24);
  static const EdgeInsets bodyPad = EdgeInsets.fromLTRB(24, 20, 24, 0);
  static const EdgeInsets bodyBottomPad = EdgeInsets.fromLTRB(24, 0, 24, 100);
  static const double radius = 12;
  static const double radiusLg = 14;

  static BoxDecoration card(BuildContext c) => BoxDecoration(
        color: surface(c),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border(c)),
      );

  static Decoration cardWithBorder(BuildContext c, {Color? accentColor}) =>
      BoxDecoration(
        color: surface(c),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border(c)),
      );

  static TextStyle h1(bool isDark) => TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: isDark ? Colors.white : const Color(0xFF0F172A),
      letterSpacing: -0.5);
  static TextStyle h2(bool isDark) => TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: isDark ? Colors.white : const Color(0xFF0F172A),
      letterSpacing: -0.4);
  static TextStyle subtitleStyle(bool isDark) => TextStyle(
      fontSize: 14,
      color: isDark
          ? Colors.white.withValues(alpha: 0.4)
          : Colors.black.withValues(alpha: 0.4));
  static TextStyle labelStyle(bool isDark) => TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: isDark
          ? Colors.white.withValues(alpha: 0.55)
          : Colors.black.withValues(alpha: 0.5));
  static TextStyle valueStyle(bool isDark) => TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.white : const Color(0xFF0F172A));
  static TextStyle titleStyle(bool isDark) => TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : const Color(0xFF0F172A));

  static InputDecoration searchInput(
          BuildContext c, TextEditingController ctrl, VoidCallback onClear) =>
      InputDecoration(
        hintText: 'Search...',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: ctrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 18), onPressed: onClear)
            : null,
        filled: true,
        fillColor: surface(c),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: BorderSide(color: border(c))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: const BorderSide(color: accent)),
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
      );

  static Widget sectionTitle(String label, IconData icon, bool isDark) {
    return Row(children: [
      Icon(icon, size: 18, color: accent),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A))),
    ]);
  }

  static Widget header(String title, String sub, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: h1(isDark)),
      const SizedBox(height: 4),
      Text(sub, style: subtitleStyle(isDark)),
    ]);
  }

  static Widget statCard(
      String label, dynamic value, Color color, bool isDark, Color cardBg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor(isDark))),
      child: Column(children: [
        Text('$value',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: mutedColor(isDark))),
      ]),
    );
  }

  static Color borderColor(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.06);
  static Color mutedColor(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.4)
      : Colors.black.withValues(alpha: 0.4);
  static Color dimColor(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.2)
      : Colors.black.withValues(alpha: 0.2);
}
