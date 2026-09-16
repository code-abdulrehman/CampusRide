import 'enums.dart';
import 'user.dart';
import 'vehicle.dart';

class Ride {
  final String rideId;
  final String driverId;
  final String vehicleId;
  final String origin;
  final String destination;
  final String originCampusId;
  final String destinationCampusId;
  final DateTime departureDate;
  final DateTime departureTime;
  DateTime expectedArrivalTime;
  int availableSeats;
  final double contributionPerSeat;
  final double pickupRadius;
  final double maxDetour;
  final bool recurringRide;
  List<String> recurringDays;
  RideStatus rideStatus;
  final String additionalNotes;
  final List<String> conditions;
  String? ridePin;
  DateTime createdAt;
  CampusUser? driver;
  Vehicle? vehicle;
  double matchScore;
  bool latestLocationReceived;

  bool get isAvailable => rideStatus == RideStatus.open && availableSeats > 0;

  Ride({
    required this.rideId,
    required this.driverId,
    required this.vehicleId,
    required this.origin,
    required this.destination,
    required this.originCampusId,
    required this.destinationCampusId,
    required this.departureDate,
    required this.departureTime,
    DateTime? expectedArrivalTime,
    required this.availableSeats,
    this.contributionPerSeat = 200.0,
    this.pickupRadius = 2.0,
    this.maxDetour = 3.0,
    this.recurringRide = false,
    this.recurringDays = const [],
    this.rideStatus = RideStatus.open,
    this.additionalNotes = '',
    this.conditions = const [],
    this.ridePin,
    DateTime? createdAt,
    this.driver,
    this.vehicle,
    this.matchScore = 0,
    this.latestLocationReceived = false,
  })  : expectedArrivalTime = expectedArrivalTime ?? departureTime.add(const Duration(minutes: 45)),
        createdAt = createdAt ?? DateTime.now();

  factory Ride.fromApi(Map<String, dynamic> json, {Map<String, dynamic>? driverJson, Map<String, dynamic>? vehicleJson, double? givenMatch}) {
    final departureAt = DateTime.tryParse((json['departureAt'] ?? '').toString()) ?? DateTime.now();
    final expectedArrivalAt = DateTime.tryParse((json['expectedArrivalAt'] ?? '').toString());
    final statusStr = (json['status'] ?? '').toString().toUpperCase();
    return Ride(
      rideId: (json['id'] ?? json['rideId']) as String,
      driverId: (json['driverId'] ?? '') as String,
      vehicleId: (json['vehicleId'] ?? '') as String,
      origin: (json['origin'] ?? '') as String,
      destination: (json['destination'] ?? '') as String,
      originCampusId: (json['originCampusId'] ?? '') as String,
      destinationCampusId: (json['destinationCampusId'] ?? '') as String,
      departureDate: departureAt,
      departureTime: departureAt,
      expectedArrivalTime: expectedArrivalAt,
      availableSeats: (json['availableSeats'] ?? 0) as int,
      contributionPerSeat: ((json['pricePerSeat'] ?? json['contributionPerSeat']) as num?)?.toDouble() ?? 0.0,
      pickupRadius: ((json['pickupRadiusKm'] ?? json['pickupRadius']) as num?)?.toDouble() ?? 2.0,
      maxDetour: ((json['maxDetourMinutes'] ?? json['maxDetour']) as num?)?.toDouble() ?? 3.0,
      recurringRide: (json['recurring'] ?? false) as bool,
      recurringDays: (json['recurringDays'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      rideStatus: _rideStatusFromString(statusStr),
      additionalNotes: (json['notes'] ?? '') as String,
      conditions: (json['conditions'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      ridePin: json['ridePin'] as String?,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      driver: driverJson != null ? CampusUser.fromApi(driverJson) : null,
      vehicle: vehicleJson != null ? Vehicle.fromApi(vehicleJson) : null,
      matchScore: givenMatch ?? ((json['match'] as Map<String, dynamic>?)?['matchScore'] as num?)?.toDouble() ?? 0,
    );
  }

  static RideStatus _rideStatusFromString(String s) {
    switch (s) {
      case 'OPEN':
        return RideStatus.open;
      case 'FULL':
        return RideStatus.full;
      case 'STARTED':
        return RideStatus.started;
      case 'COMPLETED':
        return RideStatus.completed;
      case 'CANCELLED':
        return RideStatus.cancelled;
      case 'EXPIRED':
        return RideStatus.expired;
      default:
        return RideStatus.open;
    }
  }

  Map<String, dynamic> toSearchableMap() => {
        'originCampusId': originCampusId,
        'destinationCampusId': destinationCampusId,
        'departureDate': departureDate.toIso8601String(),
        'departureHour': departureTime.hour,
        'departureMinute': departureTime.minute,
        'availableSeats': availableSeats,
        'contributionPerSeat': contributionPerSeat,
        'rideStatus': rideStatus.index,
      };
}
