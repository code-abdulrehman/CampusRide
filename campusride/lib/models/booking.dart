import 'enums.dart';

class Booking {
  final String bookingId;
  final String rideId;
  final String passengerId;
  String driverId;
  final DateTime createdAt;
  BookingStatus status;
  int seatsBooked;
  double amountPaid;
  final String pickupPoint;
  String? ridePin;
  String? passengerName;
  String? driverName;
  String? rideOrigin;
  String? rideDestination;
  DateTime? rideDepartureAt;
  String? rideStatus;

  Booking({
    required this.bookingId,
    required this.rideId,
    required this.passengerId,
    required this.driverId,
    this.status = BookingStatus.requested,
    this.seatsBooked = 1,
    this.amountPaid = 0.0,
    this.pickupPoint = 'Campus Gate',
    this.ridePin,
    DateTime? createdAt,
    this.passengerName,
    this.driverName,
    this.rideOrigin,
    this.rideDestination,
    this.rideDepartureAt,
    this.rideStatus,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Booking.fromApi(Map<String, dynamic> json) {
    final statusStr = (json['status'] ?? 'REQUESTED').toString().toUpperCase();
    final rideJson = json['ride'] as Map<String, dynamic>?;
    final driver = rideJson?['driver'] as Map<String, dynamic>?;
    final passenger = json['passenger'] as Map<String, dynamic>?;
    final seats = (json['seats'] ?? json['seatsBooked'] ?? 1) as int;
    var amount = 0.0;
    if (rideJson != null) {
      amount = ((rideJson['pricePerSeat'] ?? 0) as num).toDouble() * seats;
    }
    return Booking(
      bookingId: (json['id'] ?? json['bookingId']) as String,
      rideId: (json['rideId'] ?? rideJson?['id'] ?? '') as String,
      passengerId: (json['passengerId'] ?? passenger?['id'] ?? '') as String,
      driverId: (json['driverId'] ?? driver?['id'] ?? '') as String,
      status: _statusFromString(statusStr),
      seatsBooked: seats,
      amountPaid: json['amountPaid'] != null
          ? (json['amountPaid'] as num).toDouble()
          : amount,
      ridePin: (json['ridePin'] ?? json['pin'] ?? '').toString().isEmpty
          ? null
          : (json['ridePin'] ?? json['pin']).toString(),
      passengerName: passenger?['fullName'] as String?,
      driverName: driver?['fullName'] as String?,
      rideOrigin: rideJson?['origin'] as String?,
      rideDestination: rideJson?['destination'] as String?,
      rideDepartureAt: DateTime.tryParse((rideJson?['departureAt'] ?? '').toString()),
      rideStatus: (rideJson?['status'] ?? '').toString(),
    );
  }

  static BookingStatus _statusFromString(String s) {
    switch (s) {
      case 'ACCEPTED':
        return BookingStatus.accepted;
      case 'REJECTED':
        return BookingStatus.rejected;
      case 'CANCELLED':
        return BookingStatus.cancelled;
      case 'CHECKED_IN':
        return BookingStatus.checkedIn;
      case 'RIDE_STARTED':
        return BookingStatus.rideStarted;
      case 'COMPLETED':
        return BookingStatus.completed;
      case 'NO_SHOW':
        return BookingStatus.noShow;
      default:
        return BookingStatus.requested;
    }
  }
}
