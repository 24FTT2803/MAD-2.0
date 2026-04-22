import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityModel {
  final String id;
  final String userId;
  final String type;
  final String? communityId;
  final String? communityName;
  final String? postId;
  final String? postTitle;
  final DateTime timestamp;

  ActivityModel({
    required this.id,
    required this.userId,
    required this.type,
    this.communityId,
    this.communityName,
    this.postId,
    this.postTitle,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'communityId': communityId,
      'communityName': communityName,
      'postId': postId,
      'postTitle': postTitle,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory ActivityModel.fromMap(String id, Map<String, dynamic> map) {
    return ActivityModel(
      id: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      communityId: map['communityId'],
      communityName: map['communityName'],
      postId: map['postId'],
      postTitle: map['postTitle'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}