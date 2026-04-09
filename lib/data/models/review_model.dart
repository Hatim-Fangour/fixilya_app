
class ReviewModel {
  final String id;
  final String bookingId;
  final String clientId;
  final String handymanId;
  final double rating;
  final String? comment;
  final List<String> images;
  final bool isVerified;
  final String? handymanResponse;
  final DateTime? respondedAt;
  final int helpfulCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReviewModel({
    required this.id,
    required this.bookingId,
    required this.clientId,
    required this.handymanId,
    required this.rating,
    this.comment,
    this.images = const [],
    this.isVerified = false,
    this.handymanResponse,
    this.respondedAt,
    this.helpfulCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] ?? '',
      bookingId: json['bookingId'] ?? '',
      clientId: json['clientId'] ?? '',
      handymanId: json['handymanId'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      comment: json['comment'],
      images: List<String>.from(json['images'] ?? []),
      isVerified: json['isVerified'] ?? false,
      handymanResponse: json['handymanResponse'],
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'])
          : null,
      helpfulCount: json['helpfulCount'] ?? 0,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookingId': bookingId,
    'clientId': clientId,
    'handymanId': handymanId,
    'rating': rating,
    'comment': comment,
    'images': images,
    'isVerified': isVerified,
    'handymanResponse': handymanResponse,
    'respondedAt': respondedAt?.toIso8601String(),
    'helpfulCount': helpfulCount,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  bool get hasComment => comment != null && comment!.isNotEmpty;
  bool get hasResponse => handymanResponse != null;
  bool get isExcellent => rating >= 4.5;
  bool get isGood => rating >= 3.5 && rating < 4.5;
  bool get isPoor => rating < 3.5;
}
