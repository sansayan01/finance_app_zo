import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.delayed(300.ms, () => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.8),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText: 'Search members, loans, or savings...',
                            hintStyle: theme.textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textTertiaryLight),
                            border: InputBorder.none,
                            icon: const Icon(Icons.search_rounded,
                                color: AppColors.primary),
                            suffixIcon: _controller.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        size: 18, color: AppColors.textTertiaryLight),
                                    onPressed: () {
                                      _controller.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Cancel',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildSearchResults(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 64,
              color: AppColors.textTertiaryLight.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Type something to start searching',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: AppColors.textTertiaryLight),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}
