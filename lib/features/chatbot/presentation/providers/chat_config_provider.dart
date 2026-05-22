import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-facing chatbot configuration.
/// API key and model are managed server-side by super admin.
/// Users only control whether the chatbot is visible.
class ChatConfig {
  final bool chatbotEnabled;

  ChatConfig({this.chatbotEnabled = true});

  ChatConfig copyWith({bool? chatbotEnabled}) {
    return ChatConfig(
      chatbotEnabled: chatbotEnabled ?? this.chatbotEnabled,
    );
  }
}

class ChatConfigNotifier extends StateNotifier<ChatConfig> {
  static const _enabledKey = 'chatbot_enabled';

  ChatConfigNotifier() : super(ChatConfig(chatbotEnabled: true)) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to true (enabled) if no value is stored
    final enabled = prefs.getBool(_enabledKey);
    state = ChatConfig(chatbotEnabled: enabled ?? true);
  }

  Future<void> toggleChatbot() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !state.chatbotEnabled;
    await prefs.setBool(_enabledKey, newValue);
    state = ChatConfig(chatbotEnabled: newValue);
  }
}

final chatConfigProvider =
    StateNotifierProvider<ChatConfigNotifier, ChatConfig>((ref) {
  return ChatConfigNotifier();
});
