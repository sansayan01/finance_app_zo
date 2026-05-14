import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AsyncValueSliver widget helper
class AsyncValueSliver<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget Function()? loadingBuilder;
  final Widget Function(Object error, StackTrace stackTrace)? errorBuilder;

  const AsyncValueSliver({
    required this.value,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: loadingBuilder ??
          () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
      error: errorBuilder ??
          (e, st) => SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 32),
                        const SizedBox(height: 8),
                        Text('Error: $e'),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}

/// AsyncValueWidget helper for non-sliver context
class AsyncValueWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  const AsyncValueWidget({
    required this.value,
    required this.builder,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}
