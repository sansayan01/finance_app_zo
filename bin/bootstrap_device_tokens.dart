// =============================================================================
// One-time schema bootstrap for FCM push notifications (Dart-only, no SQL files)
// =============================================================================
//
// This replaces the Supabase SQL migration files for the `device_tokens` table.
// Run it ONCE after creating your Supabase project:
//
//   1. Put your DIRECT Postgres connection string in `.env` as:
//        SUPABASE_DB_URL=postgresql://postgres:<password>@db.<ref>.supabase.co:5432/postgres
//      (Use the "Connection string" > "URI" from Supabase Dashboard > Settings > Database)
//
//   2. Run:
//        dart run bin/bootstrap_device_tokens.dart
//
// The script is idempotent (CREATE TABLE IF NOT EXISTS / CREATE POLICY IF NOT EXISTS
// is handled by dropping/recreating policies safely). It only needs to run once;
// after that the schema lives in your database like any migration would.
//
// If you prefer not to run Dart, the same SQL is printed by this script and can
// be pasted directly into the Supabase SQL Editor.
// =============================================================================

import 'dart:io';
// ignore_for_file: depend_on_referenced_packages
import 'package:postgres/postgres.dart';

const String _sql = '''
-- Device tokens table for FCM push notifications
CREATE TABLE IF NOT EXISTS device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'android',
  device_info JSONB,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, fcm_token)
);

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (idempotent) then recreate
DROP POLICY IF EXISTS "Users can manage their own tokens" ON device_tokens;
DROP POLICY IF EXISTS "Service role can manage all tokens" ON device_tokens;
DROP POLICY IF EXISTS "Org admins can view org tokens" ON device_tokens;

CREATE POLICY "Users can manage their own tokens"
  ON device_tokens FOR ALL
  USING (user_id = auth.uid());

CREATE POLICY "Service role can manage all tokens"
  ON device_tokens FOR ALL
  USING (auth.role() = 'service_role');

CREATE POLICY "Org admins can view org tokens"
  ON device_tokens FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM profiles
      WHERE user_id = auth.uid()
      AND role IN ('superAdmin', 'executiveAdmin', 'manager')
    )
  );

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_org_id ON device_tokens(org_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_active ON device_tokens(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_device_tokens_fcm ON device_tokens(fcm_token);

-- Function to clean up inactive/expired tokens
CREATE OR REPLACE FUNCTION cleanup_inactive_tokens()
RETURNS void AS \$\$
BEGIN
  DELETE FROM device_tokens
  WHERE is_active = false
     OR updated_at < now() - interval '90 days';
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark a token as inactive (called when FCM returns an error)
CREATE OR REPLACE FUNCTION deactivate_device_token(token_fcm TEXT)
RETURNS void AS \$\$
BEGIN
  UPDATE device_tokens
  SET is_active = false, updated_at = now()
  WHERE fcm_token = token_fcm;
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION cleanup_inactive_tokens() TO service_role;
GRANT EXECUTE ON FUNCTION deactivate_device_token(TEXT) TO service_role;
''';

String? _readDbUrl() {
  final fromEnv = Platform.environment['SUPABASE_DB_URL'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

  // Fallback: parse .env file in project root
  final envFile = File('.env');
  if (envFile.existsSync()) {
    for (final line in envFile.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.startsWith('SUPABASE_DB_URL=')) {
        return trimmed.substring('SUPABASE_DB_URL='.length).trim();
      }
    }
  }
  return null;
}

Future<void> main() async {
  final dbUrl = _readDbUrl();
  if (dbUrl == null || dbUrl.isEmpty) {
    stderr.writeln(
      'ERROR: SUPABASE_DB_URL not found.\n'
      'Set it in your environment or in .env:\n'
      '  SUPABASE_DB_URL=postgresql://postgres:***@db.<ref>.supabase.co:5432/postgres',
    );
    // Print the SQL so it can be run manually in the Supabase SQL Editor.
    stdout.writeln('\n--- SQL TO RUN MANUALLY IN SUPABASE SQL EDITOR ---\n');
    stdout.writeln(_sql);
    exit(1);
  }

  final connection = await Connection.openFromUrl(dbUrl);

  try {
    await connection.execute(_sql);
    stdout.writeln('✅ device_tokens schema bootstrapped successfully.');
  } finally {
    await connection.close();
  }
}
