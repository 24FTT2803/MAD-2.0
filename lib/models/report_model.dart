import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String postId;
  final String postTitle;
  final String reportedBy;
  final String reporterName;
  final String reason;
  final DateTime timestamp;
  final String status;

  ReportModel({
    required this.id,
    required this.postId,
    required this.postTitle,
    required this.reportedBy,
    required this.reporterName,
    required this.reason,
    required this.timestamp,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'postTitle': postTitle,
      'reportedBy': reportedBy,
      'reporterName': reporterName,
      'reason': reason,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
    };
  }

  factory ReportModel.fromMap(String id, Map<String, dynamic> map) {
    return ReportModel(
      id: id,
      postId: map['postId'] ?? '',
      postTitle: map['postTitle'] ?? '',
      reportedBy: map['reportedBy'] ?? '',
      reporterName: map['reporterName'] ?? '',
      reason: map['reason'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'pending',
    );
  }
}