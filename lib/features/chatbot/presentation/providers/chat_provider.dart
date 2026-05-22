import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../../data/models/chat_message.dart';
import '../../data/repositories/chatbot_repository.dart';
import '../../../../router/app_router.dart';
import '../../../../core/providers/branding_provider.dart';

final chatbotRepositoryProvider = Provider<ChatbotRepository>((ref) {
  return ChatbotRepository();
});

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isListening;
  final bool isSpeaking;
  final bool isContinuous; // New: Hands-free mode
  final String? error;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isListening = false,
    this.isSpeaking = false,
    this.isContinuous = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isListening,
    bool? isSpeaking,
    bool? isContinuous,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isListening: isListening ?? this.isListening,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isContinuous: isContinuous ?? this.isContinuous,
      error: error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final Ref _ref;

  ChatNotifier(this._ref) : super(ChatState()) {
    _initVoice();
  }

  Future<void> _initVoice() async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
  }

  Future<void> sendMessage(String text, {String? contextRoute}) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(text: text, role: MessageRole.user);
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
    );

    // Agentic Navigation Logic
    final t = text.toLowerCase();
    if (t.contains('go to') ||
        t.contains('navigate to') ||
        t.contains('open')) {
      bool navigated = false;
      if (t.contains('settings') || t.contains('admin')) {
        _ref.read(routerProvider).go('/settings');
        navigated = true;
      } else if (t.contains('analytics') || t.contains('dashboard')) {
        _ref.read(routerProvider).go('/analytics');
        navigated = true;
      } else if (t.contains('loans')) {
        _ref.read(routerProvider).go('/loans');
        navigated = true;
      } else if (t.contains('savings')) {
        _ref.read(routerProvider).go('/savings');
        navigated = true;
      } else if (t.contains('users') || t.contains('members')) {
        _ref.read(routerProvider).go('/users');
        navigated = true;
      }

      if (navigated) {
        state = state.copyWith(
          messages: [
            ...state.messages,
            ChatMessage(
                text: "Navigating there now.", role: MessageRole.assistant)
          ],
          isLoading: false,
        );
        return;
      }
    }

    try {
      final repository = _ref.read(chatbotRepositoryProvider);
      String fullContent = '';

      // Temporary message for streaming
      final assistantMessage = ChatMessage(
        text: '...',
        role: MessageRole.assistant,
      );
      state = state.copyWith(messages: [...state.messages, assistantMessage]);

      final branding = _ref.read(brandingProvider).valueOrNull;
      final orgName = branding?.displayName;

      // Context injection (business data, role scope) is handled server-side
      // by the chat-proxy edge function.
      final responseStream = repository.streamChatResponse(
        state.messages.sublist(0, state.messages.length - 1),
        orgName: orgName,
      );

      int lastSpokenIndex = 0;
      await for (final content in responseStream) {
        fullContent = content;

        // Update the last message in real-time
        final updatedMessages = List<ChatMessage>.from(state.messages);
        updatedMessages[updatedMessages.length - 1] =
            assistantMessage.copyWith(text: fullContent);
        state = state.copyWith(messages: updatedMessages);

        // Advanced: Sentence-by-sentence streaming TTS
        if (state.isContinuous) {
          final remainingText = fullContent.substring(lastSpokenIndex);
          // Look for sentence terminators (., !, ?)
          if (RegExp(r'[.!?]').hasMatch(remainingText)) {
            final sentences = remainingText.split(RegExp(r'(?<=[.!?])\s*'));
            for (int i = 0; i < sentences.length - 1; i++) {
              if (sentences[i].trim().isNotEmpty) {
                await speak(sentences[i].trim());
                lastSpokenIndex += sentences[i].length;
              }
            }
          }
        }
      }

      // Speak any remaining text at the end
      if (state.isContinuous && lastSpokenIndex < fullContent.length) {
        speak(fullContent.substring(lastSpokenIndex).trim());
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> startListening() async {
    // Advanced Gemini Feature: Interruption (Barge-in)
    if (state.isSpeaking) {
      await stopSpeaking(); // Immediately shut up if user starts talking
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          state = state.copyWith(isListening: false);
        }
      },
      onError: (errorNotification) {
        state = state.copyWith(
            isListening: false, error: errorNotification.errorMsg);
      },
    );

    if (available) {
      state = state.copyWith(isListening: true);
      _speech.listen(
        onResult: (result) {
          // Real-time Barge-in detection
          if (state.isSpeaking && result.recognizedWords.length > 3) {
            stopSpeaking();
          }

          if (result.finalResult) {
            sendMessage(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(
            seconds: 2), // Silence detection: Auto-send after 2s of silence
        listenOptions: stt.SpeechListenOptions(
          listenMode:
              stt.ListenMode.search, // Optimized for command/search intent
        ),
      );
    }
  }

  Future<void> stopListening() async {
    await _speech.stop();
    state = state.copyWith(isListening: false);
  }

  Future<void> speak(String text) async {
    state = state.copyWith(isSpeaking: true);

    // Detect language and set locale accordingly
    final locale = _detectLanguageCode(text);
    await _tts.setLanguage(locale);

    await _tts.speak(text);
    _tts.setCompletionHandler(() {
      state = state.copyWith(isSpeaking: false);

      // Auto-listen after speaking if in continuous mode
      if (state.isContinuous) {
        startListening();
      }
    });
  }

  void toggleContinuousMode() {
    final newValue = !state.isContinuous;
    state = state.copyWith(isContinuous: newValue);

    if (newValue) {
      startListening(); // Kick off the loop if enabling
    } else {
      stopListening();
      stopSpeaking();
    }
  }

  String _detectLanguageCode(String text) {
    // Simple script-based detection for Indian languages
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return 'hi-IN'; // Hindi
    if (RegExp(r'[\u0980-\u09FF]').hasMatch(text)) return 'bn-IN'; // Bengali
    if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(text)) return 'ta-IN'; // Tamil
    if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(text)) return 'te-IN'; // Telugu
    if (RegExp(r'[\u0C80-\u0CFF]').hasMatch(text)) return 'kn-IN'; // Kannada
    if (RegExp(r'[\u0D00-\u0D7F]').hasMatch(text)) return 'ml-IN'; // Malayalam
    if (RegExp(r'[\u0A00-\u0A7F]').hasMatch(text)) return 'pa-IN'; // Punjabi
    if (RegExp(r'[\u0AB0-\u0AFF]').hasMatch(text)) return 'gu-IN'; // Gujarati
    if (RegExp(r'[\u0B00-\u0B7F]').hasMatch(text)) return 'or-IN'; // Odia
    if (RegExp(r'[\u0D80-\u0DFF]').hasMatch(text)) return 'si-LK'; // Sinhala
    return 'en-US'; // Default
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    state = state.copyWith(isSpeaking: false);
  }

  void clearHistory() {
    state = ChatState();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
