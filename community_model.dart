import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityModel {
  String id;
  String name;
  String description;
  String hobby;
  String creatorId;
  List<String> members;
  List<String> bannedUsers;
  List<Map<String, dynamic>> bannedUsersDetails;
  int memberCount;
  DateTime createdAt;

  CommunityModel({
    required this.id,
    required this.name,
    required this.description,
    required this.hobby,
    required this.creatorId,
    required this.members,
    this.bannedUsers = const [],
    this.bannedUsersDetails = const [],
    this.memberCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'hobby': hobby,
      'creatorId': creatorId,
      'members': members,
      'bannedUsers': bannedUsers,
      'bannedUsersDetails': bannedUsersDetails,
      'memberCount': members.length,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory CommunityModel.fromMap(String id, Map<String, dynamic> map) {
    return CommunityModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      hobby: map['hobby'] ?? '',
      creatorId: map['creatorId'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      bannedUsers: List<String>.from(map['bannedUsers'] ?? []),
      bannedUsersDetails: List<Map<String, dynamic>>.from(map['bannedUsersDetails'] ?? []),
      memberCount: map['memberCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  CommunityModel copyWith({
    String? id,
    String? name,
    String? description,
    String? hobby,
    String? creatorId,
    List<String>? members,
    List<String>? bannedUsers,
    List<Map<String, dynamic>>? bannedUsersDetails,
    int? memberCount,
    DateTime? createdAt,
  }) {
    return CommunityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      hobby: hobby ?? this.hobby,
      creatorId: creatorId ?? this.creatorId,
      members: members ?? this.members,
      bannedUsers: bannedUsers ?? this.bannedUsers,
      bannedUsersDetails: bannedUsersDetails ?? this.bannedUsersDetails,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}