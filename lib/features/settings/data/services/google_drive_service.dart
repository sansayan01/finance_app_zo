import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/env_config.dart';
import '../../../../core/utils/url_utils.dart';

/// Persistent Drive connection state stored in `organizations.settings`.
class DriveConnectionState {
  final bool connected;
  final String? email;
  final String? refreshToken;
  final String? folderId;
  final String? connectedAt;

  const DriveConnectionState({
    this.connected = false,
    this.email,
    this.refreshToken,
    this.folderId,
    this.connectedAt,
  });

  factory DriveConnectionState.fromJson(Map<String, dynamic> json) {
    return DriveConnectionState(
      connected: json['connected'] as bool? ?? false,
      email: json['email'] as String?,
      refreshToken: json['refresh_token'] as String?,
      folderId: json['folder_id'] as String?,
      connectedAt: json['connected_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'connected': connected,
        if (email != null) 'email': email,
        if (refreshToken != null) 'refresh_token': refreshToken,
        if (folderId != null) 'folder_id': folderId,
        if (connectedAt != null) 'connected_at': connectedAt,
      };
}

/// Service for Google Drive OAuth + file upload.
///
/// On **mobile** (Android/iOS): uses the `google_sign_in` plugin.
/// On **web**: uses a direct OAuth redirect flow via `url_launcher`
/// because the plugin's `signIn()` method is deprecated and broken on web.
class GoogleDriveService {
  final SupabaseClient _client;
  GoogleDriveService(this._client);

  // ── Scopes ────────────────────────────────────────────────────────────

  static const _scopes = ['https://www.googleapis.com/auth/drive.file'];

  // ── Mobile: GoogleSignIn plugin ────────────────────────────────────────

  GoogleSignIn get _googleSignIn => GoogleSignIn(
        scopes: _scopes,
        clientId: null, // Android/iOS reads from native config
        serverClientId: EnvConfig.googleWebClientId,
      );

  // ── Web: OAuth redirect URI ───────────────────────────────────────────

  static String get _webRedirectUri {
    // Use configured URI if set, otherwise fall back to current origin
    final configured = EnvConfig.googleRedirectUri;
    if (configured.isNotEmpty) return configured;
    return '${Uri.base.origin}/';
  }

  // ── signIn (platform-aware) ───────────────────────────────────────────

  Future<DriveConnectionState> signIn(String orgId) async {
    if (kIsWeb) {
      return _signInWeb(orgId);
    }
    return _signInMobile(orgId);
  }

  // ── Web: Direct OAuth redirect flow ───────────────────────────────────

  Future<DriveConnectionState> _signInWeb(String orgId) async {
    // 1. Build the Google OAuth URL
    final clientId = EnvConfig.googleWebClientId;
    if (clientId.isEmpty) {
      throw Exception('GOOGLE_WEB_CLIENT_ID is not configured in .env');
    }

    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': _webRedirectUri,
      'response_type': 'code',
      'scope': _scopes.join(' '),
      'access_type': 'offline', // Ensures we get a refresh_token
      'prompt': 'consent', // Force consent to always get refresh_token
    });

    debugPrint('GoogleDriveService [web]: opening OAuth URL...');
    debugPrint('Redirect URI: $_webRedirectUri');

    // 2. Open Google OAuth in new tab
    await launchUrl(authUrl, mode: LaunchMode.platformDefault);

    // 3. The user authorizes → Google redirects back with ?code=...
    // 4. On next app load, checkForRedirectCode() picks up the code
    //    and completes the connection. We return a placeholder here.
    throw Exception('__PENDING_REDIRECT__');
  }

  /// Called on app startup to check if we came back from Google OAuth redirect.
  /// Returns true if a pending redirect was handled.
  Future<bool> checkForRedirectCode(String orgId) async {
    if (!kIsWeb) return false;

    final code = Uri.base.queryParameters['code'];
    if (code == null || code.isEmpty) return false;

    debugPrint('GoogleDriveService [web]: found redirect code, exchanging...');

    try {
      // 5. Exchange auth code for tokens (with redirect_uri for web)
      final tokenResponse = await _exchangeCodeForTokens(code, redirectUri: _webRedirectUri);
      final refreshToken = tokenResponse['refresh_token'] as String?;
      final accessToken = tokenResponse['access_token'] as String?;

      if (refreshToken == null && accessToken == null) {
        throw Exception('No tokens received from Google');
      }

      // 6. Get user email from the access token
      String email = 'unknown@gmail.com';
      if (accessToken != null) {
        try {
          final userInfoResp = await http.get(
            Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
            headers: {'Authorization': 'Bearer $accessToken'},
          );
          if (userInfoResp.statusCode == 200) {
            final userInfo = jsonDecode(userInfoResp.body) as Map<String, dynamic>;
            email = userInfo['email'] as String? ?? email;
          }
        } catch (_) {}
      }

      // 7. Create or find backup folder
      final effectiveAccessToken = accessToken ??
          await _getAccessTokenFromRefresh(refreshToken!);
      final folderId = await _createOrGetBackupFolder(effectiveAccessToken, orgId);

      // 8. Persist to org settings
      final state = DriveConnectionState(
        connected: true,
        email: email,
        refreshToken: refreshToken,
        folderId: folderId,
        connectedAt: DateTime.now().toIso8601String(),
      );
      await _persistConnectionState(orgId, state);

      // 9. Clear the URL params so we don't re-process on next load
      _clearUrlParams();

      debugPrint('GoogleDriveService [web]: connected as $email');
      return true;
    } catch (e) {
      debugPrint('GoogleDriveService [web]: redirect handling failed: $e');
      _clearUrlParams();
      return false;
    }
  }

  void _clearUrlParams() {
    // Remove ?code=... from the URL without reloading
    if (kIsWeb) {
      try {
        final url = Uri.base;
        if (url.queryParameters.containsKey('code')) {
          final cleanUrl = url.replace(queryParameters: {});
          // Use history.replaceState to clean the URL
          // This is a web-only API call
          _replaceUrl(cleanUrl.toString());
        }
      } catch (_) {}
    }
  }

  // ── Mobile: google_sign_in plugin ─────────────────────────────────────

  Future<DriveConnectionState> _signInMobile(String orgId) async {
    debugPrint('GoogleDriveService [mobile]: calling _googleSignIn.signIn()...');
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Google Sign-In was cancelled.');
    debugPrint('GoogleDriveService [mobile]: account: ${account.email}');

    final serverAuthCode = account.serverAuthCode;
    if (serverAuthCode == null || serverAuthCode.isEmpty) {
      throw Exception('No server auth code received.');
    }
    debugPrint('GoogleDriveService [mobile]: exchanging auth code...');

    final tokenResponse = await _exchangeCodeForTokens(serverAuthCode);
    final refreshToken = tokenResponse['refresh_token'] as String?;

    final accessToken = await _getAccessTokenFromRefresh(refreshToken ?? '');
    final folderId = await _createOrGetBackupFolder(accessToken, orgId);

    final state = DriveConnectionState(
      connected: true,
      email: account.email,
      refreshToken: refreshToken,
      folderId: folderId,
      connectedAt: DateTime.now().toIso8601String(),
    );
    await _persistConnectionState(orgId, state);

    return state;
  }

  // ── Disconnect ────────────────────────────────────────────────────────

  Future<void> signOut(String orgId) async {
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
    await _persistConnectionState(orgId, const DriveConnectionState());
  }

  // ── Token Management ──────────────────────────────────────────────────

  Future<String> getAccessToken(DriveConnectionState connection) async {
    if (connection.refreshToken != null) {
      return _getAccessTokenFromRefresh(connection.refreshToken!);
    }
    throw Exception('No refresh token. Please reconnect Google Drive.');
  }

  Future<String> _getAccessTokenFromRefresh(String refreshToken) async {
    final response = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      body: {
        'client_id': EnvConfig.googleWebClientId,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to refresh access token: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['access_token'] as String;
  }

  Future<Map<String, dynamic>> _exchangeCodeForTokens(
    String authCode, {
    String? redirectUri,
  }) async {
    final body = <String, String>{
      'code': authCode,
      'client_id': EnvConfig.googleWebClientId,
      'grant_type': 'authorization_code',
    };
    if (redirectUri != null) body['redirect_uri'] = redirectUri;

    final response = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Token exchange failed: ${response.statusCode} ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Drive API ─────────────────────────────────────────────────────────

  Future<String> _createOrGetBackupFolder(String accessToken, String orgId) async {
    const folderName = 'MicroFlow Pro Backups';

    final searchResp = await http.get(
      Uri.parse(
        'https://www.googleapis.com/drive/v3/files'
        '?q=name%3D%27${Uri.encodeComponent(folderName)}%27'
        '%20and%20mimeType%3D%27application%2Fvnd.google-apps.folder%27'
        '%20and%20trashed%3Dfalse'
        '&fields=files(id,name)',
      ),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (searchResp.statusCode == 200) {
      final data = jsonDecode(searchResp.body) as Map<String, dynamic>;
      final files = data['files'] as List<dynamic>?;
      if (files != null && files.isNotEmpty) {
        return files.first['id'] as String;
      }
    }

    final createResp = await http.post(
      Uri.parse('https://www.googleapis.com/drive/v3/files'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': folderName,
        'mimeType': 'application/vnd.google-apps.folder',
      }),
    );

    if (createResp.statusCode != 200) {
      throw Exception('Failed to create backup folder: ${createResp.statusCode}');
    }

    final data = jsonDecode(createResp.body) as Map<String, dynamic>;
    return data['id'] as String;
  }

  Future<Map<String, dynamic>> uploadJsonBackup({
    required DriveConnectionState connection,
    required String orgName,
    required Map<String, dynamic> jsonData,
  }) async {
    final accessToken = await getAccessToken(connection);
    final folderId = connection.folderId;
    if (folderId == null) throw Exception('No backup folder configured.');

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final safeOrgName = orgName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = '${safeOrgName}_backup_$timestamp.json';
    final jsonBytes = utf8.encode(jsonEncode(jsonData));

    final uri = Uri.parse(
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
    );

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken';

    request.fields[''] = '';
    request.files.add(http.MultipartFile.fromBytes(
      'metadata',
      utf8.encode(jsonEncode({
        'name': fileName,
        'parents': [folderId],
        'mimeType': 'application/json',
      })),
    ));

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      jsonBytes,
      filename: fileName,
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode} ${response.body}');
    }

    final result = jsonDecode(response.body) as Map<String, dynamic>;
    return {
      'file_id': result['id'] as String,
      'file_name': fileName,
      'file_size': _formatBytes(jsonBytes.length),
      'file_size_bytes': jsonBytes.length,
      'drive_url': 'https://drive.google.com/file/d/${result['id']}/view',
    };
  }

  Future<List<Map<String, dynamic>>> listBackups(
    DriveConnectionState connection,
  ) async {
    if (connection.folderId == null || connection.refreshToken == null) {
      return const [];
    }

    try {
      final accessToken = await getAccessToken(connection);
      final resp = await http.get(
        Uri.parse(
          'https://www.googleapis.com/drive/v3/files'
          '?q=${Uri.encodeComponent("'${connection.folderId}' in parents and trashed=false")}'
          '&fields=files(id,name,size,createdTime,mimeType)'
          '&orderBy=createdTime%20desc'
          '&pageSize=20',
        ),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (resp.statusCode != 200) return const [];

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final files = data['files'] as List<dynamic>? ?? [];
      return files.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('listBackups error: $e');
      return const [];
    }
  }

  // ── Org Settings Persistence ──────────────────────────────────────────

  Future<DriveConnectionState> getConnectionState(String orgId) async {
    try {
      final result = await _client
          .from('organizations')
          .select('settings')
          .eq('id', orgId)
          .maybeSingle();

      final settings = result?['settings'] as Map<String, dynamic>? ?? {};
      final driveData = settings['google_drive'] as Map<String, dynamic>?;
      if (driveData == null) return const DriveConnectionState();
      return DriveConnectionState.fromJson(driveData);
    } catch (e) {
      debugPrint('getConnectionState error: $e');
      return const DriveConnectionState();
    }
  }

  Future<void> _persistConnectionState(
    String orgId,
    DriveConnectionState state,
  ) async {
    try {
      final result = await _client
          .from('organizations')
          .select('settings')
          .eq('id', orgId)
          .maybeSingle();

      final currentSettings = Map<String, dynamic>.from(
        (result?['settings'] as Map<String, dynamic>?) ?? {},
      );
      currentSettings['google_drive'] = state.toJson();

      await _client
          .from('organizations')
          .update({
            'settings': currentSettings,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orgId);
    } catch (e) {
      debugPrint('persistConnectionState error: $e');
      throw Exception('Failed to save Drive connection: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Replace URL without reload to clear OAuth params (web) or no-op (mobile).
void _replaceUrl(String url) => replaceUrl(url);
