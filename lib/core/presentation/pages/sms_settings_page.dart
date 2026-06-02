// lib/core/presentation/pages/sms_settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_colors.dart';
import '../../providers/sms_config_provider.dart';
import '../../providers/sms_outbox_provider.dart';
import '../../providers/sms_provider.dart';
import '../../services/sms_service.dart';
import '../../widgets/glass_card.dart';

class SmsSettingsPage extends ConsumerStatefulWidget {
  const SmsSettingsPage({super.key});

  @override
  ConsumerState<SmsSettingsPage> createState() => _SmsSettingsPageState();
}

class _SmsSettingsPageState extends ConsumerState<SmsSettingsPage> {
  String? _testResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final config = ref.watch(smsConfigProvider);
    final configNotifier = ref.read(smsConfigProvider.notifier);
    final outboxAsync = ref.watch(smsOutboxProvider);
    final smsService = ref.read(smsServiceProvider);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white70 : Colors.black87),
        ),
        title: Text('SMS Settings',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPermissionCard(theme, isDark),
              const SizedBox(height: 24),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(theme, 'Auto-Send Settings', Icons.send_rounded),
                    const Divider(height: 1),
                    const SizedBox(height: 4),
                    _switchTile(
                      theme: theme,
                      title: 'SMS on Collection',
                      subtitle: 'Send receipt SMS after each collection',
                      icon: Icons.receipt_long_outlined,
                      value: config.smsOnCollection,
                      onChanged: (_) => configNotifier.toggleSmsOnCollection(),
                    ),
                    _switchTile(
                      theme: theme,
                      title: 'SMS on Savings Deposit',
                      subtitle: 'Send confirmation SMS after savings deposit',
                      icon: Icons.account_balance_wallet_outlined,
                      value: config.smsOnSavings,
                      onChanged: (_) => configNotifier.toggleSmsOnSavings(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(theme, 'SIM & Outbox', Icons.sim_card_outlined),
                    const Divider(height: 1),
                    const SizedBox(height: 4),
                    _infoTile(
                      theme: theme,
                      title: 'SMS SIM Slot',
                      subtitle: 'Tap to choose which SIM sends SMS',
                      icon: Icons.sim_card_outlined,
                      onTap: () => _pickSim(context, smsService),
                    ),
                    _infoTile(
                      theme: theme,
                      title: 'Send Test SMS',
                      subtitle: _testResult ?? 'Send a one-off test message to your own number',
                      icon: Icons.send_outlined,
                      onTap: () => _sendTest(context, smsService),
                    ),
                    _infoTile(
                      theme: theme,
                      title: 'Pending outbox',
                      subtitle: outboxAsync.when(
                        data: (o) {
                          final due = o.pendingDue().length;
                          return due == 0 ? 'No messages waiting' : '$due message(s) waiting to send';
                        },
                        loading: () => 'Loading…',
                        error: (_, __) => 'Outbox error',
                      ),
                      icon: Icons.outbox_outlined,
                      onTap: () async {
                        final o = await ref.read(smsOutboxProvider.future);
                        await ref.read(collectionSmsSenderProvider.notifier)
                            .flushOutbox(overrideOutbox: o);
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(theme, 'Auto-Reminders', Icons.notifications_active_rounded),
                    const Divider(height: 1),
                    const SizedBox(height: 4),
                    _switchTile(
                      theme: theme,
                      title: 'Due EMI Reminders',
                      subtitle: 'Auto-send reminders for due and overdue EMIs',
                      icon: Icons.alarm_outlined,
                      value: config.reminderEnabled,
                      onChanged: (_) => configNotifier.toggleReminder(),
                    ),
                    if (config.reminderEnabled) ...[
                      const SizedBox(height: 12),
                      _timePickerTile(
                        context: context,
                        theme: theme,
                        isDark: isDark,
                        time: config.reminderTime,
                        onChanged: (time) => configNotifier.setReminderTime(time),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(theme, 'SMS History', Icons.history_rounded),
                    const Divider(height: 1),
                    const SizedBox(height: 4),
                    _infoTile(
                      theme: theme,
                      title: 'View Sent SMS',
                      subtitle: 'See the last 200 messages with status',
                      icon: Icons.history_rounded,
                      onTap: () => context.push('/sms-history'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickSim(BuildContext context, SmsService svc) async {
    final subs = await svc.pickSubscription();
    if (!context.mounted) return;
    if (subs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This device has one SIM. Using it.')),
      );
      return;
    }
    final current = await svc.getSubscriptionId();
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: subs.map((s) {
            final selected = current == s.subscriptionId;
            return ListTile(
              leading: Icon(selected ? Icons.check_circle : Icons.sim_card),
              title: Text(s.displayName.isEmpty ? 'SIM ${s.simSlotIndex + 1}' : s.displayName),
              subtitle: Text(s.carrierName),
              onTap: () => Navigator.of(ctx).pop(s.subscriptionId),
            );
          }).toList(),
        ),
      ),
    );
    if (picked != null) {
      await svc.setSubscription(picked);
      if (mounted) setState(() {});
    }
  }

  Future<void> _sendTest(BuildContext context, SmsService svc) async {
    final controller = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Test SMS'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: '+91XXXXXXXXXX'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (phone == null || phone.isEmpty) return;
    final result = await svc.sendTestSms(phone: phone, message: 'MicroFlow test message.');
    if (!mounted) return;
    setState(() => _testResult = 'Last test: $result');
  }

  Widget _buildPermissionCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.sms_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SMS Ready',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                Text('SMS can be sent from this device (managed by native plugin)',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _switchTile({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _timePickerTile({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required String time,
    required ValueChanged<String> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final parts = time.split(':');
        final initialHour = int.tryParse(parts[0]) ?? 8;
        final initialMinute = int.tryParse(parts[1]) ?? 0;
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
        );
        if (picked != null) {
          onChanged('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.schedule_rounded, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reminder Time', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text('Send reminders at this time daily',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(time, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }
}
