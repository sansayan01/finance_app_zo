import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailService {
  final String? apiKey;
  final String baseUrl = 'https://api.resend.com';

  EmailService(this.apiKey);

  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  Future<bool> send({
    required String to,
    required String subject,
    required String body,
  }) async {
    if (!isConfigured) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/emails'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': 'MicroFlow Pro <noreply@microflowpro.com>',
          'to': [to],
          'subject': subject,
          'html': body,
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendWelcome(String email, String orgName) async {
    return send(
      to: email,
      subject: 'Welcome to MicroFlow Pro!',
      body:
          '<h2>Welcome to MicroFlow Pro!</h2><p>Your organization <b>$orgName</b> is ready.</p><p><a href="https://app.microflowpro.com">Go to Dashboard</a></p>',
    );
  }

  Future<bool> sendOverdueAlert(
      String email, String memberName, double amount) async {
    return send(
      to: email,
      subject: 'Overdue EMI Alert',
      body:
          '<h2>Overdue Collection</h2><p>Member <b>$memberName</b> has an overdue EMI of ₹${amount.toStringAsFixed(2)}.</p>',
    );
  }
}
