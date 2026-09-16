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

  factory RideRequest.fromApi(Map<String, dynamic> json) {
    final earliest = DateTime.tryParse((json['earliestDeparture'] ?? '').toString()) ?? DateTime.now();
    final latest = DateTime.tryParse((json['latestDeparture'] ?? '').toString()) ?? earliest;
    final statusStr = (json['status'] ?? 'OPEN').toString().toUpperCase();
    return RideRequest(
      requestId: (json['id'] ?? json['requestId']) as String,
      studentId: (json['studentId'] ?? '') as String,
      origin: (json['origin'] ?? json['originCampusId'] ?? '') as String,
      destination: (json['destination'] ?? json['destinationCampusId'] ?? '') as String,
      preferredDate: earliest,
      preferredStartTime: TimeOfDay(hour: earliest.hour, minute: earliest.minute),
      latestDepartureTime: TimeOfDay(hour: latest.hour, minute: latest.minute),
      requiredArrivalTime: DateTime.tryParse((json['requiredArrival'] ?? '').toString()) ?? latest,
      requiredSeats: (json['requiredSeats'] ?? 1) as int,
      maximumBudget: ((json['maxBudget'] ?? 300) as num).toDouble(),
      maxPickupDistance: ((json['maxPickupDistanceKm'] ?? 2) as num).toDouble(),
      requestStatus: statusStr == 'OPEN' ? RequestStatus.pending : (statusStr == 'FULFILLED' ? RequestStatus.fulfilled : RequestStatus.cancelled),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

enum RequestStatus { pending, matched, fulfilled, cancelled }
