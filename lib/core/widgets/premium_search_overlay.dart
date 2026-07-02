import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// A single search result item.
class OverlaySearchResult {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const OverlaySearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });
}

/// Premium search overlay with deep backdrop blur, live search, and smooth animations.
class PremiumSearchOverlay extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onSearch;
  final ValueChanged<String>? onChanged;
  final Future<List<OverlaySearchResult>> Function(String query)? fetchResults;
  final VoidCallback? onCancel;
  final String? initialQuery;

  const PremiumSearchOverlay({
    super.key,
    this.hintText = 'Search members, staff, loans...',
    required this.onSearch,
    this.onChanged,
    this.fetchResults,
    this.onCancel,
    this.initialQuery,
  });

  static Future<void> show(
    BuildContext context, {
    String hintText = 'Search members, staff, loans...',
    required ValueChanged<String> onSearch,
    ValueChanged<String>? onChanged,
    Future<List<OverlaySearchResult>> Function(String query)? fetchResults,
    String? initialQuery,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => PremiumSearchOverlay(
          hintText: hintText,
          onSearch: onSearch,
          onChanged: onChanged,
          fetchResults: fetchResults,
          initialQuery: initialQuery,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: child,
        ),
      ),
    );
  }

  @override
  State<PremiumSearchOverlay> createState() => _PremiumSearchOverlayState();
}

class _PremiumSearchOverlayState extends State<PremiumSearchOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  final _input = TextEditingController();
  final _focus = FocusNode();

  List<OverlaySearchResult> _results = [];
  bool _loading = false;
  Timer? _debounce;
  String _lastQuery = '';
  final Map<String, List<OverlaySearchResult>> _cache = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery?.isNotEmpty == true) {
      _input.text = widget.initialQuery!;
    }
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _start();
  }

  Future<void> _start() async {
    await Future.delayed(const Duration(milliseconds: 40));
    if (!mounted) return;
    _anim.forward();
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    _focus.requestFocus();
    if (_input.text.isNotEmpty) _doSearch(_input.text.trim());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _anim.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _close() {
    HapticFeedback.lightImpact();
    _anim.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCancel?.call();
      }
    });
  }

  void _submit(String v) {
    final q = v.trim();
    if (q.isNotEmpty) {
      HapticFeedback.mediumImpact();
      widget.onSearch(q);
    }
  }

  void _onChanged(String value) {
    widget.onChanged?.call(value);
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      if (_results.isNotEmpty || _loading) {
        setState(() { _results = []; _loading = false; });
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 180), () => _doSearch(q));
  }

  Future<void> _doSearch(String query) async {
    if (query == _lastQuery) return;
    _lastQuery = query;

    if (_cache.containsKey(query)) {
      if (mounted) setState(() { _results = _cache[query]!; _loading = false; });
      return;
    }

    if (mounted) setState(() => _loading = true);

    try {
      final results = await widget.fetchResults?.call(query) ?? [];
      _cache[query] = results;
      if (mounted && query == _lastQuery) {
        setState(() { _results = results; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _results = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top + 10;
    final screenW = mq.size.width;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final p = _anim.value;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Material(
          type: MaterialType.transparency,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (d, _) { if (!d) _close(); },
            child: Stack(children: [
              // ── Full-screen blur layer (BEHIND everything) ──
              Positioned.fill(
                child: GestureDetector(
                  onTap: _close,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 100),
                    opacity: p,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 16.0 * p,
                        sigmaY: 16.0 * p,
                      ),
                      child: Container(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.55 * p)
                            : Colors.black.withValues(alpha: 0.45 * p),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Search bar + results (foreground, blocks backdrop taps) ──
              Positioned(
                top: topPad,
                left: 16,
                right: 16,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildBar(p, screenW, isDark, theme),
                      if (_results.isNotEmpty || _loading || (_input.text.trim().length >= 2 && p > 0.5))
                        _buildResults(isDark, theme),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildBar(double p, double screenW, bool isDark, ThemeData theme) {
    final barW = screenW - 32;
    final barH = 56.0;
    final barR = 24.0;

    final fp = Curves.easeOutCubic.transform(p);

    final iconCol = Color.lerp(
      isDark ? Colors.white60 : Colors.black45,
      AppColors.primary,
      fp,
    );

    // Glassmorphic layers
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.04 + 0.04 * fp)
        : Colors.white.withValues(alpha: 0.65 + 0.15 * fp);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08 + 0.08 * fp)
        : Colors.white.withValues(alpha: 0.5 + 0.2 * fp);

    return Opacity(
      opacity: p,
      child: Transform.translate(
        offset: Offset(0, -10 + 10 * fp),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(barR),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20 * fp, sigmaY: 20 * fp),
            child: Container(
              width: barW,
              height: barH,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(barR),
                border: Border.all(color: borderColor, width: 0.8),
                boxShadow: [
                  // Outer shadow for depth
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18 * fp),
                    blurRadius: 20 * fp,
                    offset: Offset(0, 4 + 6 * fp),
                    spreadRadius: -3,
                  ),
                  // Inner highlight (top edge glow)
                  BoxShadow(
                    color: Colors.white.withValues(alpha: isDark ? 0.03 : 0.5),
                    blurRadius: 0,
                    offset: const Offset(0, -0.5),
                    spreadRadius: 0,
                  ),
                  // Primary ambient
                  BoxShadow(
                    color: (isDark ? AppColors.primaryDark : AppColors.primary)
                        .withValues(alpha: 0.06 * fp),
                    blurRadius: 48 * fp,
                    offset: const Offset(0, 2),
                    spreadRadius: -12,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(Icons.search_rounded, size: 22, color: iconCol),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Opacity(
                      opacity: fp,
                      child: TextField(
                        controller: _input,
                        focusNode: _focus,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.3,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        cursorColor: AppColors.primary,
                        textInputAction: TextInputAction.search,
                        onChanged: _onChanged,
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textTertiaryLight,
                            fontSize: 15,
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onSubmitted: _submit,
                      ),
                    ),
                  ),
                  if (fp > 0.5)
                    GestureDetector(
                      onTap: _input.text.isNotEmpty
                          ? () { _input.clear(); _onChanged(''); }
                          : _close,
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _input.text.isNotEmpty
                              ? Icons.close_rounded
                              : Icons.arrow_back_rounded,
                          size: 17,
                          color: AppColors.textTertiaryLight,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults(bool isDark, ThemeData theme) {
    final query = _input.text.trim();

    // Glassmorphic colors
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.7);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.5);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            margin: const EdgeInsets.only(top: 10),
            constraints: const BoxConstraints(maxHeight: 380),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: isDark ? 0.02 : 0.4),
                  blurRadius: 0,
                  offset: const Offset(0, -0.5),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : query.length < 2
                    ? const SizedBox.shrink()
                    : _results.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'No results found',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textTertiaryLight,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: _results.length,
                            itemBuilder: (_, i) => _Tile(
                              result: _results[i],
                              index: i,
                              isDark: isDark,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _results[i].onTap?.call();
                              },
                            ),
                          ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Result Tile with staggered entrance
// ══════════════════════════════════════════════════════════════════════════════

class _Tile extends StatefulWidget {
  final OverlaySearchResult result;
  final int index;
  final bool isDark;
  final VoidCallback onTap;

  const _Tile({
    required this.result,
    required this.index,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200 + widget.index * 40),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
    Future.delayed(Duration(milliseconds: 40 + widget.index * 40), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.result;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: r.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(r.icon, size: 19, color: r.color),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (r.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            r.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: AppColors.textTertiaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textTertiaryLight.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
