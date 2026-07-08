import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../payments/data/providers/upi_providers.dart';
import '../../../payments/data/services/upi_service.dart';
import '../../data/providers/integrations_providers.dart';
import '../../data/providers/payment_gateway_providers.dart';

class IntegrationsSettingsPage extends ConsumerStatefulWidget {
const IntegrationsSettingsPage({super.key});

@override
ConsumerState<IntegrationsSettingsPage> createState() =>
_IntegrationsSettingsPageState();
}

class _IntegrationsSettingsPageState
extends ConsumerState<IntegrationsSettingsPage> with SingleTickerProviderStateMixin {
late TabController _tabController;

// ─── UPI State ─────────────────────────────────────────────────
final _upiVpaCtrl = TextEditingController();
final _upiMerchantCtrl = TextEditingController();
bool _savingUpi = false;
bool _loadingUpiConfig = true;

// ─── Email State ───────────────────────────────────────────────
String _emailProvider = 'none'; // none | smtp | resend
final _smtpHostCtrl = TextEditingController();
final _smtpPortCtrl = TextEditingController(text: '465');
final _smtpUserCtrl = TextEditingController();
final _smtpPassCtrl = TextEditingController();
final _resendKeyCtrl = TextEditingController();
final _fromEmailCtrl = TextEditingController();
final _fromNameCtrl = TextEditingController();
final _testEmailCtrl = TextEditingController();
bool _savingEmail = false;
bool _sendingTest = false;
bool _loadingEmail = true;

// ─── WhatsApp State ────────────────────────────────────────────
final _waPhoneIdCtrl = TextEditingController();
final _waBizIdCtrl = TextEditingController();
final _waTokenCtrl = TextEditingController();
final _waTestPhoneCtrl = TextEditingController();
bool _savingWhatsApp = false;
bool _sendingWaTest = false;
bool _loadingWhatsApp = true;

// ─── Payment Gateway State ────────────────────────────────────
String _razorpayEnabled = 'false';
String _razorpayKey = '';
String _razorpaySecret = '';
String _razorpayWebhookSecret = '';
String _phonepeEnabled = 'false';
String _phonepeMerchantId = '';
String _phonepeSaltKey = '';
String _phonepeSaltIndex = '1';
bool _savingGateway = false;
bool _loadingGateway = true;

final _razorpayKeyCtrl = TextEditingController();
final _razorpaySecretCtrl = TextEditingController();
final _razorpayWebhookCtrl = TextEditingController();
final _phonepeMerchantCtrl = TextEditingController();
final _phonepeSaltCtrl = TextEditingController();

@override
void initState() {
super.initState();
_tabController = TabController(length: 2, vsync: this);
_loadUpiConfig();
_loadEmailConfig();
_loadWhatsAppConfig();
_loadGatewayConfig();
}

@override
void dispose() {
_tabController.dispose();
_upiVpaCtrl.dispose();
_upiMerchantCtrl.dispose();
_smtpHostCtrl.dispose();
_smtpPortCtrl.dispose();
_smtpUserCtrl.dispose();
_smtpPassCtrl.dispose();
_resendKeyCtrl.dispose();
_fromEmailCtrl.dispose();
_fromNameCtrl.dispose();
_testEmailCtrl.dispose();
_waPhoneIdCtrl.dispose();
_waBizIdCtrl.dispose();
_waTokenCtrl.dispose();
_waTestPhoneCtrl.dispose();
_razorpayKeyCtrl.dispose();
_razorpaySecretCtrl.dispose();
_razorpayWebhookCtrl.dispose();
_phonepeMerchantCtrl.dispose();
_phonepeSaltCtrl.dispose();
super.dispose();
}

// ────────────────────────────────────────────────────────────────
// UPI
// ────────────────────────────────────────────────────────────────

Future<void> _loadUpiConfig() async {
try {
final config = await ref.read(upiServiceProvider).getOrgVpa();
if (!mounted) return;
setState(() {
_upiVpaCtrl.text = config?['upi_vpa'] as String? ?? '';
_upiMerchantCtrl.text = config?['merchant_name'] as String? ?? '';
_loadingUpiConfig = false;
});
} catch (_) {
if (!mounted) return;
setState(() => _loadingUpiConfig = false);
}
}

Future<void> _saveUpi() async {
final vpa = _upiVpaCtrl.text.trim();
final merchant = _upiMerchantCtrl.text.trim();
if (vpa.isEmpty && merchant.isEmpty) {
_showSnack('Enter VPA and merchant name to configure UPI.');
return;
}
if (vpa.isNotEmpty && !UpiService.isValidVpa(vpa)) {
_showSnack('Invalid VPA. It must contain an "@" symbol.', isError: true);
return;
}
setState(() => _savingUpi = true);
try {
await ref.read(upiServiceProvider).saveOrgVpa(vpa: vpa, merchantName: merchant);
if (!mounted) return;
_showSnack('UPI payment configuration saved', isSuccess: true);
} catch (e) {
if (!mounted) return;
_showSnack('Failed to save UPI config: $e', isError: true);
} finally {
if (mounted) setState(() => _savingUpi = false);
}
}

// ────────────────────────────────────────────────────────────────
// Email
// ────────────────────────────────────────────────────────────────

Future<void> _loadEmailConfig() async {
try {
final emailSvc = ref.read(emailSettingsServiceProvider);
final config = await emailSvc.getCommunications();
if (!mounted) return;
setState(() {
_emailProvider = config['provider'] as String? ?? 'none';
_smtpHostCtrl.text = config['smtp_host'] as String? ?? '';
_smtpPortCtrl.text = '${(config['smtp_port'] as int? ?? 465)}';
_smtpUserCtrl.text = config['smtp_username'] as String? ?? '';
_smtpPassCtrl.text = config['smtp_password'] as String? ?? '';
_resendKeyCtrl.text = config['api_key'] as String? ?? '';
_fromEmailCtrl.text = config['from_email'] as String? ?? '';
_fromNameCtrl.text = config['from_name'] as String? ?? '';
_loadingEmail = false;
});
} catch (_) {
if (!mounted) return;
setState(() => _loadingEmail = false);
}
}

Future<void> _saveEmail() async {
setState(() => _savingEmail = true);
try {
await ref.read(emailSettingsServiceProvider).saveCommunications(
provider: _emailProvider,
smtpHost: _smtpHostCtrl.text.trim().isEmpty ? null : _smtpHostCtrl.text.trim(),
smtpPort: int.tryParse(_smtpPortCtrl.text.trim()),
smtpUsername: _smtpUserCtrl.text.trim().isEmpty ? null : _smtpUserCtrl.text.trim(),
smtpPassword: _smtpPassCtrl.text.trim().isEmpty ? null : _smtpPassCtrl.text.trim(),
apiKey: _resendKeyCtrl.text.trim().isEmpty ? null : _resendKeyCtrl.text.trim(),
fromEmail: _fromEmailCtrl.text.trim().isEmpty ? null : _fromEmailCtrl.text.trim(),
fromName: _fromNameCtrl.text.trim().isEmpty ? null : _fromNameCtrl.text.trim(),
);
if (!mounted) return;
_showSnack('Email configuration saved', isSuccess: true);
} catch (e) {
if (!mounted) return;
_showSnack('Failed to save email config: $e', isError: true);
} finally {
if (mounted) setState(() => _savingEmail = false);
}
}

Future<void> _sendTestEmail() async {
final to = _testEmailCtrl.text.trim();
if (to.isEmpty) {
_showSnack('Enter an email address to test.', isError: true);
return;
}
setState(() => _sendingTest = true);
try {
final ok = await ref.read(emailSettingsServiceProvider).sendTestEmail(to);
if (!mounted) return;
if (ok) {
_showSnack('Test email sent successfully to $to', isSuccess: true);
} else {
_showSnack('Failed to send test email. Check your configuration.', isError: true);
}
} catch (_) {
if (!mounted) return;
_showSnack('Failed to send test email.', isError: true);
} finally {
if (mounted) setState(() => _sendingTest = false);
}
}

// ────────────────────────────────────────────────────────────────
// WhatsApp
// ────────────────────────────────────────────────────────────────

Future<void> _loadWhatsAppConfig() async {
try {
final waSvc = ref.read(whatsAppServiceProvider);
final config = await waSvc.getWhatsAppConfig();
if (!mounted) return;
setState(() {
_waPhoneIdCtrl.text = config['phone_number_id'] as String? ?? '';
_waBizIdCtrl.text = config['business_account_id'] as String? ?? '';
_waTokenCtrl.text = config['access_token'] as String? ?? '';
_loadingWhatsApp = false;
});
} catch (_) {
if (!mounted) return;
setState(() => _loadingWhatsApp = false);
}
}

Future<void> _saveWhatsApp() async {
setState(() => _savingWhatsApp = true);
try {
await ref.read(whatsAppServiceProvider).saveWhatsAppConfig(
phoneNumberId: _waPhoneIdCtrl.text.trim(),
businessAccountId: _waBizIdCtrl.text.trim(),
accessToken: _waTokenCtrl.text.trim(),
);
if (!mounted) return;
_showSnack('WhatsApp Business API configuration saved', isSuccess: true);
} catch (e) {
if (!mounted) return;
_showSnack('Failed to save WhatsApp config: $e', isError: true);
} finally {
if (mounted) setState(() => _savingWhatsApp = false);
}
}

Future<void> _sendWaTest() async {
final to = _waTestPhoneCtrl.text.trim();
if (to.isEmpty) {
_showSnack('Enter a phone number (with country code, e.g. +919876543210).', isError: true);
return;
}
setState(() => _sendingWaTest = true);
try {
final ok = await ref.read(whatsAppServiceProvider).sendTestMessage(to);
if (!mounted) return;
if (ok) {
_showSnack('Test WhatsApp message sent to $to', isSuccess: true);
} else {
_showSnack('Failed to send test WhatsApp message. Check your configuration.', isError: true);
}
} catch (_) {
if (!mounted) return;
_showSnack('Failed to send test WhatsApp message.', isError: true);
} finally {
if (mounted) setState(() => _sendingWaTest = false);
}
}

// ────────────────────────────────────────────────────────────────
// Payment Gateway
// ────────────────────────────────────────────────────────────────

Future<void> _loadGatewayConfig() async {
try {
final config = await ref.read(paymentGatewayServiceProvider).getGatewayConfig();
if (!mounted) return;
setState(() {
_razorpayEnabled = config['razorpay'] != null ? 'true' : 'false';
if (config['razorpay'] != null) {
final rz = config['razorpay'] as Map<String, dynamic>;
_razorpayKey = rz['api_key'] as String? ?? '';
_razorpaySecret = rz['api_secret'] as String? ?? '';
_razorpayWebhookSecret = rz['webhook_secret'] as String? ?? '';
}
_phonepeEnabled = config['phonepe'] != null ? 'true' : 'false';
if (config['phonepe'] != null) {
final pp = config['phonepe'] as Map<String, dynamic>;
_phonepeMerchantId = pp['api_key'] as String? ?? '';
_phonepeSaltKey = pp['api_secret'] as String? ?? '';
_phonepeSaltIndex = pp['salt_index'] as String? ?? '1';
}
_loadingGateway = false;
});
} catch (_) {
if (!mounted) return;
setState(() => _loadingGateway = false);
}
}

Future<void> _saveGatewayConfig() async {
setState(() => _savingGateway = true);
try {
// Save Razorpay
if (_razorpayEnabled == 'true') {
await ref.read(paymentGatewayServiceProvider).saveGatewayConfig(
gateway: 'razorpay',
apiKey: _razorpayKey.isNotEmpty ? _razorpayKey : null,
apiSecret: _razorpaySecret.isNotEmpty ? _razorpaySecret : null,
webhookSecret: _razorpayWebhookSecret.isNotEmpty ? _razorpayWebhookSecret : null,
sandbox: 'true',
);
} else {
await ref.read(paymentGatewayServiceProvider).deleteGatewayConfig('razorpay');
}

// Save PhonePe
if (_phonepeEnabled == 'true') {
await ref.read(paymentGatewayServiceProvider).saveGatewayConfig(
gateway: 'phonepe',
apiKey: _phonepeMerchantId.isNotEmpty ? _phonepeMerchantId : null,
apiSecret: _phonepeSaltKey.isNotEmpty ? _phonepeSaltKey : null,
webhookSecret: '',
sandbox: 'true',
saltIndex: _phonepeSaltIndex,
);
} else {
await ref.read(paymentGatewayServiceProvider).deleteGatewayConfig('phonepe');
}

if (!mounted) return;
_showSnack('Payment gateway configuration saved', isSuccess: true);
} catch (e) {
if (!mounted) return;
_showSnack('Failed to save gateway config: $e', isError: true);
} finally {
if (mounted) setState(() => _savingGateway = false);
}
}

// ────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────

void _showSnack(String message, {bool isError = false, bool isSuccess = false}) {
final bg = isError
? Colors.red
: isSuccess
? AppColors.success
: null;
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Row(
children: [
Icon(
isError
? Icons.error_outline_rounded
: isSuccess
? Icons.check_circle_rounded
: Icons.info_outline_rounded,
color: Colors.white,
size: 20,
),
const SizedBox(width: 12),
Expanded(child: Text(message)),
],
),
backgroundColor: bg,
behavior: SnackBarBehavior.floating,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
),
);
}

@override
Widget build(BuildContext context) {
final theme = Theme.of(context);
final isDark = theme.brightness == Brightness.dark;

return Scaffold(
backgroundColor: theme.scaffoldBackgroundColor,
appBar: AppBar(
title: const Text('Integrations & APIs'),
leading: IconButton(
icon: const Icon(Icons.arrow_back_rounded),
onPressed: () => context.pop(),
),
backgroundColor: theme.scaffoldBackgroundColor,
elevation: 0,
bottom: TabBar(
controller: _tabController,
indicatorColor: AppColors.primary,
labelColor: AppColors.primary,
unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
tabs: const [
Tab(icon: Icon(Icons.forum_outlined, size: 20), text: 'Communication'),
Tab(icon: Icon(Icons.payment_rounded, size: 20), text: 'Gateways'),
],
),
),
body: SafeArea(
child: TabBarView(
controller: _tabController,
children: [
_buildCommunicationsTab(theme, isDark),
_buildPaymentGatewaysTab(theme, isDark),
],
),
),
);
}

// ────────────────────────────────────────────────────────────────
// TAB 1 — Communications
// ────────────────────────────────────────────────────────────────

Widget _buildCommunicationsTab(ThemeData theme, bool isDark) {
return SingleChildScrollView(
padding: const EdgeInsets.all(24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Text(
'Communications & Alerts',
style: theme.textTheme.titleLarge
?.copyWith(fontWeight: FontWeight.w800),
),
const SizedBox(width: 8),
Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
decoration: BoxDecoration(
color: AppColors.success.withValues(alpha: 0.12),
borderRadius: BorderRadius.circular(6),
),
child: Text(
'ACTIVE',
style: TextStyle(
fontSize: 10,
fontWeight: FontWeight.bold,
color: AppColors.success,
),
),
),
],
).animate().fadeIn(),
const SizedBox(height: 6),
Text(
'Configure channels for dispatching alerts, invoices, and notifications.',
style: TextStyle(
fontSize: 14,
color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
),
).animate(delay: 50.ms).fadeIn(),
const SizedBox(height: 24),

// ── Local SMS ──────────────────────────────────────────────
_buildSmsCard(theme).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05, end: 0),
const SizedBox(height: 16),

// ── Email Section ──────────────────────────────────────────
_buildEmailCard(theme).animate(delay: 130.ms).fadeIn().slideY(begin: 0.05, end: 0),
const SizedBox(height: 16),

// ── WhatsApp Section ────────────────────────────────────────
_buildWhatsAppCard(theme).animate(delay: 160.ms).fadeIn().slideY(begin: 0.05, end: 0),
],
),
);
}

// ── SMS Entry Card ────────────────────────────────────────────────

Widget _buildSmsCard(ThemeData theme) {
return GlassCard(
padding: const EdgeInsets.all(20),
child: InkWell(
onTap: () => context.push('/settings/sms'),
borderRadius: BorderRadius.circular(12),
child: Row(
children: [
Container(
width: 42,
height: 42,
decoration: BoxDecoration(
color: Colors.green.withValues(alpha: 0.1),
borderRadius: BorderRadius.circular(10),
),
child: const Icon(Icons.sms_rounded, color: Colors.green, size: 22),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Expanded(
child: const Text(
'Local SMS',
style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
),
),
Container(
padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
decoration: BoxDecoration(
color: Colors.green.withValues(alpha: 0.12),
borderRadius: BorderRadius.circular(6),
),
child: const Text(
'ACTIVE',
style: TextStyle(
fontSize: 10,
fontWeight: FontWeight.bold,
color: Colors.green,
),
),
),
],
),
const SizedBox(height: 2),
Text(
'Auto-send, SIM selection, reminders, and history',
style: TextStyle(
fontSize: 12,
color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
),
),
],
),
),
Icon(
Icons.chevron_right_rounded,
size: 20,
color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3),
),
],
),
),
);
}

// ────────────────────────────────────────────────────────────────
// Email Card
// ────────────────────────────────────────────────────────────────

Widget _buildEmailCard(ThemeData theme) {
return GlassCard(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Header row
Row(
children: [
Container(
width: 42,
height: 42,
decoration: BoxDecoration(
color: Colors.blue.withValues(alpha: 0.1),
borderRadius: BorderRadius.circular(10),
),
child: const Icon(Icons.email_outlined, color: Colors.blue, size: 22),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'SMTP / Email Settings',
style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
),
Text(
_emailProvider == 'none'
? 'Not configured'
: _emailProvider == 'resend'
? 'Resend API'
: 'SMTP Relay',
style: TextStyle(
fontSize: 12,
color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
),
),
],
),
),
if (_emailProvider != 'none')
Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
],
),

const SizedBox(height: 20),

// Loading state
if (_loadingEmail)
const Padding(
padding: EdgeInsets.symmetric(vertical: 16),
child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
)
else ...[
// Provider selector
Row(
children: [
_ProviderChip(
label: 'Resend',
selected: _emailProvider == 'resend',
onTap: () => setState(() => _emailProvider = 'resend'),
color: Colors.purple,
),
const SizedBox(width: 8),
_ProviderChip(
label: 'SMTP',
selected: _emailProvider == 'smtp',
onTap: () => setState(() => _emailProvider = 'smtp'),
color: Colors.blue,
),
const SizedBox(width: 8),
_ProviderChip(
label: 'None',
selected: _emailProvider == 'none',
onTap: () => setState(() => _emailProvider = 'none'),
color: Colors.grey,
),
],
),

if (_emailProvider == 'resend') ...[
const SizedBox(height: 16),
TextField(
controller: _resendKeyCtrl,
obscureText: true,
decoration: const InputDecoration(
labelText: 'Resend API Key',
hintText: 're_xxxxxxxxxxxx',
prefixIcon: Icon(Icons.key_outlined, size: 20),
border: OutlineInputBorder(),
),
),
const SizedBox(height: 4),
Text(
'Get your API key from resend.com/api-keys',
style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5)),
),
],

if (_emailProvider == 'smtp') ...[
const SizedBox(height: 16),
Row(
children: [
Expanded(
child: TextField(
controller: _smtpHostCtrl,
decoration: const InputDecoration(
labelText: 'SMTP Host',
hintText: 'smtp.example.com',
prefixIcon: Icon(Icons.dns_outlined, size: 20),
border: OutlineInputBorder(),
),
),
),
const SizedBox(width: 12),
SizedBox(
width: 80,
child: TextField(
controller: _smtpPortCtrl,
keyboardType: TextInputType.number,
decoration: const InputDecoration(
labelText: 'Port',
hintText: '465',
border: OutlineInputBorder(),
),
),
),
],
),
const SizedBox(height: 12),
TextField(
controller: _smtpUserCtrl,
decoration: const InputDecoration(
labelText: 'Username',
hintText: 'user@example.com',
prefixIcon: Icon(Icons.person_outline, size: 20),
border: OutlineInputBorder(),
),
),
const SizedBox(height: 12),
TextField(
controller: _smtpPassCtrl,
obscureText: true,
decoration: const InputDecoration(
labelText: 'Password',
hintText: 'App password or SMTP password',
prefixIcon: Icon(Icons.lock_outline, size: 20),
border: OutlineInputBorder(),
),
),
],

if (_emailProvider != 'none') ...[
const SizedBox(height: 16),
Row(
children: [
Expanded(
child: TextField(
controller: _fromEmailCtrl,
decoration: const InputDecoration(
labelText: 'From Email',
hintText: 'noreply@yourorg.com',
prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
border: OutlineInputBorder(),
),
),
),
const SizedBox(width: 12),
Expanded(
child: TextField(
controller: _fromNameCtrl,
decoration: const InputDecoration(
labelText: 'From Name',
hintText: 'Your Organization',
prefixIcon: Icon(Icons.badge_outlined, size: 20),
border: OutlineInputBorder(),
),
),
),
],
),

// Test email row
Container(
margin: const EdgeInsets.only(top: 16),
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
borderRadius: BorderRadius.circular(12),
border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
),
child: Row(
children: [
Expanded(
child: TextField(
controller: _testEmailCtrl,
keyboardType: TextInputType.emailAddress,
decoration: const InputDecoration(
labelText: 'Send test email to',
hintText: 'you@example.com',
border: OutlineInputBorder(),
isDense: true,
),
),
),
const SizedBox(width: 12),
_sendingTest
? const SizedBox(
width: 36,
height: 36,
child: CircularProgressIndicator(strokeWidth: 2.5),
)
: IconButton(
onPressed: _sendTestEmail,
icon: const Icon(Icons.send_rounded),
tooltip: 'Send test',
style: IconButton.styleFrom(
backgroundColor: AppColors.primary,
foregroundColor: Colors.white,
),
),
],
),
),
],

const SizedBox(height: 20),
SizedBox(
width: double.infinity,
height: 48,
child: ElevatedButton.icon(
onPressed: _savingEmail ? null : _saveEmail,
icon: _savingEmail
? const SizedBox(
width: 16,
height: 16,
child: CircularProgressIndicator(
strokeWidth: 2.5,
color: Colors.white,
),
)
: const Icon(Icons.save_outlined, size: 18),
label: Text(
_savingEmail ? 'Saving…' : 'Save Email Configuration',
style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
),
style: ElevatedButton.styleFrom(
backgroundColor: AppColors.primary,
foregroundColor: Colors.white,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
),
),
),

const SizedBox(height: 12),
Row(
children: [
Icon(
_emailProvider != 'none'
? Icons.check_circle_rounded
: Icons.circle_outlined,
size: 14,
color: _emailProvider != 'none' ? AppColors.success : Colors.grey,
),
const SizedBox(width: 6),
Text(
_emailProvider != 'none'
? 'Email notifications enabled'
: 'Email notifications disabled',
style: TextStyle(
fontSize: 12,
color: _emailProvider != 'none' ? AppColors.success : Colors.grey,
),
),
],
),
],
],
),
);
}

// ────────────────────────────────────────────────────────────────
// WhatsApp Card
// ────────────────────────────────────────────────────────────────

Widget _buildWhatsAppCard(ThemeData theme) {
return GlassCard(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Header
Row(
children: [
Container(
width: 42,
height: 42,
decoration: BoxDecoration(
color: Colors.teal.withValues(alpha: 0.1),
borderRadius: BorderRadius.circular(10),
),
child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.teal, size: 22),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'WhatsApp Business API',
style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
),
Text(
'Official notifications to customer devices',
style: TextStyle(
fontSize: 12,
color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
),
),
],
),
),
if (_waPhoneIdCtrl.text.isNotEmpty)
Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
],
),

const SizedBox(height: 16),

if (_loadingWhatsApp)
const Padding(
padding: EdgeInsets.symmetric(vertical: 16),
child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
)
else ...[
TextField(
controller: _waPhoneIdCtrl,
decoration: const InputDecoration(
labelText: 'Phone Number ID',
hintText: 'From Meta Developer Console',
prefixIcon: Icon(Icons.phone_iphone_outlined, size: 20),
border: OutlineInputBorder(),
),
),
const SizedBox(height: 12),
TextField(
controller: _waBizIdCtrl,
decoration: const InputDecoration(
labelText: 'Business Account ID',
hintText: 'e.g. 123456789012345',
prefixIcon: Icon(Icons.business_outlined, size: 20),
border: OutlineInputBorder(),
),
),
const SizedBox(height: 12),
TextField(
controller: _waTokenCtrl,
obscureText: true,
decoration: const InputDecoration(
labelText: 'Access Token',
hintText: 'Permanent or temporary token',
prefixIcon: Icon(Icons.key_outlined, size: 20),
border: OutlineInputBorder(),
),
),
const SizedBox(height: 4),
Text(
'Get these from developers.facebook.com > WhatsApp > Getting Started',
style: TextStyle(
fontSize: 11,
color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
),
),

// Test row
Container(
margin: const EdgeInsets.only(top: 16),
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
borderRadius: BorderRadius.circular(12),
border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
),
child: Row(
children: [
Expanded(
child: TextField(
controller: _waTestPhoneCtrl,
keyboardType: TextInputType.phone,
decoration: const InputDecoration(
labelText: 'Send test to phone number',
hintText: '+919876543210',
border: OutlineInputBorder(),
isDense: true,
),
),
),
const SizedBox(width: 12),
_sendingWaTest
? const SizedBox(
width: 36,
height: 36,
child: CircularProgressIndicator(strokeWidth: 2.5),
)
: IconButton(
onPressed: _sendWaTest,
icon: const Icon(Icons.send_rounded),
tooltip: 'Send test',
style: IconButton.styleFrom(
backgroundColor: AppColors.teal,
foregroundColor: Colors.white,
),
),
],
),
),

const SizedBox(height: 20),
SizedBox(
width: double.infinity,
height: 48,
child: ElevatedButton.icon(
onPressed: _savingWhatsApp ? null : _saveWhatsApp,
icon: _savingWhatsApp
? const SizedBox(
width: 16,
height: 16,
child: CircularProgressIndicator(
strokeWidth: 2.5,
color: Colors.white,
),
)
: const Icon(Icons.save_outlined, size: 18),
label: Text(
_savingWhatsApp ? 'Saving…' : 'Save WhatsApp Configuration',
style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
),
style: ElevatedButton.styleFrom(
backgroundColor: AppColors.teal,
foregroundColor: Colors.white,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
),
),
),

const SizedBox(height: 12),
Row(
children: [
Icon(
_waPhoneIdCtrl.text.isNotEmpty
? Icons.check_circle_rounded
: Icons.circle_outlined,
size: 14,
color: _waPhoneIdCtrl.text.isNotEmpty ? AppColors.success : Colors.grey,
),
const SizedBox(width: 6),
Text(
_waPhoneIdCtrl.text.isNotEmpty
? 'WhatsApp Business API configured'
: 'Not configured',
style: TextStyle(
fontSize: 12,
color: _waPhoneIdCtrl.text.isNotEmpty ? AppColors.success : Colors.grey,
),
),
],
),
],
],
),
);
}

// ────────────────────────────────────────────────────────────────
// TAB 2 — Payment Gateways
// ────────────────────────────────────────────────────────────────

Widget _buildPaymentGatewaysTab(ThemeData theme, bool isDark) {
return SingleChildScrollView(
padding: const EdgeInsets.all(24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Text(
'Repayment Gateways',
style: theme.textTheme.titleLarge
?.copyWith(fontWeight: FontWeight.w800),
),
const SizedBox(width: 8),
Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
decoration: BoxDecoration(
color: Colors.green.withValues(alpha: 0.12),
borderRadius: BorderRadius.circular(6),
),
child: const Text(
'LIVE',
style: TextStyle(
fontSize: 10,
fontWeight: FontWeight.bold,
color: Colors.green,
),
),
),
],
).animate().fadeIn(),
const SizedBox(height: 6),
Text(
'Cashless repayment pipelines. Customers pay via UPI intents.',
style: TextStyle(
fontSize: 14,
color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
),
).animate(delay: 50.ms).fadeIn(),
const SizedBox(height: 24),

// ── UPI (live) ────────────────────────────────────────────
_buildUpiConfigSection(theme).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05, end: 0),
const SizedBox(height: 16),

// ── Razorpay / PhonePe Config ──────────────────────────────
_buildGatewayConfigCard(theme, isDark).animate(delay: 130.ms).fadeIn().slideY(begin: 0.05, end: 0),
],
),
);
}

// ── UPI Config Section (unchanged from before) ───────────────────

Widget _buildUpiConfigSection(ThemeData theme) {
return GlassCard(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
width: 42,
height: 42,
decoration: BoxDecoration(
color: Colors.green.withValues(alpha: 0.1),
borderRadius: BorderRadius.circular(10),
),
child: const Icon(Icons.qr_code_2_rounded, color: Colors.green, size: 22),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'UPI Direct Payments',
style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
),
Text(
'Configure merchant VPA for customer self-service UPI payments',
style: TextStyle(
fontSize: 12,
color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
),
),
],
),
),
],
),
const SizedBox(height: 20),

if (_loadingUpiConfig)
const Padding(
padding: EdgeInsets.symmetric(vertical: 24),
child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
)
else ...[
TextFormField(
controller: _upiVpaCtrl,
keyboardType: TextInputType.emailAddress,
textCapitalization: TextCapitalization.none,
decoration: const InputDecoration(
labelText: 'UPI VPA',
hintText: 'yourorg@bankupi',
prefixIcon: Icon(Icons.alternate_email_rounded),
border: OutlineInputBorder(),
),
),
const SizedBox(height: 16),
TextFormField(
controller: _upiMerchantCtrl,
textCapitalization: TextCapitalization.words,
decoration: const InputDecoration(
labelText: 'Merchant Name',
hintText: 'Displayed on the customer UPI app',
prefixIcon: Icon(Icons.storefront_outlined),
border: OutlineInputBorder(),
),
),
const SizedBox(height: 20),
SizedBox(
width: double.infinity,
height: 48,
child: ElevatedButton.icon(
onPressed: _savingUpi ? null : _saveUpi,
icon: _savingUpi
? const SizedBox(
width: 16,
height: 16,
child: CircularProgressIndicator(
strokeWidth: 2.5,
color: Colors.white,
),
)
: const Icon(Icons.save_outlined, size: 18),
label: Text(
_savingUpi ? 'Saving UPI config…' : 'Save UPI Configuration',
style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
),
style: ElevatedButton.styleFrom(
backgroundColor: AppColors.success,
foregroundColor: Colors.white,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
),
),
),

const SizedBox(height: 12),
Row(
children: [
Icon(
Icons.check_circle_rounded,
size: 14,
color: _upiVpaCtrl.text.trim().isNotEmpty ? Colors.green : Colors.grey,
),
const SizedBox(width: 6),
Text(
_upiVpaCtrl.text.trim().isNotEmpty
? 'VPA configured — customers can pay via UPI'
: 'No VPA configured — UPI payments disabled',
style: TextStyle(
fontSize: 12,
color: _upiVpaCtrl.text.trim().isNotEmpty ? Colors.green : Colors.grey,
),
),
],
),
],
],
),
);
}

// ── Gateway Config Card (Razorpay + PhonePe) ──────────────────────

Widget _buildGatewayConfigCard(ThemeData theme, bool isDark) {
return GlassCard(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Header
Row(
children: [
Container(
width: 42,
height: 42,
decoration: BoxDecoration(
color: Colors.deepPurple.withValues(alpha: 0.1),
borderRadius: BorderRadius.circular(10),
),
child: const Icon(Icons.payment_rounded, color: Colors.deepPurple, size: 22),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text('Razorpay / PhonePe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
Text(
_razorpayEnabled == 'true' || _phonepeEnabled == 'true'
? 'Gateway configured'
: 'Not configured',
style: TextStyle(
fontSize: 12,
color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
),
),
],
),
),
if (_razorpayEnabled == 'true' || _phonepeEnabled == 'true')
Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
],
),

if (_loadingGateway)
const Padding(
padding: EdgeInsets.symmetric(vertical: 16),
child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
)
else ...[
const SizedBox(height: 20),

// ── Razorpay Section ──
_GatewaySection(
title: 'Razorpay',
icon: Icons.credit_card_rounded,
color: Colors.deepPurple,
enabled: _razorpayEnabled,
onToggle: (v) => setState(() => _razorpayEnabled = v ? 'true' : 'false'),
children: [
TextField(
controller: _razorpayKeyCtrl..text = _razorpayKey,
decoration: const InputDecoration(
labelText: 'API Key',
hintText: 'rzp_test_... or rzp_live_...',
prefixIcon: Icon(Icons.key_outlined, size: 20),
border: OutlineInputBorder(),
),
onChanged: (v) => _razorpayKey = v,
),
const SizedBox(height: 12),
TextField(
controller: _razorpaySecretCtrl..text = _razorpaySecret,
obscureText: true,
decoration: const InputDecoration(
labelText: 'API Secret',
hintText: 'Your Razorpay API secret',
prefixIcon: Icon(Icons.lock_outline, size: 20),
border: OutlineInputBorder(),
),
onChanged: (v) => _razorpaySecret = v,
),
const SizedBox(height: 12),
TextField(
controller: _razorpayWebhookCtrl..text = _razorpayWebhookSecret,
obscureText: true,
decoration: const InputDecoration(
labelText: 'Webhook Secret',
hintText: 'From Razorpay Dashboard > Settings > Webhooks',
prefixIcon: Icon(Icons.webhook_outlined, size: 20),
border: OutlineInputBorder(),
),
onChanged: (v) => _razorpayWebhookSecret = v,
),
],
),
const SizedBox(height: 16),

// ── PhonePe Section ──
_GatewaySection(
title: 'PhonePe',
icon: Icons.phone_android_rounded,
color: Colors.teal,
enabled: _phonepeEnabled,
onToggle: (v) => setState(() => _phonepeEnabled = v ? 'true' : 'false'),
children: [
TextField(
controller: _phonepeMerchantCtrl..text = _phonepeMerchantId,
decoration: const InputDecoration(
labelText: 'Merchant ID',
hintText: 'Your PhonePe Merchant ID',
prefixIcon: Icon(Icons.business_outlined, size: 20),
border: OutlineInputBorder(),
),
onChanged: (v) => _phonepeMerchantId = v,
),
const SizedBox(height: 12),
TextField(
controller: _phonepeSaltCtrl..text = _phonepeSaltKey,
obscureText: true,
decoration: const InputDecoration(
labelText: 'Salt Key',
hintText: 'From PhonePe Dashboard',
prefixIcon: Icon(Icons.key_outlined, size: 20),
border: OutlineInputBorder(),
),
onChanged: (v) => _phonepeSaltKey = v,
),
const SizedBox(height: 12),
TextField(
decoration: const InputDecoration(
labelText: 'Salt Index',
hintText: 'Usually 1 or 2',
prefixIcon: Icon(Icons.numbers_rounded, size: 20),
border: OutlineInputBorder(),
),
onChanged: (v) => _phonepeSaltIndex = v,
),
],
),
const SizedBox(height: 20),
SizedBox(
width: double.infinity,
height: 48,
child: ElevatedButton.icon(
onPressed: _savingGateway ? null : _saveGatewayConfig,
icon: _savingGateway
? const SizedBox(
width: 16,
height: 16,
child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
)
: const Icon(Icons.save_outlined, size: 18),
label: Text(
_savingGateway ? 'Saving…' : 'Save Gateway Configuration',
style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
),
style: ElevatedButton.styleFrom(
backgroundColor: AppColors.primary,
foregroundColor: Colors.white,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
),
),
),
],
],
),
);
}
}

// ─── Expandable Gateway Section Widget ──────────────────────────────

class _GatewaySection extends StatelessWidget {
final String title;
final IconData icon;
final Color color;
final String enabled;
final ValueChanged<bool> onToggle;
final List<Widget> children;

const _GatewaySection({
required this.title,
required this.icon,
required this.color,
required this.enabled,
required this.onToggle,
required this.children,
});

@override
Widget build(BuildContext context) {
final theme = Theme.of(context);
final isOn = enabled == 'true';
return Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
borderRadius: BorderRadius.circular(12),
border: Border.all(
color: isOn
? color.withValues(alpha: 0.4)
: theme.dividerColor.withValues(alpha: 0.5),
),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Icon(
icon,
size: 20,
color: isOn
? color
: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
),
const SizedBox(width: 10),
Text(
title,
style: TextStyle(
fontWeight: FontWeight.w700,
fontSize: 14,
color: isOn
? null
: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
),
),
const Spacer(),
GestureDetector(
onTap: () => onToggle(!isOn),
child: AnimatedContainer(
duration: const Duration(milliseconds: 200),
width: 44,
height: 24,
decoration: BoxDecoration(
color: isOn
? color
: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3),
borderRadius: BorderRadius.circular(12),
),
child: AnimatedAlign(
duration: const Duration(milliseconds: 200),
alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
child: Container(
width: 20,
height: 20,
margin: const EdgeInsets.symmetric(horizontal: 2),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(10),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.15),
blurRadius: 4,
offset: const Offset(0, 1),
),
],
),
),
),
),
),
],
),
if (isOn) ...[
const SizedBox(height: 16),
...children,
],
],
),
);
}
}

// ─── Provider Chip Widget ──────────────────────────────────────────

class _ProviderChip extends StatelessWidget {
final String label;
final bool selected;
final VoidCallback onTap;
final Color color;

const _ProviderChip({
required this.label,
required this.selected,
required this.onTap,
required this.color,
});

@override
Widget build(BuildContext context) {
final theme = Theme.of(context);
return GestureDetector(
onTap: onTap,
child: AnimatedContainer(
duration: const Duration(milliseconds: 200),
padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
decoration: BoxDecoration(
color: selected
? color.withValues(alpha: 0.15)
: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: selected ? color : theme.dividerColor.withValues(alpha: 0.5),
width: selected ? 1.5 : 1,
),
),
child: Text(
label,
style: TextStyle(
fontSize: 13,
fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
color: selected
? color
: theme.textTheme.bodyMedium?.color,
),
),
),
);
}
}
