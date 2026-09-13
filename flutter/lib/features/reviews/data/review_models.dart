/// `GET /products/:id/reviews` item — visible reviews only, and never the
/// reviewer's email/phone (backend `PublicReview`).
class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.rating,
    required this.text,
    required this.userDisplayName,
    required this.createdAt,
  });

  final int id;
  final int rating;
  final String text;
  final String userDisplayName;
  final DateTime createdAt;

  factory ReviewModel.fromJson(Map<String, dynamic> j) => ReviewModel(
    id: (j['id'] as num).toInt(),
    rating: (j['rating'] as num?)?.toInt() ?? 0,
    text: j['text'] as String? ?? '',
    userDisplayName: j['user_display_name'] as String? ?? '',
    createdAt:
        DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime(2000),
  );
}
