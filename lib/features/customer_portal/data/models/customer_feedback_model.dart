/// Data model for customer feedback records from the `customer_feedback` table.
class CustomerFeedbackModel {
  final String id;
  final String type;
  final String? subject;
  final String message;
  final int? rating;
  final String status;
  final DateTime? createdAt;

  CustomerFeedbackModel({
    required this.id,
    required this.type,
    this.subject,
    required this.message,
    this.rating,
    required this.status,
    this.createdAt,
  });

  factory CustomerFeedbackModel.fromJson(Map<String, dynamic> json) {
    return CustomerFeedbackModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'other',
      subject: json['subject']?.toString(),
      message: json['message']?.toString() ?? '',
      rating: json['rating'] != null
          ? int.tryParse(json['rating'].toString())
          : null,
      status: json['status']?.toString() ?? 'new',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  bool get isNew => status == 'new';
  bool get isInReview => status == 'in_review';
  bool get isResolved => status == 'resolved';

  String get typeLabel => switch (type) {
        'complaint' => 'Complaint',
        'suggestion' => 'Suggestion',
        'appreciation' => 'Appreciation',
        'other' => 'Other',
        _ => type[0].toUpperCase() + type.substring(1),
      };

  String get statusLabel => switch (status) {
        'new' => 'New',
        'in_review' => 'In Review',
        'resolved' => 'Resolved',
        _ => status[0].toUpperCase() + status.substring(1),
      };
}
