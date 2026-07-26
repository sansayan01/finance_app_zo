import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/analytics_service.dart';

/// Exposes the [AnalyticsService] singleton to the Riverpod graph.
///
/// Usage in a widget/provider:
///   ref.read(analyticsProvider).track('collection_done', {...});
final Provider<AnalyticsService> analyticsProvider =
    Provider<AnalyticsService>((ref) => analytics);
