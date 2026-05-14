import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/system_config_provider.dart';

class UpdateWrapper extends ConsumerWidget {
  final Widget child;

  const UpdateWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateCheck = ref.watch(updateCheckProvider);

    return updateCheck.when(
      data: (result) {
        if (result.status == UpdateStatus.noUpdate) {
          return child;
        }

        if (result.status == UpdateStatus.maintenance) {
          return _MaintenanceOverlay(message: result.message);
        }

        if (result.status == UpdateStatus.forceUpdate) {
          return _UpdateOverlay(
            message: result.message,
            updateUrl: result.updateUrl,
            isForce: true,
            child: child,
          );
        }

        // Soft update - we can just return child and show a snackbar or a non-blocking dialog
        // For simplicity in this initial version, we'll return child but trigger a dialog after build
        if (result.status == UpdateStatus.softUpdate) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showSoftUpdateDialog(context, result);
          });
          return child;
        }

        return child;
      },
      loading: () => child,
      error: (_, __) => child,
    );
  }

  void _showSoftUpdateDialog(BuildContext context, UpdateCheckResult result) {
    // Check if already shown this session to avoid spamming
    // This could be handled with another provider or local state
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: Text(result.message ?? 'A new version is available.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              if (result.updateUrl != null) {
                launchUrl(Uri.parse(result.updateUrl!));
              }
              Navigator.pop(context);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceOverlay extends StatelessWidget {
  final String? message;

  const _MaintenanceOverlay({this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.build_rounded, size: 80, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'Under Maintenance',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message ?? 'We are currently performing scheduled maintenance.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateOverlay extends StatelessWidget {
  final String? message;
  final String? updateUrl;
  final bool isForce;
  final Widget child;

  const _UpdateOverlay({
    this.message,
    this.updateUrl,
    required this.isForce,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Semi-transparent background over the app
          child,
          Container(color: Colors.black54),
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.system_update_rounded, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'Update Required',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message ?? 'Please update the app to the latest version to continue.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (updateUrl != null) {
                          launchUrl(Uri.parse(updateUrl!));
                        }
                      },
                      child: const Text('Update Now'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
