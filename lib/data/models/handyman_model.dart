class HandymanModel {
  final String id;
  final String name;
  final String category;
  final String city;
  final double rating;
  final int reviews;
  final String phone;
  final double hourlyRate;
  final String image;
  final bool verified;
  final String experience;
  final int completedJobs;

  HandymanModel({
    required this.id,
    required this.name,
    required this.category,
    required this.city,
    required this.rating,
    required this.reviews,
    required this.phone,
    required this.hourlyRate,
    required this.image,
    required this.verified,
    required this.experience,
    required this.completedJobs,
  });

  factory HandymanModel.fromJson(Map<String, dynamic> json) {
    return HandymanModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      city: json['city'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviews: json['reviews'] ?? 0,
      phone: json['phone'] ?? '',
      hourlyRate: (json['hourlyRate'] ?? 0.0).toDouble(),
      image: json['image'] ?? '',
      verified: json['verified'] ?? false,
      experience: json['experience'] ?? '',
      completedJobs: json['completedJobs'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'city': city,
      'rating': rating,
      'reviews': reviews,
      'phone': phone,
      'hourlyRate': hourlyRate,
      'image': image,
      'verified': verified,
      'experience': experience,
      'completedJobs': completedJobs,
    };
  }
}
