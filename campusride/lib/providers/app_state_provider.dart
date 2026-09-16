import 'package:flutter/foundation.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../models/vehicle.dart';
import '../models/ride.dart';
import '../models/ride_request.dart';
import '../models/booking.dart';
import '../models/app_notification.dart';
import '../models/campus.dart';
import '../services/data_repository.dart';
import '../services/api_client.dart';

class AppStateProvider extends ChangeNotifier {
  final DataRepository repository = DataRepository.instance;

  CampusUser? currentUser;

  // Cached collections for fast screen reads
  List<Ride> myRides = [];
  List<Booking> myBookings = [];
  List<AppNotification> notifications = [];
  List<Vehicle> myVehicles = [];
  List<RideRequest> myRideRequests = [];
  List<Map<String, dynamic>> searchResults = [];

  bool isLoading = false;
  String? errorMessage;
  int unreadCount = 0;
  bool initializing = true;

  final Set<String> _ratedRideKeys = {};

  CampusUser? userById(String id) {
    if (currentUser?.userId == id) return currentUser;
    return null;
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  Future<T> _guard<T>(Future<T> Function() fn) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await fn();
      return result;
    } on ApiException catch (e) {
      errorMessage = e.message;
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // --- Init / session ---
  Future<void> init({bool force = false}) async {
    initializing = true;
    notifyListeners();
    await repository.api.loadSession();
    if (repository.api.isLoggedIn) {
      try {
        await syncAll();
      } catch (_) {
        // token may be expired; user can log in again
      }
    }
    initializing = false;
    notifyListeners();
  }

  Future<void> syncAll() async {
    await loadCampuses();
    await refreshCurrentUser();
    await Future.wait([
      loadMyRides(),
      loadMyBookings(),
      loadMyVehicles(),
      loadNotifications(),
      loadMyRideRequests(),
    ]);
  }

  // --- Auth ---
  Future<bool> login(String email, String password) {
    return _guard(() async {
      final result = await repository.login(email, password);
      currentUser = result.user;
      notifyListeners();
      await syncAll();
      notifyListeners();
      return true;
    });
  }

  Future<void> logout() async {
    final refresh = repository.api.refreshToken ?? '';
    await repository.logout(refresh);
    currentUser = null;
    myRides = [];
    myBookings = [];
    notifications = [];
    myVehicles = [];
    myRideRequests = [];
    searchResults = [];
    unreadCount = 0;
    notifyListeners();
  }

  Future<CampusUser> register({
    required String name,
    required String email,
    required String studentId,
    String? password,
    String? phone,
    String? department,
    String? semester,
    String? mainCampus,
  }) {
    return _guard(() async {
      final result = await repository.register(
        name: name,
        email: email,
        studentId: studentId,
        password: password,
        phone: phone,
        department: department,
        semester: semester,
        mainCampusId: mainCampus,
      );
      currentUser = result.user;
      notifyListeners();
      await syncAll();
      notifyListeners();
      return result.user;
    });
  }

  Future<void> refreshCurrentUser() async {
    final user = await repository.getCurrentUser();
    currentUser = user;
    notifyListeners();
  }

  // --- Profile ---
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? department,
    String? semester,
  }) {
    return _guard(() async {
      if (currentUser == null) throw ApiException(statusCode: 401, code: 'NO_SESSION', message: 'Not logged in');
      currentUser!
        ..name = name ?? currentUser!.name
        ..phone = phone ?? currentUser!.phone
        ..department = department ?? currentUser!.department
        ..semester = semester ?? currentUser!.semester;
      final updated = await repository.updateProfile(currentUser!);
      currentUser = updated;
      notifyListeners();
    });
  }

  Future<void> setEmergencyContact(String name, String phone) {
    return _guard(() async {
      await repository.setEmergencyContact(name, phone);
      currentUser!
        ..emergencyContactName = name
        ..emergencyContactPhone = phone;
      notifyListeners();
    });
  }

  // --- Campuses ---
  Future<void> loadCampuses() async {
    try {
      await repository.fetchCampuses();
      notifyListeners();
    } catch (_) {
      // keep defaults
    }
  }

  List<Campus> get campuses => repository.campuses;

  String campusName(String id) {
    for (final c in campuses) {
      if (c.campusId == id) return c.campusName;
    }
    return id;
  }

  // --- Verification ---
  Future<void> submitStudentVerification() async {
    // Students are auto-verified at registration on the backend.
    await refreshCurrentUser();
  }

  Future<void> submitDriverVerification() async {
    // Driver verification is handled by admin. Refresh to show latest status.
    await refreshCurrentUser();
  }

  bool canCreateRide() {
    return currentUser?.isDriverVerified ?? false;
  }

  // --- Vehicles ---
  Future<Vehicle> addVehicle({
    required String company,
    required String model,
    required int modelYear,
    required String color,
    required String registrationNumber,
    required int totalSeats,
  }) {
    return _guard(() async {
      final vehicle = await repository.addVehicle(
        company: company,
        model: model,
        modelYear: modelYear,
        color: color,
        registrationNumber: registrationNumber,
        totalSeats: totalSeats,
      );
      myVehicles.add(vehicle);
      notifyListeners();
      return vehicle;
    });
  }

  Future<void> loadMyVehicles() async {
    try {
      myVehicles = await repository.getMyVehicles();
      notifyListeners();
    } catch (_) {}
  }

  List<Vehicle> getMyVehicles() => myVehicles;

  // --- Rides ---
  Future<Ride> createRide({
    required String originCampusId,
    required String destinationCampusId,
    required DateTime departureDate,
    required DateTime departureTime,
    required String vehicleId,
    required int availableSeats,
    required double contributionPerSeat,
    List<String> conditions = const [],
    String additionalNotes = '',
    bool recurringRide = false,
    List<String> recurringDays = const [],
  }) {
    final origin = campusName(originCampusId);
    final destination = campusName(destinationCampusId);
    final departureAt = DateTime(
      departureDate.year,
      departureDate.month,
      departureDate.day,
      departureTime.hour,
      departureTime.minute,
    );
    return _guard(() async {
      final ride = await repository.createRide(
        originCampusId: originCampusId,
        destinationCampusId: destinationCampusId,
        origin: origin,
        destination: destination,
        departureAt: departureAt,
        vehicleId: vehicleId,
        availableSeats: availableSeats,
        contributionPerSeat: contributionPerSeat,
        conditions: conditions,
        additionalNotes: additionalNotes,
        recurring: recurringRide,
        recurringDays: recurringDays,
      );
      myRides.insert(0, ride);
      notifyListeners();
      return ride;
    });
  }

  Future<List<Map<String, dynamic>>> searchRides({
    required String fromCampusId,
    required String toCampusId,
    required DateTime date,
    int? maxDepartureHour,
    int? maxDepartureMinutes,
    int seatsNeeded = 1,
  }) {
    return _guard(() async {
      final results = await repository.searchRides(
        fromCampusId: fromCampusId,
        toCampusId: toCampusId,
        date: date,
        maxDepartureHour: maxDepartureHour,
        maxDepartureMinutes: maxDepartureMinutes,
        seatsNeeded: seatsNeeded,
      );
      searchResults = results;
      notifyListeners();
      return results;
    });
  }

  Future<Ride?> getRideById(String id) async {
    return _guard(() => repository.getRideById(id));
  }

  Future<void> loadMyRides() async {
    try {
      final driverId = currentUser?.userId ?? '';
      final rides = await repository.getRidesByDriver(driverId);
      myRides = rides;
      notifyListeners();
    } catch (_) {}
  }

  Future<Ride> cancelRide(Ride ride) {
    return _guard(() async {
      final updated = await repository.cancelRide(ride.rideId);
      _replaceRide(updated);
      return updated;
    });
  }

  Future<Ride> startRide(Ride ride) {
    return _guard(() async {
      final updated = await repository.startRide(ride.rideId);
      _replaceRide(updated);
      return updated;
    });
  }

  Future<Ride> completeRide(Ride ride) {
    return _guard(() async {
      final updated = await repository.completeRide(ride.rideId);
      _replaceRide(updated);
      return updated;
    });
  }

  void _replaceRide(Ride updated) {
    final idx = myRides.indexWhere((r) => r.rideId == updated.rideId);
    if (idx >= 0) myRides[idx] = updated;
    notifyListeners();
  }

  // --- Ride Requests ---
  Future<RideRequest> createRideRequest({
    required String originCampusId,
    required String destinationCampusId,
    required DateTime preferredDate,
    required int startHour,
    required int startMinute,
    required int latestHour,
    required int latestMinute,
    required DateTime requiredArrivalTime,
    int requiredSeats = 1,
    double maxBudget = 300.0,
  }) {
    final origin = campusName(originCampusId);
    final destination = campusName(destinationCampusId);
    final earliest = DateTime(
      preferredDate.year, preferredDate.month, preferredDate.day, startHour, startMinute,
    );
    final latest = DateTime(
      preferredDate.year, preferredDate.month, preferredDate.day, latestHour, latestMinute,
    );
    return _guard(() async {
      final request = await repository.createRideRequest(
        originCampusId: originCampusId,
        destinationCampusId: destinationCampusId,
        origin: origin,
        destination: destination,
        earliestDeparture: earliest,
        latestDeparture: latest,
        requiredSeats: requiredSeats,
        maxBudget: maxBudget,
      );
      myRideRequests.insert(0, request);
      notifyListeners();
      return request;
    });
  }

  Future<void> loadMyRideRequests() async {
    try {
      myRideRequests = await repository.getMyRideRequests();
      notifyListeners();
    } catch (_) {}
  }

  // --- Bookings ---
  Future<Booking> requestSeat(Ride ride, {int seats = 1, String pickupPoint = 'Campus Gate'}) {
    if (!currentUser!.isStudentVerified) {
      return Future.error(Exception(
          'Your student account must be verified before booking. Register using your university email.'));
    }
    return _guard(() async {
      final booking = await repository.requestBooking(ride.rideId, seats: seats);
      myBookings.insert(0, booking);
      notifyListeners();
      return booking;
    });
  }

  Future<void> acceptBooking(Booking booking) {
    return _guard(() async {
      final updated = await repository.acceptBooking(booking.bookingId);
      _replaceBooking(updated);
    });
  }

  Future<void> rejectBooking(Booking booking) {
    return _guard(() async {
      final updated = await repository.rejectBooking(booking.bookingId);
      _replaceBooking(updated);
    });
  }

  Future<void> cancelBooking(Booking booking) {
    return _guard(() async {
      final updated = await repository.cancelBooking(booking.bookingId);
      _replaceBooking(updated);
    });
  }

  Future<Booking> checkIn(Booking booking, String pin) {
    return _guard(() async {
      final updated = await repository.checkinBooking(booking.bookingId, pin);
      _replaceBooking(updated);
      return updated;
    });
  }

  Future<void> markNoShow(Booking booking) {
    return _guard(() async {
      final updated = await repository.noShowBooking(booking.bookingId);
      _replaceBooking(updated);
    });
  }

  void _replaceBooking(Booking updated) {
    final idx = myBookings.indexWhere((b) => b.bookingId == updated.bookingId);
    if (idx >= 0) {
      myBookings[idx] = updated;
    } else {
      myBookings.add(updated);
    }
    notifyListeners();
  }

  Future<void> loadMyBookings() async {
    try {
      final raw = await repository.getMyBookings();
      myBookings = raw.map((b) => Booking.fromApi(b)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getBookingsByRide(String rideId) async {
    return _guard(() => repository.getBookingsByRide(rideId));
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
  }) {
    return _guard(() async {
      await repository.submitRating(
        rideId: rideId,
        rateeId: rateeId,
        overallRating: overallRating,
        punctuality: punctuality,
        behaviour: behaviour,
        communication: communication,
        comment: comment,
      );
      if (currentUser != null) {
        _ratedRideKeys.add('${currentUser!.userId}:$rideId');
      }
      notifyListeners();
    });
  }

  bool hasRated(String rideId) {
    if (currentUser == null) return false;
    return _ratedRideKeys.contains('${currentUser!.userId}:$rideId');
  }

  // --- Reports ---
  Future<void> submitReport({
    required String reportedUserId,
    String? rideId,
    required ReportReason reason,
    required String description,
  }) {
    return _guard(() => repository.submitReport(
          reportedUserId: reportedUserId,
          rideId: rideId,
          reason: reason,
          description: description,
        ));
  }

  // --- Notifications ---
  Future<void> loadNotifications() async {
    try {
      notifications = await repository.getNotificationsForUser(currentUser?.userId ?? '');
      unreadCount = notifications.where((n) => !n.isRead).length;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllNotificationsRead() {
    return _guard(() async {
      await repository.markAllNotificationsRead();
      for (final n in notifications) {
        n.isRead = true;
      }
      unreadCount = 0;
      notifyListeners();
    });
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await repository.markNotificationRead(id);
      for (final n in notifications) {
        if (n.id == id && !n.isRead) {
          n.isRead = true;
          unreadCount = unreadCount > 0 ? unreadCount - 1 : 0;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  void addNotificationForCurrentUser({
    required String title,
    required String message,
    AppNotificationType type = AppNotificationType.general,
  }) {
    // Local optimistic notification; server sends real ones via events.
  }

  // --- Admin ---
  Map<String, dynamic> adminDashboard = {};
  List<Map<String, dynamic>> adminUsers = [];
  List<Map<String, dynamic>> pendingDrivers = [];
  List<Map<String, dynamic>> pendingVehicles = [];
  List<Map<String, dynamic>> adminReports = [];

  Future<void> loadAdminDashboard() async {
    adminDashboard = await repository.getAdminDashboard();
    notifyListeners();
  }

  Future<void> loadAdminUsers() async {
    adminUsers = await repository.getAdminUsers();
    notifyListeners();
  }

  Future<void> loadPendingDrivers() async {
    pendingDrivers = await repository.getPendingDrivers();
    notifyListeners();
  }

  Future<void> loadPendingVehicles() async {
    pendingVehicles = await repository.getPendingVehicles();
    notifyListeners();
  }

  Future<void> loadAdminReports() async {
    adminReports = await repository.getAdminReports();
    notifyListeners();
  }

  Future<void> verifyStudent(String userId) {
    return _guard(() async {
      await repository.adminVerifyStudent(userId);
      await refreshCurrentUser();
    });
  }

  Future<void> verifyDriver(String userId) {
    return _guard(() async {
      await repository.adminVerifyDriver(userId);
      await Future.wait([loadPendingDrivers(), loadAdminUsers()]);
    });
  }

  Future<void> verifyVehicle(String vehicleId) {
    return _guard(() async {
      await repository.adminVerifyVehicle(vehicleId);
      await loadPendingVehicles();
    });
  }

  Future<void> suspendUser(String userId) {
    return _guard(() async {
      await repository.adminSuspendUser(userId);
      await loadAdminUsers();
    });
  }

  Future<void> resolveReport(String reportId, {String? status, String? adminAction}) {
    return _guard(() async {
      await repository.adminResolveReport(reportId, status: status, adminAction: adminAction);
      await Future.wait([loadAdminReports(), loadAdminDashboard()]);
    });
  }

  // --- Formatting ---
  String formatTime(DateTime time) {
    final h = time.hour > 12 ? time.hour - 12 : time.hour;
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '${h == 0 ? 12 : h}:${time.minute.toString().padLeft(2, '0')} $suffix';
  }

  String formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}