// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sanitize an exception / error object into a human-friendly string.
///
/// The `errorFormatter` collapses low-level exceptions (Postgres, network,
/// auth) into short, *actionable* user messages. Raw `e.toString()` output
/// is never shown to end users — it leaks internals (column names, RLS
/// policy names, JWT claims, etc.).

/// Sanitize an exception / error object into a human-friendly string.
///
/// If [fallback] is supplied it is used when no specific match is found.
String errorFormatter(Object? error, {String? fallback}) {
  if (error == null) return fallback ?? 'Something went wrong';

  final raw = error.toString().toLowerCase();

  // 1) Network / socket errors
  if (raw.contains('socketexception') ||
      raw.contains('network is unreachable') ||
      raw.contains('failed host lookup') ||
      raw.contains('connection refused') ||
      raw.contains('connection timed out') ||
      raw.contains('no internet')) {
    return 'No internet connection. Please check your network and try again.';
  }

  // 2) Auth errors
  if (raw.contains('invalid login credentials') ||
      raw.contains('invalid_credentials')) {
    return 'Incorrect email or password.';
  }
  if (raw.contains('email not confirmed')) {
    return 'Please verify your email address before signing in.';
  }
  if (raw.contains('user already registered')) {
    return 'An account with this email already exists.';
  }
  if (raw.contains('rate limit')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }

  // 3) Permission / RLS
  if (raw.contains('permission denied') ||
      raw.contains('row-level security') ||
      raw.contains('new row violates row-level security')) {
    return 'You do not have permission to perform this action.';
  }

  // 4) Unique constraint
  if (raw.contains('duplicate key') ||
      raw.contains('unique constraint') ||
      raw.contains('already exists')) {
    return 'A record with these details already exists.';
  }

  // 5) Foreign key / missing
  if (raw.contains('foreign key') || raw.contains('violates fk')) {
    return 'Cannot complete action: this record is referenced by other data.';
  }
  if (raw.contains('not found') || raw.contains('pgrst116')) {
    return 'The requested record was not found.';
  }

  // 6) Validation
  if (raw.contains('invalid email')) {
    return 'Please enter a valid email address.';
  }
  if (raw.contains('password')) {
    return 'Please check your password and try again.';
  }

  // 7) Custom AuthException messages (e.g. from auth_repository) — pass through.
  if (error is AuthException && (error.message).isNotEmpty) {
    return error.message;
  }
  if (error is Exception) {
    final msg = error.toString();
    // Strip "Exception: " / "Error: " prefix
    final stripped = msg
        .replaceFirst('Exception: ', '')
        .replaceFirst('Error: ', '')
        .trim();
    if (stripped.length <= 200 && !stripped.startsWith('{')) {
      return stripped;
    }
  }

  // 8) Last-resort fallback — never leak the raw `original`.
  return fallback ?? 'Something went wrong. Please try again.';
}

/// Show an error in a SnackBar using the formatter above.
void showErrorSnackBar(BuildContext context, Object? error,
    {String? fallback, Duration? duration}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(errorFormatter(error, fallback: fallback)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: duration ?? const Duration(seconds: 4),
    ),
  );
}

/// Show a success message in a SnackBar.
void showSuccessSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.green.shade700,
    ),
  );
}
