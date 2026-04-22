import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String username;
  final String email;
  final String role;
  final List<String> hobbies;
  final String? profileImage;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.username,
    required this.email,
    this.role = 'user',
    this.hobbies = const [],
    this.profileImage,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'hobbies': hobbies,
      'profileImage': profileImage,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      hobbies: List<String>.from(json['hobbies'] ?? []),
      profileImage: json['profileImage'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}