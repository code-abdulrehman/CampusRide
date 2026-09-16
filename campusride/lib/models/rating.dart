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

  factory UserRating.fromApi(Map<String, dynamic> json) {
    final reviewer = json['reviewer'] as Map<String, dynamic>?;
    return UserRating(
      ratingId: (json['id'] ?? json['ratingId']) as String,
      rideId: (json['rideId'] ?? '') as String,
      raterId: (reviewer?['id'] ?? json['raterId'] ?? '') as String,
      rateeId: (reviewer?['id'] ?? json['rateeId'] ?? '') as String,
      overallRating: ((json['overall'] ?? json['overallRating'] ?? 0) as num).toDouble(),
      punctuality: ((json['punctuality'] ?? 0) as num).toDouble(),
      behaviour: ((json['behaviour'] ?? 0) as num).toDouble(),
      communication: ((json['communication'] ?? 0) as num).toDouble(),
      comment: (json['comment'] ?? '') as String,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}
