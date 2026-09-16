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

  factory UserReport.fromApi(Map<String, dynamic> json) {
    final statusStr = (json['status'] ?? 'OPEN').toString().toUpperCase();
    ReportStatus rStatus;
    switch (statusStr) {
      case 'OPEN':
        rStatus = ReportStatus.pending;
        break;
      case 'RESOLVED':
        rStatus = ReportStatus.reviewed;
        break;
      case 'WARNING':
        rStatus = ReportStatus.warning;
        break;
      case 'SUSPENDED':
        rStatus = ReportStatus.temporarySuspension;
        break;
      case 'BANNED':
        rStatus = ReportStatus.permanentBan;
        break;
      default:
        rStatus = ReportStatus.pending;
    }
    return UserReport(
      reportId: (json['id'] ?? json['reportId']) as String,
      reporterId: (json['reporterId'] ?? '') as String,
      reportedUserId: (json['reportedUserId'] ?? '') as String,
      rideId: json['rideId'] as String?,
      reason: _reasonFromString((json['reason'] ?? 'other').toString()),
      description: (json['details'] ?? json['description'] ?? '') as String,
      status: rStatus,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }

  static ReportReason _reasonFromString(String s) {
    switch (s) {
      case 'DANGEROUS_DRIVING':
        return ReportReason.dangerousDriving;
      case 'HARASSMENT':
        return ReportReason.harassment;
      case 'FAKE_DETAILS':
        return ReportReason.fakeDetails;
      case 'NO_SHOW':
        return ReportReason.noShow;
      case 'EXCESSIVE_CHARGING':
        return ReportReason.excessiveCharging;
      case 'MISBEHAVIOR':
        return ReportReason.misbehavior;
      case 'WRONG_PICKUP':
        return ReportReason.wrongPickup;
      case 'SPAM':
        return ReportReason.spam;
      default:
        return ReportReason.other;
    }
  }
}
