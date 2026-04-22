import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  String id;
  String communityId;
  String authorId;
  String authorName;
  String title;
  String content;
  List<String> likes;
  List<String> dislikes;
  int commentCount;
  DateTime createdAt;

  PostModel({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.content,
    this.likes = const [],
    this.dislikes = const [],
    this.commentCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'communityId': communityId,
      'authorId': authorId,
      'authorName': authorName,
      'title': title,
      'content': content,
      'likes': likes,
      'dislikes': dislikes,
      'commentCount': commentCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PostModel.fromMap(String id, Map<String, dynamic> map) {
    return PostModel(
      id: id,
      communityId: map['communityId'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      likes: List<String>.from(map['likes'] ?? []),
      dislikes: List<String>.from(map['dislikes'] ?? []),
      commentCount: map['commentCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  PostModel copyWith({
    String? id,
    String? communityId,
    String? authorId,
    String? authorName,
    String? title,
    String? content,
    List<String>? likes,
    List<String>? dislikes,
    int? commentCount,
    DateTime? createdAt,
  }) {
    return PostModel(
      id: id ?? this.id,
      communityId: communityId ?? this.communityId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      title: title ?? this.title,
      content: content ?? this.content,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}