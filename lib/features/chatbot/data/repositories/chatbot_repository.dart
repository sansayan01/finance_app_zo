import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/chat_message.dart';

class ChatbotRepository {
  final String _apiKey;
  final String _model;

  ChatbotRepository({required String apiKey, required String model})
      : _apiKey = apiKey,
        _model = model;

  Stream<String> streamChatResponse(List<ChatMessage> history,
      {String? contextRoute, String? businessContext, String? orgName}) async* {
    final messages = history.map((m) => m.toJson()).toList();

    final name = orgName ?? 'MicroFlow Pro';
    String systemContext =
        'You are the $name Assistant, a concise multilingual financial expert. '
        'If asked about your creation, state that you were created by Sayan Mondal (Charlie). '
        'Your answers MUST be direct, short (1-2 sentences), and informative. '
        'CRITICAL: DO NOT include internal thoughts or <thought> tags. Provide ONLY the final answer. '
        'If the user asks for a loan summary, use the [UI:LOAN_SUMMARY] tag.';

    if (contextRoute != null) {
      systemContext += ' \nPage Context: $contextRoute';
    }
    if (businessContext != null) {
      systemContext += ' \nLive Data: $businessContext';
    }

    final requestBody = {
      'model': _model,
      'messages': [
        {'role': 'system', 'content': systemContext},
        ...messages,
      ],
      'temperature': 0.5,
      'top_p': 0.7,
      'max_tokens': 1024,
      'stream': true,
    };

    final baseUrl = 'https://integrate.api.nvidia.com/v1/chat/completions';
    final url = kIsWeb
        ? 'https://corsproxy.io/?${Uri.encodeComponent(baseUrl)}'
        : baseUrl;

    try {
      final request = http.Request('POST', Uri.parse(url));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      });
      request.body = jsonEncode(requestBody);

      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        if (errorBody.contains('image') ||
            errorBody.contains('vision') ||
            errorBody.contains('image.png')) {
          yield 'Error: This model does not support image input. Please send text messages only.';
        } else {
          yield 'Error: ${response.statusCode}\nDetails: $errorBody';
        }
        return;
      }

      String fullResponse = '';
      bool isThinking = false;

      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (chunk.trim().isEmpty) continue;
        if (chunk.startsWith('data: ')) {
          final data = chunk.substring(6).trim();
          if (data == '[DONE]') break;
          try {
            final json = jsonDecode(data);
            final content = json['choices'][0]['delta']['content'] as String?;
            if (content != null) {
              fullResponse += content;

              // Filter logic for <think> blocks
              String filteredResponse = fullResponse;
              if (filteredResponse.contains('<think>')) {
                isThinking = true;
                final parts = filteredResponse.split('</think>');
                if (parts.length > 1) {
                  isThinking = false;
                  filteredResponse = parts.last.trim();
                } else {
                  filteredResponse = ''; // Still thinking, show nothing yet
                }
              }

              if (!isThinking && filteredResponse.isNotEmpty) {
                yield filteredResponse;
              }
            }
          } catch (_) {}
        }
      }
      client.close();
    } catch (e) {
      yield 'Failed to connect: $e';
    }
  }
}
