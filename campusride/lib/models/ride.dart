import 'enums.dart';

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
  final String ridePin;
  DateTime createdAt;

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
    String? ridePin,
    DateTime? createdAt,
  })  : expectedArrivalTime = expectedArrivalTime ?? departureTime.add(const Duration(minutes: 45)),
        ridePin = ridePin ?? _generatePin(),
        createdAt = createdAt ?? DateTime.now();

  static String _generatePin() {
    return (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
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
