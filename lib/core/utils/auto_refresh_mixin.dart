import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mixin that invalidates specified providers when the page becomes visible.
/// Use this on ConsumerStatefulWidget pages to auto-refresh data on navigation return.
mixin AutoRefreshMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Override to return the list of providers to invalidate on page focus.
  List<ProviderOrFamily> get autoRefreshProviders;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Invalidate providers when dependencies change (including route changes)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        for (final provider in autoRefreshProviders) {
          ref.invalidate(provider);
        }
      }
    });
  }
}
