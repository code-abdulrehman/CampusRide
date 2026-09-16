import 'enums.dart';

class Vehicle {
  final String vehicleId;
  final String ownerUserId;
  String vehicleType;
  String company;
  String model;
  int modelYear;
  String color;
  String registrationNumber;
  int totalSeats;
  int passengerCapacity;
  VehicleStatus registrationStatus;
  VehicleStatus verificationStatus;
  VehicleStatus vehicleStatus;

  Vehicle({
    required this.vehicleId,
    required this.ownerUserId,
    this.vehicleType = 'Sedan',
    this.company = '',
    this.model = '',
    this.modelYear = 2024,
    this.color = 'White',
    this.registrationNumber = '',
    this.totalSeats = 5,
    this.passengerCapacity = 4,
    this.registrationStatus = VehicleStatus.pending,
    this.verificationStatus = VehicleStatus.pending,
    this.vehicleStatus = VehicleStatus.pending,
  });

  bool get isVerified => verificationStatus == VehicleStatus.verified;

  String get displayName => '$company $model'.trim();
}
