import 'package:cloud_firestore/cloud_firestore.dart';

enum UserType { client, handyman }

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final String userType;
  final String? profileImage;
  final DateTime createdAt;
  final bool emailVerified;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.userType,
    this.profileImage,
    required this.createdAt,
    required this.emailVerified,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      userType: json['userType'] ?? '',
      profileImage: json['profileImage'],
      createdAt: _parseDateTime(json['createdAt']),
      emailVerified: json['emailVerified'] ?? false,
    );
  }

  /// Safely parse DateTime from Firestore Timestamp, ISO string, or null.
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'userType': userType,
      'profileImage': profileImage,
      'createdAt': createdAt.toIso8601String(),
      'emailVerified': emailVerified,
    };
  }

  // Method 1: fromFirestore
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }

    return UserModel.fromJson({...data, 'id': doc.id});
  }

  // Method 2: toFirestore
  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? userType,
    String? profileImage,
    DateTime? createdAt,
    bool? emailVerified,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      userType: userType ?? this.userType,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
}
