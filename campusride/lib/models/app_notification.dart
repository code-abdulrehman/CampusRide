enum AppNotificationType { rideRequest, rideAccepted, rideRejected, rideStarted, rideCancelled, waitlist, general }

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final AppNotificationType type;
  bool isRead;
  final String? relatedRideId;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    this.relatedRideId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
