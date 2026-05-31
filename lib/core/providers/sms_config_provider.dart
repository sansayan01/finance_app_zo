import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_providers.dart';

class SmsConfig {
  final bool smsOnCollection;
  final bool smsOnSavings;
  final bool reminderEnabled;
  final String reminderTime;

  const SmsConfig({
    this.smsOnCollection = true,
    this.smsOnSavings = true,
    this.reminderEnabled = false,
    this.reminderTime = '08:00',
  });

  SmsConfig copyWith({
    bool? smsOnCollection,
    bool? smsOnSavings,
    bool? reminderEnabled,
    String? reminderTime,
  }) {
    return SmsConfig(
      smsOnCollection: smsOnCollection ?? this.smsOnCollection,
      smsOnSavings: smsOnSavings ?? this.smsOnSavings,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'sms_on_collection': smsOnCollection,
        'sms_on_savings': smsOnSavings,
        'sms_reminder_enabled': reminderEnabled,
        'sms_reminder_time': reminderTime,
      };

  factory SmsConfig.fromPrefs(SharedPreferences prefs) {
    return SmsConfig(
      smsOnCollection: prefs.getBool('sms_on_collection') ?? true,
      smsOnSavings: prefs.getBool('sms_on_savings') ?? true,
      reminderEnabled: prefs.getBool('sms_reminder_enabled') ?? false,
      reminderTime: prefs.getString('sms_reminder_time') ?? '08:00',
    );
  }
}

class SmsConfigNotifier extends StateNotifier<SmsConfig> {
  final SharedPreferences _prefs;

  SmsConfigNotifier(this._prefs) : super(SmsConfig.fromPrefs(_prefs));

  Future<void> toggleSmsOnCollection() async {
    final val = !state.smsOnCollection;
    await _prefs.setBool('sms_on_collection', val);
    state = state.copyWith(smsOnCollection: val);
  }

  Future<void> toggleSmsOnSavings() async {
    final val = !state.smsOnSavings;
    await _prefs.setBool('sms_on_savings', val);
    state = state.copyWith(smsOnSavings: val);
  }

  Future<void> toggleReminder() async {
    final val = !state.reminderEnabled;
    await _prefs.setBool('sms_reminder_enabled', val);
    state = state.copyWith(reminderEnabled: val);
  }

  Future<void> setReminderTime(String time) async {
    await _prefs.setString('sms_reminder_time', time);
    state = state.copyWith(reminderTime: time);
  }
}

final smsConfigProvider =
    StateNotifierProvider<SmsConfigNotifier, SmsConfig>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SmsConfigNotifier(prefs);
});
