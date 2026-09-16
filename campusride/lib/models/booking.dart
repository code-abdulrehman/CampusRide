import 'enums.dart';

class Booking {
  final String bookingId;
  final String rideId;
  final String passengerId;
  final String driverId;
  final DateTime createdAt;
  BookingStatus status;
  int seatsBooked;
  double amountPaid;
  final String pickupPoint;
  String? ridePin;

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
  }) : createdAt = createdAt ?? DateTime.now();
}
