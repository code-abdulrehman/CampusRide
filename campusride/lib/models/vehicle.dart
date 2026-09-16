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

  factory Vehicle.fromApi(Map<String, dynamic> json) {
    final statusStr = (json['verificationStatus'] ?? '').toString().toUpperCase();
    final active = (json['active'] ?? (statusStr == 'VERIFIED')) as bool;
    return Vehicle(
      vehicleId: (json['id'] ?? json['vehicleId']) as String,
      ownerUserId: (json['ownerId'] ?? json['ownerUserId'] ?? '') as String,
      vehicleType: (json['vehicleType'] ?? 'Sedan').toString().split('.').last,
      company: (json['company'] ?? '') as String,
      model: (json['model'] ?? '') as String,
      modelYear: (json['year'] ?? json['modelYear'] ?? DateTime.now().year) as int,
      color: (json['color'] ?? 'White') as String,
      registrationNumber: (json['registrationNumber'] ?? '') as String,
      totalSeats: (json['totalSeats'] ?? 5) as int,
      passengerCapacity: (json['passengerCapacity'] ?? 4) as int,
      verificationStatus: _vehicleStatus(statusStr),
      vehicleStatus: active ? VehicleStatus.verified : (statusStr == 'REJECTED' ? VehicleStatus.rejected : VehicleStatus.pending),
      registrationStatus: _vehicleStatus(statusStr),
    );
  }

  static VehicleStatus _vehicleStatus(String s) {
    switch (s) {
      case 'VERIFIED':
        return VehicleStatus.verified;
      case 'REJECTED':
        return VehicleStatus.rejected;
      case 'SUSPENDED':
        return VehicleStatus.suspended;
      default:
        return VehicleStatus.pending;
    }
  }
}
