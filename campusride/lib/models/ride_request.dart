import 'package:flutter/material.dart' show TimeOfDay;

class RideRequest {
  final String requestId;
  final String studentId;
  final String origin;
  final String destination;
  final DateTime preferredDate;
  final TimeOfDay preferredStartTime;
  final TimeOfDay latestDepartureTime;
  final DateTime requiredArrivalTime;
  final int requiredSeats;
  final double maximumBudget;
  final double maxPickupDistance;
  final String specialRequirements;
  RequestStatus requestStatus;
  final DateTime createdAt;

  RideRequest({
    required this.requestId,
    required this.studentId,
    required this.origin,
    required this.destination,
    required this.preferredDate,
    required this.preferredStartTime,
    required this.latestDepartureTime,
    required this.requiredArrivalTime,
    this.requiredSeats = 1,
    this.maximumBudget = 300.0,
    this.maxPickupDistance = 2.0,
    this.specialRequirements = '',
    this.requestStatus = RequestStatus.pending,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

enum RequestStatus { pending, matched, fulfilled, cancelled }
