import 'dart:math';
import 'package:flutter/material.dart' show TimeOfDay;
import '../config/api_config.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../models/vehicle.dart';
import '../models/ride.dart';
import '../models/ride_request.dart';
import '../models/booking.dart';
import '../models/rating.dart';
import '../models/app_notification.dart';
import '../models/campus.dart';
import 'api_client.dart';

class DataRepository {
  DataRepository._privateConstructor();
  static final DataRepository instance = DataRepository._privateConstructor();

  final ApiClient api = ApiClient.instance;

  // --- Auth ---
  Future<({CampusUser user, String accessToken, String refreshToken})> login(
    String email,
    String password,
  ) async {
    final res = await api.post(ApiPaths.login, body: {'email': email, 'password': password});
    final data = res['data'] as Map<String, dynamic>;
    await _persistSession(data);
    final user = CampusUser.fromApi(data['user'] as Map<String, dynamic>);
    return (user: user, accessToken: _token(data, 'accessToken'), refreshToken: _token(data, 'refreshToken'));
  }

  Future<({CampusUser user, String accessToken, String refreshToken})> register({
    required String name,
    required String email,
    required String studentId,
    String? password,
    String? phone,
    String? department,
    String? semester,
    String? mainCampusId,
  }) async {
    final res = await api.post(ApiPaths.register, body: {
      'fullName': name,
      'email': email,
      'password': password ?? 'CampusRide@123',
      'studentId': studentId,
      if (phone != null) 'phone': phone,
      if (department != null) 'department': department,
      if (semester != null) 'semester': semester,
      if (mainCampusId != null) 'mainCampusId': mainCampusId,
    });
    final data = res['data'] as Map<String, dynamic>;
    await _persistSession(data);
    return (user: CampusUser.fromApi(data['user'] as Map<String, dynamic>), accessToken: _token(data, 'accessToken'), refreshToken: _token(data, 'refreshToken'));
  }

  Future<void> logout(String refreshToken) async {
    try {
      await api.post(ApiPaths.logout, body: {'refreshToken': refreshToken});
    } catch (_) {
      // ignore server errors on logout
    }
    await api.clearTokens();
  }

  Future<void> _persistSession(Map<String, dynamic> data) async {
    final tokens = data['tokens'] as Map<String, dynamic>;
    await api.saveTokens(
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
      expiresIn: tokens['expiresIn'] as String?,
    );
  }

  String _token(Map<String, dynamic> data, String key) =>
      (((data['tokens'] as Map<String, dynamic>)[key]) ?? '') as String;

  // --- Users ---
  Future<CampusUser> getCurrentUser() async {
    final res = await api.get(ApiPaths.me);
    final data = res['data'] as Map<String, dynamic>;
    if (data.containsKey('user')) {
      return CampusUser.fromApi(data['user'] as Map<String, dynamic>);
    }
    return CampusUser.fromApi(data);
  }

  Future<Map<String, dynamic>> getBootstrap() async {
    final res = await api.get(ApiPaths.bootstrap);
    final data = (res['data'] as Map<String, dynamic>?) ?? {};
    final campusesRaw = data['campuses'] as List<dynamic>? ?? [];
    if (campusesRaw.isNotEmpty) {
      _campuses = campusesRaw.map((c) => Campus.fromApi(c as Map<String, dynamic>)).toList();
    }
    return data;
  }

  Future<CampusUser> updateProfile(CampusUser user) async {
    final res = await api.put(ApiPaths.profile, body: {
      'fullName': user.name,
      'phone': user.phone,
      'department': user.department,
      'semester': user.semester,
    });
    final data = res['data'] as Map<String, dynamic>;
    return CampusUser.fromApi(data.containsKey('user') ? data['user'] as Map<String, dynamic> : data);
  }

  Future<void> setEmergencyContact(String name, String phone) async {
    await api.patch(ApiPaths.emergencyContact, body: {'contactName': name, 'contactPhone': phone});
  }

  Future<CampusUser> fetchUser(String userId) async {
    final res = await api.get('/users/$userId');
    final data = res['data'] as Map<String, dynamic>;
    return CampusUser.fromApi(data);
  }

  List<CampusUser> getVerifiedDrivers() => []; // fetched via search results where needed

  // --- Campuses ---
  List<Campus> get campuses => _campuses;
  List<Campus> _campuses = Campus.sampleCampuses;

  Future<List<Campus>> fetchCampuses() async {
    final res = await api.get(ApiPaths.campuses);
    final data = res['data'] as List<dynamic>;
    _campuses = data.map((c) => Campus.fromApi(c as Map<String, dynamic>)).toList();
    return _campuses;
  }

  // --- Vehicles ---
  Future<Vehicle> addVehicle({
    required String company,
    required String model,
    required int modelYear,
    required String color,
    required String registrationNumber,
    required int totalSeats,
    String vehicleType = 'SEDAN',
  }) async {
    final res = await api.post(ApiPaths.vehicles, body: {
      'company': company,
      'model': model,
      'year': modelYear,
      'color': color,
      'registrationNumber': registrationNumber,
      'totalSeats': totalSeats,
      'passengerCapacity': totalSeats - 1,
      'vehicleType': vehicleType,
    });
    final data = res['data'] as Map<String, dynamic>;
    return Vehicle.fromApi(data.containsKey('vehicle') ? data['vehicle'] as Map<String, dynamic> : data);
  }

  Future<List<Vehicle>> getMyVehicles() async {
    final res = await api.get(ApiPaths.vehicles);
    final data = res['data'] as List<dynamic>? ?? [];
    return data.map((v) => Vehicle.fromApi(v as Map<String, dynamic>)).toList();
  }

  Future<Vehicle?> getVehicleById(String id) async {
    try {
      final res = await api.get('${ApiPaths.vehicles}/$id');
      final data = res['data'] as Map<String, dynamic>;
      return Vehicle.fromApi(data);
    } catch (_) {
      return null;
    }
  }

  List<Vehicle> getVehiclesByOwner(String ownerId) => []; // in-memory cache replaced by getMyVehicles

  // --- Rides ---
  Future<Ride> createRide({
    required String originCampusId,
    required String destinationCampusId,
    required String origin,
    required String destination,
    required DateTime departureAt,
    required String vehicleId,
    required int availableSeats,
    required double contributionPerSeat,
    List<String> conditions = const [],
    String additionalNotes = '',
    bool recurring = false,
    List<String> recurringDays = const [],
  }) async {
    final res = await api.post(ApiPaths.rides, body: {
      'originCampusId': originCampusId,
      'destinationCampusId': destinationCampusId,
      'origin': origin,
      'destination': destination,
      'departureAt': departureAt.toUtc().toIso8601String(),
      'vehicleId': vehicleId,
      'availableSeats': availableSeats,
      'pricePerSeat': contributionPerSeat,
      'conditions': conditions,
      'notes': additionalNotes,
      'recurring': recurring,
      'recurringDays': recurringDays,
    });
    final data = res['data'] as Map<String, dynamic>;
    return Ride.fromApi(data);
  }

  Future<Ride?> getRideById(String id) async {
    try {
      final res = await api.get(ApiPaths.rideDetail(id));
      final data = res['data'] as Map<String, dynamic>;
      return Ride.fromApi(data.containsKey('ride') ? data['ride'] as Map<String, dynamic> : data);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getRideDetail(String id) async {
    final res = await api.get(ApiPaths.rideDetail(id));
    return (res['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<List<Ride>> getRidesByDriver(String driverId) async {
    final res = await api.get(ApiPaths.ridesMine);
    final data = res['data'] as List<dynamic>? ?? [];
    return data.map((r) => Ride.fromApi(r as Map<String, dynamic>)).toList();
  }

  Future<List<Map<String, dynamic>>> searchRides({
    required String fromCampusId,
    required String toCampusId,
    required DateTime date,
    int? maxDepartureHour,
    int? maxDepartureMinutes,
    int seatsNeeded = 1,
  }) async {
    final res = await api.get(ApiPaths.rideSearch, query: {
      'fromCampusId': fromCampusId,
      'toCampusId': toCampusId,
      'date':
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'seats': seatsNeeded,
      if (maxDepartureHour != null) 'latestDepartureHour': maxDepartureHour,
      if (maxDepartureMinutes != null) 'latestDepartureMinutes': maxDepartureMinutes,
    });
    final items = ((res['data'] as Map<String, dynamic>?)?['items'] as List<dynamic>? ?? []);
    return items.map((e) => (e as Map<String, dynamic>)).toList();
  }

  Future<Ride> cancelRide(String rideId) async {
    final res = await api.post(ApiPaths.rideCancel(rideId));
    final data = res['data'] as Map<String, dynamic>;
    return Ride.fromApi(data);
  }

  Future<Ride> startRide(String rideId, {bool checkin = true}) async {
    final res = await api.post(ApiPaths.rideStart(rideId), body: {'checkin': checkin});
    final data = res['data'] as Map<String, dynamic>;
    return Ride.fromApi(data);
  }

  Future<Ride> completeRide(String rideId) async {
    final res = await api.post(ApiPaths.rideComplete(rideId));
    final data = res['data'] as Map<String, dynamic>;
    return Ride.fromApi(data);
  }

  // --- Ride Requests ---
  Future<RideRequest> createRideRequest({
    required String originCampusId,
    required String destinationCampusId,
    required String origin,
    required String destination,
    required DateTime earliestDeparture,
    required DateTime latestDeparture,
    int requiredSeats = 1,
    double maxBudget = 300.0,
    double maxPickupDistanceKm = 2.0,
  }) async {
    final res = await api.post(ApiPaths.rideRequests, body: {
      'originCampusId': originCampusId,
      'destinationCampusId': destinationCampusId,
      'earliestDeparture': earliestDeparture.toUtc().toIso8601String(),
      'latestDeparture': latestDeparture.toUtc().toIso8601String(),
      'requiredSeats': requiredSeats,
      'maxBudget': maxBudget,
      'maxPickupDistanceKm': maxPickupDistanceKm,
    });
    final data = res['data'] as Map<String, dynamic>;
    return RideRequest.fromApi(data.containsKey('rideRequest') ? data['rideRequest'] as Map<String, dynamic> : data);
  }

  Future<List<RideRequest>> getMyRideRequests() async {
    final res = await api.get(ApiPaths.rideRequestsMine);
    final data = res['data'] as List<dynamic>? ?? [];
    return data.map((r) => RideRequest.fromApi(r as Map<String, dynamic>)).toList();
  }

  // --- Bookings ---
  Future<Booking> requestBooking(String rideId, {int seats = 1}) async {
    final res = await api.post(ApiPaths.bookingForRide(rideId), body: {'seats': seats});
    final data = res['data'] as Map<String, dynamic>;
    return Booking.fromApi(data.containsKey('booking') ? data['booking'] as Map<String, dynamic> : data);
  }

  Future<Booking> acceptBooking(String bookingId) async {
    final res = await api.post(ApiPaths.bookingAccept(bookingId));
    final data = res['data'] as Map<String, dynamic>;
    return Booking.fromApi(data.containsKey('booking') ? data['booking'] as Map<String, dynamic> : data);
  }

  Future<Booking> rejectBooking(String bookingId) async {
    final res = await api.post(ApiPaths.bookingReject(bookingId));
    final data = res['data'] as Map<String, dynamic>;
    return Booking.fromApi(data.containsKey('booking') ? data['booking'] as Map<String, dynamic> : data);
  }

  Future<Booking> cancelBooking(String bookingId) async {
    final res = await api.post(ApiPaths.bookingCancel(bookingId));
    final data = res['data'] as Map<String, dynamic>;
    return Booking.fromApi(data.containsKey('booking') ? data['booking'] as Map<String, dynamic> : data);
  }

  Future<Booking> checkinBooking(String bookingId, String pin) async {
    final res = await api.post(ApiPaths.bookingCheckin(bookingId), body: {'pin': pin});
    final data = res['data'] as Map<String, dynamic>;
    return Booking.fromApi(data.containsKey('booking') ? data['booking'] as Map<String, dynamic> : data);
  }

  Future<Booking> noShowBooking(String bookingId) async {
    final res = await api.post(ApiPaths.bookingNoShow(bookingId));
    final data = res['data'] as Map<String, dynamic>;
    return Booking.fromApi(data.containsKey('booking') ? data['booking'] as Map<String, dynamic> : data);
  }

  Future<List<Map<String, dynamic>>> getMyBookings() async {
    final res = await api.get(ApiPaths.bookingsMine);
    final data = res['data'] as List<dynamic>? ?? [];
    return data.map((b) => (b as Map<String, dynamic>)).toList();
  }

  Future<Booking?> getBookingById(String id) async {
    try {
      final res = await api.get(ApiPaths.bookingDetail(id));
      final data = res['data'] as Map<String, dynamic>;
      return Booking.fromApi(data.containsKey('booking') ? data['booking'] as Map<String, dynamic> : data);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getBookingsByRide(String rideId) async {
    final res = await api.get(ApiPaths.rideBookings(rideId));
    final data = res['data'] as List<dynamic>? ?? [];
    return data.map((b) => (b as Map<String, dynamic>)).toList();
  }

  // --- Ratings ---
  Future<void> submitRating({
    required String rideId,
    required String rateeId,
    required double overallRating,
    required double punctuality,
    required double behaviour,
    required double communication,
    String comment = '',
  }) async {
    await api.post('${ApiPaths.rideDetail(rideId)}/ratings', body: {
      'rateeId': rateeId,
      'overallRating': overallRating,
      'punctuality': punctuality,
      'behaviour': behaviour,
      'communication': communication,
      'comment': comment,
    });
  }

  Future<List<UserRating>> getRatingsForUser(String userId) async {
    final res = await api.get('/users/$userId/ratings');
    final data = res['data'] as List<dynamic>? ?? [];
    return data.map((r) => UserRating.fromApi(r as Map<String, dynamic>)).toList();
  }

  double getAverageRating(String userId) => 0.0; // server provides ratingAverage on user

  // --- Reports ---
  Future<void> submitReport({
    required String reportedUserId,
    String? rideId,
    required ReportReason reason,
    required String description,
  }) async {
    await api.post(ApiPaths.reportCreate(), body: {
      'reportedUserId': reportedUserId,
      if (rideId != null) 'rideId': rideId,
      'reason': reason.name
          .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m.group(0)}')
          .toUpperCase()
          .replaceFirst('_', ''),
      'description': description,
    });
  }

  // --- Notifications ---
  Future<List<AppNotification>> getNotificationsForUser(String userId) async {
    final res = await api.get(ApiPaths.notifications);
    final data = (res['data'] as Map<String, dynamic>?)?['items'] as List<dynamic>? ?? [];
    return data.map((n) => AppNotification.fromApi(n as Map<String, dynamic>)).toList();
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final res = await api.get(ApiPaths.notifications);
      final items = (res['data'] as Map<String, dynamic>?)?['items'] as List<dynamic>? ?? [];
      return items.where((n) => (n as Map<String, dynamic>)['readAt'] == null).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    await api.patch(ApiPaths.notificationRead(notificationId));
  }

  Future<void> markAllNotificationsRead() async {
    await api.post(ApiPaths.notificationsReadAll);
  }

  // --- Admin ---
  Future<Map<String, dynamic>> getAdminDashboard() async {
    final res = await api.get(ApiPaths.adminDashboard);
    return (res['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<List<Map<String, dynamic>>> getAdminUsers() async {
    final res = await api.get(ApiPaths.adminUsers);
    final data = (res['data'] as Map<String, dynamic>?)?['items'] as List<dynamic>? ?? [];
    return data.map((u) => (u as Map<String, dynamic>)).toList();
  }

  Future<List<Map<String, dynamic>>> getPendingDrivers() async {
    final res = await api.get('/admin/drivers/pending');
    final data = (res['data'] as Map<String, dynamic>?)?['items'] as List<dynamic>? ??
        res['data'] as List<dynamic>? ??
        [];
    return data.map((u) => (u as Map<String, dynamic>)).toList();
  }

  Future<List<Map<String, dynamic>>> getPendingVehicles() async {
    final res = await api.get('/admin/vehicles/pending');
    final data = (res['data'] as Map<String, dynamic>?)?['items'] as List<dynamic>? ??
        res['data'] as List<dynamic>? ??
        [];
    return data.map((v) => (v as Map<String, dynamic>)).toList();
  }

  Future<List<Map<String, dynamic>>> getAdminReports() async {
    final res = await api.get(ApiPaths.adminReports);
    final data = (res['data'] as Map<String, dynamic>?)?['items'] as List<dynamic>? ??
        res['data'] as List<dynamic>? ??
        [];
    return data.map((r) => (r as Map<String, dynamic>)).toList();
  }

  Future<void> adminVerifyStudent(String userId) async {
    // Student verification is automatic on registration; nothing to do.
  }

  Future<void> adminVerifyDriver(String userId, {String status = 'VERIFIED'}) async {
    await api.patch('/admin/drivers/$userId/verification', body: {'status': status});
  }

  Future<void> adminVerifyVehicle(String vehicleId, {String status = 'VERIFIED'}) async {
    await api.patch('/admin/vehicles/$vehicleId/verification', body: {'status': status});
  }

  Future<void> adminSuspendUser(String userId, {bool suspend = true}) async {
    await api.patch('/admin/users/$userId/status',
        body: {'accountStatus': suspend ? 'SUSPENDED' : 'ACTIVE'});
  }

  Future<void> adminResolveReport(String reportId, {String? status, String? adminAction}) async {
    await api.patch('/admin/reports/$reportId', body: {
      if (status != null) 'status': status,
      if (adminAction != null) 'adminAction': adminAction,
    });
  }

  // --- Matching helper (client-side fallback when server lacks match data) ---
  double calculateMatchScore(Ride ride, TimeOfDay startTime, TimeOfDay endTime, double budget, String fromCampusId) {
    double score = 0;
    score += 30.0;
    final rideTimeMin = ride.departureTime.hour * 60 + ride.departureTime.minute;
    final startMin = startTime.hour * 60 + startTime.minute;
    final endMin = endTime.hour * 60 + endTime.minute;
    if (rideTimeMin >= startMin && rideTimeMin <= endMin) {
      score += 25.0;
    } else {
      final diff = (rideTimeMin - startMin).abs();
      score += max(0, 25.0 - diff * 0.5);
    }
    score += 10.0;
    if (ride.contributionPerSeat <= budget) {
      score += 10.0;
    } else {
      score += max(0, 10.0 - ((ride.contributionPerSeat - budget) / budget) * 10);
    }
    score += 16.0;
    if (ride.driver != null) {
      score += ((ride.driver!.rating / 5.0) * 9.0).clamp(0, 9);
    }
    return score.roundToDouble().clamp(0, 100);
  }
}