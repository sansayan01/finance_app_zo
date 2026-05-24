/// App-wide layout constants.
///
/// Use these instead of magic numbers when working around the floating
/// glass bottom navigation bar.
library;

import 'package:flutter/widgets.dart';

/// The amount of padding that pages should leave at the bottom so their
/// last item is not hidden behind the floating glass bottom navigation bar.
///
/// Kept intentionally small (15 px) — this value is *added* on top of the
/// system bottom inset (gesture nav etc.) by [_NavSafeArea] in the shells,
/// and many existing pages already include their own hardcoded bottom
/// breathing room. Bumping this further would compound into excessive
/// empty space.
///
/// Pages that already use [SafeArea](`bottom: true`) or default
/// [MediaQuery.padding.bottom] inside [AdminShell] / [StaffShell] don't
/// need this — the shells inject an inflated [MediaQuery] for that case.
/// Use this constant when you have an explicit
/// `padding: EdgeInsets.fromLTRB(.., .., .., 0)` and want to fix it.
const double kBottomNavSafeArea = 15;

/// Convenience: an [EdgeInsets] with only the bottom inflated for the navbar.
const EdgeInsets kBottomNavInsets = EdgeInsets.only(bottom: kBottomNavSafeArea);

/// The visual height of the floating glass bottom navigation bar used
/// in [CustomerShell] (and similar shells). This excludes the system
/// bottom inset (handled via [MediaQuery.viewPadding]).
///
/// Use this in bottom sheets and modals to push content above the bar.
/// Example:
/// ```dart
/// MediaQuery.of(ctx).viewInsets.bottom +
///   MediaQuery.of(ctx).viewPadding.bottom +
///   kBottomNavBarHeight
/// ```
const double kBottomNavBarHeight = 72;

/// Convenience: padding for a [FloatingActionButton] inside the
/// [AdminShell] / [StaffShell] so it floats above the glass navbar
/// instead of being eclipsed by it.
const EdgeInsets kFabSafeAreaPadding = EdgeInsets.only(bottom: 80);
