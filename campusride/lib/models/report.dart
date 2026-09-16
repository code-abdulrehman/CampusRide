import 'enums.dart';

class UserReport {
  final String reportId;
  final String reporterId;
  final String reportedUserId;
  final String? rideId;
  final ReportReason reason;
  String description;
  ReportStatus status;
  final DateTime createdAt;

  UserReport({
    required this.reportId,
    required this.reporterId,
    required this.reportedUserId,
    this.rideId,
    required this.reason,
    this.description = '',
    this.status = ReportStatus.pending,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
