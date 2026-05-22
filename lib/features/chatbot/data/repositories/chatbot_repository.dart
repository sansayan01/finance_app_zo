import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';
import '../../../../core/config/env_config.dart';

/// Calls the Supabase edge function which proxies to NVIDIA NIM.
/// API key and model are managed server-side by the super admin.
class ChatbotRepository {
  final SupabaseClient _supabase;

  ChatbotRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Stream<String> streamChatResponse(List<ChatMessage> history,
      {String? orgName}) async* {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      yield* Stream.error('Not authenticated. Please log in again.');
      return;
    }

    final messages = history.map((m) => m.toJson()).toList();

    final url = '${EnvConfig.supabaseUrl}/functions/v1/chat-proxy';

    try {
      final request = http.Request('POST', Uri.parse(url));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
        'apikey': EnvConfig.supabaseAnonKey,
      });
      request.body = jsonEncode({
        'messages': messages,
        if (orgName != null) 'orgName': orgName,
      });

      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        String errorMessage;
        try {
          final json = jsonDecode(body);
          errorMessage = json['error'] ?? 'AI service error';
        } catch (_) {
          errorMessage = 'AI service returned ${response.statusCode}';
        }
        yield* Stream.error(errorMessage);
        return;
      }

      // Stream SSE response from edge function
      String buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast(); // Keep incomplete line in buffer

        for (final line in lines) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('data:')) continue;
          final data = trimmed.substring(5).trim();
          if (data == '[DONE]') return;
          if (data.isEmpty) continue;

          try {
            final json = jsonDecode(data);
            final choices = json['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'];
              if (delta != null && delta['content'] != null) {
                yield delta['content'] as String;
              }
            }
          } catch (_) {
            // Skip malformed JSON chunks
          }
        }
      }
    } catch (e) {
      if (e is http.ClientException) {
        yield* Stream.error(
            'Connection failed. Check your internet and try again.');
      } else {
        yield* Stream.error('Unexpected error: ${e.toString()}');
      }
    }
  }
}
