import 'dart:math';
import 'package:flutter/material.dart' show TimeOfDay;
import '../models/enums.dart';
import '../models/user.dart';
import '../models/vehicle.dart';
import '../models/ride.dart';
import '../models/ride_request.dart';
import '../models/booking.dart';
import '../models/rating.dart';
import '../models/report.dart';
import '../models/app_notification.dart';

class DataRepository {
  DataRepository._privateConstructor();
  static final DataRepository instance = DataRepository._privateConstructor();

  final Map<String, CampusUser> _users = {};
  final Map<String, Vehicle> _vehicles = {};
  final Map<String, Ride> _rides = {};
  final Map<String, RideRequest> _rideRequests = {};
  final Map<String, Booking> _bookings = {};
  final List<UserRating> _ratings = [];
  final List<UserReport> _reports = [];
  final List<AppNotification> _notifications = [];

  // Getters
  List<CampusUser> get users => _users.values.toList();
  List<Vehicle> get vehicles => _vehicles.values.toList();
  List<Ride> get rides => _rides.values.toList();
  List<RideRequest> get rideRequests => _rideRequests.values.toList();
  List<Booking> get bookings => _bookings.values.toList();
  List<UserRating> get ratings => _ratings.toList();
  List<UserReport> get reports => _reports.toList();
  List<AppNotification> get notifications => _notifications.toList();

  // --- User Operations ---
  void addUser(CampusUser user) => _users[user.userId] = user;
  CampusUser? getUserById(String id) => _users[id];

  CampusUser? login(String email, String password) {
    try {
      return _users.values.firstWhere((u) => u.email == email);
    } catch (_) {
      return null;
    }
  }

  List<CampusUser> getVerifiedDrivers() =>
      _users.values.where((u) => u.isStudentVerified).toList();

  // --- Vehicle Operations ---
  void addVehicle(Vehicle vehicle) => _vehicles[vehicle.vehicleId] = vehicle;
  Vehicle? getVehicleById(String id) => _vehicles[id];
  List<Vehicle> getVehiclesByOwner(String ownerId) =>
      _vehicles.values.where((v) => v.ownerUserId == ownerId).toList();

  // --- Ride Request Operations ---
  void addRideRequest(RideRequest request) => _rideRequests[request.requestId] = request;

  // --- Ride Operations ---
  void addRide(Ride ride) => _rides[ride.rideId] = ride;
  Ride? getRideById(String id) => _rides[id];
  List<Ride> getRidesByDriver(String driverId) =>
      _rides.values.where((r) => r.driverId == driverId).toList();
  List<Ride> getAvailableRides() =>
      _rides.values.where((r) => r.isAvailable).toList();

  List<Ride> searchRides({
    required String fromCampusId,
    required String toCampusId,
    required DateTime date,
    int? maxDepartureHour,
    int? maxDepartureMinutes,
    int seatsNeeded = 1,
  }) {
    return _rides.values.where((r) {
      if (r.originCampusId != fromCampusId) return false;
      if (r.destinationCampusId != toCampusId) return false;
      if (!r.isAvailable) return false;
      if (r.availableSeats < seatsNeeded) return false;

      final rideDate = DateTime(r.departureDate.year, r.departureDate.month, r.departureDate.day);
      final searchDate = DateTime(date.year, date.month, date.day);
      if (!rideDate.isAtSameMomentAs(searchDate)) return false;

      if (maxDepartureHour != null) {
        final maxMinutes = maxDepartureHour * 60 + (maxDepartureMinutes ?? 0);
        if (r.departureTime.hour * 60 + r.departureTime.minute > maxMinutes) return false;
      }

      return true;
    }).toList();
  }

  // --- Matching ---
  double calculateMatchScore(Ride ride, TimeOfDay startTime, TimeOfDay endTime, double budget, String fromCampusId) {
    double score = 0;

    // Route match (30%) - campus to campus
    score += 30.0;

    // Time match (25%)
    final rideTimeMin = ride.departureTime.hour * 60 + ride.departureTime.minute;
    final startMin = startTime.hour * 60 + startTime.minute;
    final endMin = endTime.hour * 60 + endTime.minute;
    if (rideTimeMin >= startMin && rideTimeMin <= endMin) {
      score += 25.0;
    } else {
      final diff = (rideTimeMin - startMin).abs();
      score += max(0, 25.0 - diff * 0.5);
    }

    // Pickup distance (15%) - simplified, assume some distance
    score += 10.0;

    // Budget match (10%)
    if (ride.contributionPerSeat <= budget) {
      score += 10.0;
    } else {
      score += max(0, 10.0 - ((ride.contributionPerSeat - budget) / budget) * 10);
    }

    // Driver rating (10%)
    final driver = _users[ride.driverId];
    if (driver != null) {
      score += (driver.rating / 5.0) * 10.0;
    }

    // Reliability (10%)
    if (driver != null) {
      score += (driver.reliabilityScore / 100.0) * 10.0;
    }

    return score.roundToDouble().clamp(0, 100);
  }

  List<MapEntry<Ride, double>> findMatchingRides({
    required String fromCampusId,
    required String toCampusId,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required double budget,
    int seatsNeeded = 1,
  }) {
    final candidates = searchRides(
      fromCampusId: fromCampusId,
      toCampusId: toCampusId,
      date: date,
      seatsNeeded: seatsNeeded,
    );

    final scored = candidates.map((ride) {
      final score = calculateMatchScore(ride, startTime, endTime, budget, fromCampusId);
      return MapEntry(ride, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored;
  }

  // --- Booking Operations ---
  void addBooking(Booking booking) => _bookings[booking.bookingId] = booking;
  Booking? getBookingById(String id) => _bookings[id];
  List<Booking> getBookingsByRide(String rideId) =>
      _bookings.values.where((b) => b.rideId == rideId).toList();
  List<Booking> getBookingsByPassenger(String passengerId) =>
      _bookings.values.where((b) => b.passengerId == passengerId).toList();

  void updateBookingStatus(String bookingId, BookingStatus status) {
    final booking = _bookings[bookingId];
    if (booking != null) {
      booking.status = status;
    }
  }

  void updateRideSeats(String rideId, int seatsReduction) {
    final ride = _rides[rideId];
    if (ride != null) {
      ride.availableSeats = (ride.availableSeats - seatsReduction).clamp(0, 99);
      if (ride.availableSeats == 0) {
        ride.rideStatus = RideStatus.full;
      }
    }
  }

  // --- Rating Operations ---
  void addRating(UserRating rating) => _ratings.add(rating);
  List<UserRating> getRatingsForUser(String userId) =>
      _ratings.where((r) => r.rateeId == userId).toList();

  double getAverageRating(String userId) {
    final userRatings = getRatingsForUser(userId);
    if (userRatings.isEmpty) return 0.0;
    final sum = userRatings.map((r) => r.overallRating).reduce((a, b) => a + b);
    return (sum / userRatings.length * 10).roundToDouble() / 10;
  }

  // --- Report Operations ---
  void addReport(UserReport report) => _reports.add(report);
  List<UserReport> getPendingReports() =>
      _reports.where((r) => r.status == ReportStatus.pending).toList();

  // --- Notification Operations ---
  void addNotification(AppNotification notification) => _notifications.add(notification);
  List<AppNotification> getNotificationsForUser(String userId) =>
      _notifications.where((n) => n.userId == userId).toList();
  int getUnreadCount(String userId) =>
      _notifications.where((n) => n.userId == userId && !n.isRead).length;

  void markNotificationRead(String notificationId) {
    final notif = _notifications.firstWhere((n) => n.id == notificationId, orElse: () => throw Exception('Not found'));
    notif.isRead = true;
  }

  // --- Seed Data ---
  void seedDemoData() {
    // Campuses are static via Campus.sampleCampuses

    // Users
    final ahmed = CampusUser(
      userId: 'u1',
      name: 'Ahmed Khan',
      email: 'ahmed@university.edu',
      phone: '0301-1234567',
      studentId: 'STU-001',
      department: 'Computer Science',
      semester: '6th',
      mainCampus: 'campus_a',
      verificationStatus: UserVerificationStatus.driverVerified,
      rating: 4.8,
      completedRides: 46,
      cancelledRides: 1,
    );
    final hamza = CampusUser(
      userId: 'u2',
      name: 'Hamza Ali',
      email: 'hamza@university.edu',
      phone: '0321-7654321',
      studentId: 'STU-002',
      department: 'Electrical Engineering',
      semester: '4th',
      mainCampus: 'campus_a',
      verificationStatus: UserVerificationStatus.studentVerified,
      rating: 4.5,
      completedRides: 12,
      cancelledRides: 2,
    );
    final usman = CampusUser(
      userId: 'u3',
      name: 'Usman Raza',
      email: 'usman@university.edu',
      phone: '0333-9876543',
      studentId: 'STU-003',
      department: 'Business Admin',
      semester: '8th',
      mainCampus: 'main',
      verificationStatus: UserVerificationStatus.studentVerified,
      rating: 4.2,
      completedRides: 30,
      cancelledRides: 5,
    );
    final fatima = CampusUser(
      userId: 'u4',
      name: 'Fatima Noor',
      email: 'fatima@university.edu',
      phone: '0345-1122334',
      studentId: 'STU-004',
      department: 'Data Science',
      semester: '3rd',
      mainCampus: 'main',
      verificationStatus: UserVerificationStatus.studentVerified,
      rating: 4.9,
      completedRides: 60,
      cancelledRides: 0,
    );
    final admin = CampusUser(
      userId: 'admin1',
      name: 'Admin User',
      email: 'admin@university.edu',
      studentId: 'ADM-001',
      verificationStatus: UserVerificationStatus.driverVerified,
    );

    for (final u in [ahmed, hamza, usman, fatima, admin]) {
      addUser(u);
    }

    // Vehicles
    final v1 = Vehicle(
      vehicleId: 'v1',
      ownerUserId: 'u1',
      company: 'Honda',
      model: 'City',
      modelYear: 2022,
      color: 'White',
      registrationNumber: 'LEA-1234',
      totalSeats: 5,
      passengerCapacity: 4,
      verificationStatus: VehicleStatus.verified,
      vehicleStatus: VehicleStatus.verified,
    );
    final v2 = Vehicle(
      vehicleId: 'v2',
      ownerUserId: 'u3',
      company: 'Toyota',
      model: 'Corolla',
      modelYear: 2023,
      color: 'Black',
      registrationNumber: 'LEB-5678',
      totalSeats: 5,
      passengerCapacity: 4,
      verificationStatus: VehicleStatus.verified,
      vehicleStatus: VehicleStatus.verified,
    );
    addVehicle(v1);
    addVehicle(v2);

    // Rides
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    final r1 = Ride(
      rideId: 'r1',
      driverId: 'u1',
      vehicleId: 'v1',
      origin: 'Campus A',
      destination: 'Main Campus',
      originCampusId: 'campus_a',
      destinationCampusId: 'main',
      departureDate: tomorrow,
      departureTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8, 0),
      expectedArrivalTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8, 45),
      availableSeats: 3,
      contributionPerSeat: 200,
      conditions: ['No smoking', 'University students only', 'No food inside vehicle'],
      additionalNotes: 'I will leave sharp at 8:05 AM.',
    );

    final r2 = Ride(
      rideId: 'r2',
      driverId: 'u3',
      vehicleId: 'v2',
      origin: 'Campus A',
      destination: 'Main Campus',
      originCampusId: 'campus_a',
      destinationCampusId: 'main',
      departureDate: tomorrow,
      departureTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8, 30),
      expectedArrivalTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 15),
      availableSeats: 2,
      contributionPerSeat: 250,
      conditions: ['University students only'],
    );

    addRide(r1);
    addRide(r2);

    // Seed a sample ride request
    final req1 = RideRequest(
      requestId: 'req1',
      studentId: 'u2',
      origin: 'Campus A',
      destination: 'Main Campus',
      preferredDate: tomorrow,
      preferredStartTime: const TimeOfDay(hour: 7, minute: 45),
      latestDepartureTime: const TimeOfDay(hour: 8, minute: 30),
      requiredArrivalTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0),
      requiredSeats: 1,
      maximumBudget: 250,
    );
    _rideRequests[req1.requestId] = req1;

    // Notifications
    addNotification(AppNotification(
      id: 'notif1',
      userId: 'u2',
      title: 'Ride Found!',
      message: 'Ahmed has a ride at 8:00 AM from Campus A to Main Campus. 92% match!',
      type: AppNotificationType.general,
    ));
    addNotification(AppNotification(
      id: 'notif2',
      userId: 'u1',
      title: 'New Ride Request',
      message: 'Ali has requested a seat on your 8:00 AM ride.',
      type: AppNotificationType.rideRequest,
    ));
  }
}
