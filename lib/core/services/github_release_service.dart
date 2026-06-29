import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env_config.dart';
import '../models/github_release.dart';

/// Service that fetches the latest release info from GitHub.
///
/// Used by the in-app update system to check for new versions.
/// Returns null on any error (network, rate limit, 404, etc.)
/// so the caller can fall back gracefully.
class GitHubReleaseService {
  final Dio _dio;

  GitHubReleaseService({Dio? dio}) : _dio = dio ?? Dio();

  /// Fetches the latest release from the GitHub repository.
  ///
  /// Makes a single GET request to the GitHub Releases API.
  /// - For public repos: works without authentication (60 req/hr limit).
  /// - For private repos: requires a valid token via [EnvConfig.githubToken].
  ///
  /// Returns `null` on any error — the caller should treat this as
  /// "no update information available" and fall back gracefully.
  Future<GitHubRelease?> fetchLatestRelease() async {
    try {
      final headers = <String, String>{
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

      final token = EnvConfig.githubToken;
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _dio
          .get(
            'https://api.github.com/repos/sansayan01/finance_app_zo/releases/latest',
            options: Options(headers: headers),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.data is Map) {
        final release =
            GitHubRelease.fromJson(response.data as Map<String, dynamic>);
        debugPrint('✅ GitHub release: ${release.tagName}');
        return release;
      }

      debugPrint('⚠️ GitHub API unexpected status: ${response.statusCode}');
      return null;
    } on TimeoutException {
      debugPrint('⚠️ GitHub release check timed out');
      return null;
    } on DioException catch (e) {
      debugPrint('⚠️ GitHub release check failed: ${e.type} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('⚠️ GitHub release check error: $e');
      return null;
    }
  }

  /// Builds the authorization headers needed for downloading from GitHub.
  ///
  /// For public repos, this returns empty headers (no auth needed).
  /// For private repos, includes the Bearer token.
  Map<String, String> get downloadHeaders {
    final token = EnvConfig.githubToken;
    if (token.isNotEmpty) {
      return {'Authorization': 'Bearer $token'};
    }
    return {};
  }
}

/// Singleton — no state to manage, just HTTP calls.
final githubReleaseServiceProvider = Provider<GitHubReleaseService>((ref) {
  return GitHubReleaseService();
});
