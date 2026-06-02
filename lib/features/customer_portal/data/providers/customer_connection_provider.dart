import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

/// True when the device has internet connectivity.
///
/// Emits whenever the connection state changes. Consumers (e.g. error states)
/// can `ref.listen` on this provider to auto-retry failed network requests
/// when connectivity is restored.
final isOnlineProvider = StreamProvider<bool>((ref) {
  return InternetConnectionChecker().onStatusChange.map(
        (status) => status == InternetConnectionStatus.connected,
      );
});
