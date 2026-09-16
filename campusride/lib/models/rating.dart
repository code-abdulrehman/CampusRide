class UserRating {
  final String ratingId;
  final String rideId;
  final String raterId;
  final String rateeId;
  final double overallRating;
  final double punctuality;
  final double behaviour;
  final double communication;
  final String comment;
  final DateTime createdAt;

  UserRating({
    required this.ratingId,
    required this.rideId,
    required this.raterId,
    required this.rateeId,
    required this.overallRating,
    this.punctuality = 0.0,
    this.behaviour = 0.0,
    this.communication = 0.0,
    this.comment = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
