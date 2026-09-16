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

  factory AppNotification.fromApi(Map<String, dynamic> json) {
    final typeStr = (json['type'] ?? '').toString().toUpperCase();
    final data = json['data'] as Map<String, dynamic>?;
    AppNotificationType type;
    switch (typeStr) {
      case 'BOOKING_REQUESTED':
        type = AppNotificationType.rideRequest;
        break;
      case 'BOOKING_ACCEPTED':
        type = AppNotificationType.rideAccepted;
        break;
      case 'BOOKING_REJECTED':
        type = AppNotificationType.rideRejected;
        break;
      case 'RIDE_STARTED':
        type = AppNotificationType.rideStarted;
        break;
      case 'RIDE_CANCELLED':
      case 'WAITLIST_NOTIFY':
        type = AppNotificationType.rideCancelled;
        break;
      default:
        type = AppNotificationType.general;
    }
    return AppNotification(
      id: (json['id'] ?? json['notificationId']) as String,
      userId: (json['userId'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      message: (json['body'] ?? '') as String,
      type: type,
      isRead: json['readAt'] != null && json['readAt'] != '',
      relatedRideId: data?['rideId'] != null ? data!['rideId'].toString() : null,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}
