import 'package:flutter/foundation.dart';
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
import '../models/campus.dart';
import '../services/data_repository.dart';

class AppStateProvider extends ChangeNotifier {
  final DataRepository repository = DataRepository.instance;

  CampusUser? currentUser;
  int _idCounter = 1000;

  String _nextId(String prefix) => '$prefix${++_idCounter}';

  // --- Auth ---
  bool login(String email, {String? password}) {
    final user = repository.login(email, password ?? '');
    if (user == null) return false;
    currentUser = user;
    notifyListeners();
    return true;
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  CampusUser register({
    required String name,
    required String email,
    required String studentId,
    String? phone,
    String? department,
    String? semester,
    String? mainCampus,
  }) {
    final user = CampusUser(
      userId: _nextId('u'),
      name: name,
      email: email,
      phone: phone ?? '',
      studentId: studentId,
      department: department ?? '',
      semester: semester ?? '',
      mainCampus: mainCampus ?? 'Campus A',
      verificationStatus: UserVerificationStatus.studentPending,
    );
    repository.addUser(user);
    currentUser = user;
    repository.addNotification(AppNotification(
      id: _nextId('n'),
      userId: user.userId,
      title: 'Welcome to CampusRide!',
      message: 'Your student verification is in progress. An admin will review it soon.',
      type: AppNotificationType.general,
    ));
    notifyListeners();
    return user;
  }

  void updateProfile(CampusUser updated) {
    repository.addUser(updated);
    currentUser = repository.getUserById(updated.userId);
    notifyListeners();
  }

  void setEmergencyContact(String name, String phone) {
    if (currentUser == null) return;
    currentUser!.emergencyContactName = name;
    currentUser!.emergencyContactPhone = phone;
    repository.addUser(currentUser!);
    notifyListeners();
  }

  // --- Verification ---
  void submitStudentVerification() {
    if (currentUser == null) return;
    currentUser!.verificationStatus = UserVerificationStatus.studentVerified;
    repository.addUser(currentUser!);
    repository.addNotification(AppNotification(
      id: _nextId('n'),
      userId: currentUser!.userId,
      title: 'Student Verified',
      message: 'Congratulations! Your student account has been verified. You can now book rides.',
      type: AppNotificationType.general,
    ));
    notifyListeners();
  }

  void submitDriverVerification() {
    if (currentUser == null) return;
    currentUser!.verificationStatus = UserVerificationStatus.driverVerified;
    repository.addUser(currentUser!);
    repository.addNotification(AppNotification(
      id: _nextId('n'),
      userId: currentUser!.userId,
      title: 'Driver Verified',
      message: 'You are now a verified driver on CampusRide!',
      type: AppNotificationType.general,
    ));
    notifyListeners();
  }

  // --- Vehicle ---
  Vehicle addVehicle({
    required String company,
    required String model,
    required int modelYear,
    required String color,
    required String registrationNumber,
    required int totalSeats,
  }) {
    final vehicle = Vehicle(
      vehicleId: _nextId('v'),
      ownerUserId: currentUser?.userId ?? '',
      company: company,
      model: model,
      modelYear: modelYear,
      color: color,
      registrationNumber: registrationNumber,
      totalSeats: totalSeats,
      passengerCapacity: totalSeats - 1,
    );
    repository.addVehicle(vehicle);
    repository.addNotification(AppNotification(
      id: _nextId('n'),
      userId: currentUser?.userId ?? '',
      title: 'Vehicle Submitted',
      message: 'Your vehicle (${vehicle.displayName}) is pending verification by the admin.',
      type: AppNotificationType.general,
    ));
    notifyListeners();
    return vehicle;
  }

  bool canCreateRide() {
    return currentUser?.isDriverVerified ?? false;
  }

  List<Vehicle> getMyVehicles() {
    final uid = currentUser?.userId ?? '';
    return repository.getVehiclesByOwner(uid);
  }

  // --- Rides ---
  Ride createRide({
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
    final originCampus = _campusName(originCampusId);
    final destinationCampus = _campusName(destinationCampusId);
    final ride = Ride(
      rideId: _nextId('r'),
      driverId: currentUser?.userId ?? '',
      vehicleId: vehicleId,
      origin: originCampus,
      destination: destinationCampus,
      originCampusId: originCampusId,
      destinationCampusId: destinationCampusId,
      departureDate: departureDate,
      departureTime: departureTime,
      availableSeats: availableSeats,
      contributionPerSeat: contributionPerSeat,
      conditions: conditions,
      additionalNotes: additionalNotes,
      recurringRide: recurringRide,
      recurringDays: recurringDays,
    );
    repository.addRide(ride);
    _notifyRideSeekers(ride);
    notifyListeners();
    return ride;
  }

  String _campusName(String id) {
    for (final c in Campus.sampleCampuses) {
      if (c.campusId == id) return c.campusName;
    }
    return id;
  }

  void _notifyRideSeekers(Ride ride) {
    final matching = repository.rideRequests.where((req) {
      return req.requestStatus == RequestStatus.pending &&
          req.origin == _campusName(ride.originCampusId) &&
          req.destination == _campusName(ride.destinationCampusId);
    });
    for (final req in matching) {
      repository.addNotification(AppNotification(
        id: _nextId('n'),
        userId: req.studentId,
        title: 'New Ride Available!',
        message: 'A ride from ${ride.origin} to ${ride.destination} at ${formatTime(ride.departureTime)} is now available.',
        type: AppNotificationType.general,
        relatedRideId: ride.rideId,
      ));
    }
  }

  // --- Ride Request ---
  RideRequest createRideRequest({
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
    final request = RideRequest(
      requestId: _nextId('req'),
      studentId: currentUser?.userId ?? '',
      origin: _campusName(originCampusId),
      destination: _campusName(destinationCampusId),
      preferredDate: preferredDate,
      preferredStartTime: TimeOfDay(hour: startHour, minute: startMinute),
      latestDepartureTime: TimeOfDay(hour: latestHour, minute: latestMinute),
      requiredArrivalTime: requiredArrivalTime,
      requiredSeats: requiredSeats,
      maximumBudget: maxBudget,
    );
    repository.addRideRequest(request);
    notifyListeners();
    return request;
  }

  // --- Booking ---
  Booking requestSeat(Ride ride, {int seats = 1, String pickupPoint = 'Campus Gate'}) {
    if (!currentUser!.isStudentVerified) {
      throw Exception('Your student account must be verified before booking. Verify in your profile first.');
    }
    final booking = Booking(
      bookingId: _nextId('b'),
      rideId: ride.rideId,
      passengerId: currentUser?.userId ?? '',
      driverId: ride.driverId,
      status: BookingStatus.requested,
      seatsBooked: seats,
      amountPaid: ride.contributionPerSeat * seats,
      pickupPoint: pickupPoint,
    );
    repository.addBooking(booking);
    repository.addNotification(AppNotification(
      id: _nextId('n'),
      userId: ride.driverId,
      title: 'New Seat Request',
      message: '${currentUser?.name} requested $seats seat(s) on your ${ride.origin} → ${ride.destination} ride.',
      type: AppNotificationType.rideRequest,
      relatedRideId: ride.rideId,
    ));
    notifyListeners();
    return booking;
  }

  void acceptBooking(Booking booking) {
    repository.updateBookingStatus(booking.bookingId, BookingStatus.accepted);
    repository.updateRideSeats(booking.rideId, booking.seatsBooked);
    final ride = repository.getRideById(booking.rideId);
    repository.addNotification(AppNotification(
      id: _nextId('n'),
      userId: booking.passengerId,
      title: 'Seat Confirmed!',
      message: 'Your seat on ${ride?.origin} → ${ride?.destination} has been confirmed. Ride PIN: ${ride?.ridePin}',
      type: AppNotificationType.rideAccepted,
      relatedRideId: booking.rideId,
    ));
    notifyListeners();
  }

  void rejectBooking(Booking booking) {
    repository.updateBookingStatus(booking.bookingId, BookingStatus.rejected);
    repository.addNotification(AppNotification(
      id: _nextId('n'),
      userId: booking.passengerId,
      title: 'Booking Rejected',
      message: 'The driver could not accept your booking request.',
      type: AppNotificationType.rideRejected,
    ));
    notifyListeners();
  }

  void cancelBooking(Booking booking) {
    final wasAccepted = booking.status == BookingStatus.accepted ||
        booking.status == BookingStatus.checkedIn ||
        booking.status == BookingStatus.rideStarted;
    repository.updateBookingStatus(booking.bookingId, BookingStatus.cancelled);
    if (wasAccepted) {
      final ride = repository.getRideById(booking.rideId);
      if (ride != null && ride.rideStatus != RideStatus.completed) {
        ride.availableSeats += booking.seatsBooked;
        ride.rideStatus = RideStatus.open;
      }
      final driver = repository.getUserById(ride?.driverId ?? '');
      if (driver != null && driver.userId == currentUser?.userId) {
        driver.cancelledRides++;
        repository.addUser(driver);
      }
    }
    repository.addNotification(AppNotification(
      id: _nextId('n'),
      userId: booking.driverId,
      title: 'Booking Cancelled',
      message: 'A passenger cancelled their seat on your ride. A seat has been freed up.',
      type: AppNotificationType.general,
      relatedRideId: booking.rideId,
    ));
    notifyListeners();
  }

  void checkIn(Booking booking, String pin) {
    final ride = repository.getRideById(booking.rideId);
    if (pin.trim() != ride?.ridePin) {
      throw Exception('Invalid PIN. Please verify the ride PIN with your driver.');
    }
    repository.updateBookingStatus(booking.bookingId, BookingStatus.checkedIn);
    notifyListeners();
  }

  void startRide(Ride ride) {
    ride.rideStatus = RideStatus.started;
    for (final b in repository.getBookingsByRide(ride.rideId)) {
      if (b.status == BookingStatus.accepted || b.status == BookingStatus.checkedIn) {
        b.status = BookingStatus.rideStarted;
      }
      repository.addNotification(AppNotification(
        id: _nextId('n'),
        userId: b.passengerId,
        title: 'Ride Started',
        message: 'Your ride ${ride.origin} → ${ride.destination} has started. Stay safe!',
        type: AppNotificationType.rideStarted,
        relatedRideId: ride.rideId,
      ));
    }
    notifyListeners();
  }

  void completeRide(Ride ride) {
    ride.rideStatus = RideStatus.completed;
    for (final b in repository.getBookingsByRide(ride.rideId)) {
      if (b.status == BookingStatus.accepted ||
          b.status == BookingStatus.checkedIn ||
          b.status == BookingStatus.rideStarted) {
        b.status = BookingStatus.completed;
      }
    }
    final driver = repository.getUserById(ride.driverId);
    if (driver != null) driver.completedRides++;
    notifyListeners();
  }

  void markNoShow(Booking booking) {
    repository.updateBookingStatus(booking.bookingId, BookingStatus.noShow);
    notifyListeners();
  }

  // --- Ratings ---
  void submitRating({
    required String rideId,
    required String rateeId,
    required double overallRating,
    required double punctuality,
    required double behaviour,
    required double communication,
    String comment = '',
  }) {
    final rating = UserRating(
      ratingId: _nextId('rt'),
      rideId: rideId,
      raterId: currentUser?.userId ?? '',
      rateeId: rateeId,
      overallRating: overallRating,
      punctuality: punctuality,
      behaviour: behaviour,
      communication: communication,
      comment: comment,
    );
    repository.addRating(rating);
    if (currentUser != null) {
      // mark that this user rated this ride to avoid duplicates in UI
      _ratedRideKeys.add('${currentUser!.userId}:$rideId');
    }
    notifyListeners();
  }

  bool hasRated(String rideId) {
    if (currentUser == null) return false;
    return _ratedRideKeys.contains('${currentUser!.userId}:$rideId');
  }

  final Set<String> _ratedRideKeys = {};

  // --- Reports ---
  void submitReport({
    required String reportedUserId,
    String? rideId,
    required ReportReason reason,
    required String description,
  }) {
    final report = UserReport(
      reportId: _nextId('rep'),
      reporterId: currentUser?.userId ?? '',
      reportedUserId: reportedUserId,
      rideId: rideId,
      reason: reason,
      description: description,
    );
    repository.addReport(report);
    notifyListeners();
  }

  // --- Admin Actions ---
  void verifyStudent(String userId) {
    final user = repository.getUserById(userId);
    if (user != null) {
      user.verificationStatus = UserVerificationStatus.studentVerified;
      repository.addUser(user);
      repository.addNotification(AppNotification(
        id: _nextId('n'),
        userId: user.userId,
        title: 'Verified!',
        message: 'Your student verification has been approved.',
        type: AppNotificationType.general,
      ));
    }
    notifyListeners();
  }

  void verifyDriver(String userId) {
    final user = repository.getUserById(userId);
    if (user != null) {
      user.verificationStatus = UserVerificationStatus.driverVerified;
      repository.addUser(user);
      repository.addNotification(AppNotification(
        id: _nextId('n'),
        userId: user.userId,
        title: 'Driver Verified',
        message: 'Your driver profile has been approved.',
        type: AppNotificationType.general,
      ));
    }
    notifyListeners();
  }

  void verifyVehicle(String vehicleId) {
    final vehicle = repository.getVehicleById(vehicleId);
    if (vehicle != null) {
      vehicle.verificationStatus = VehicleStatus.verified;
      vehicle.vehicleStatus = VehicleStatus.verified;
      repository.addNotification(AppNotification(
        id: _nextId('n'),
        userId: vehicle.ownerUserId,
        title: 'Vehicle Verified',
        message: '${vehicle.displayName} has been approved.',
        type: AppNotificationType.general,
      ));
    }
    notifyListeners();
  }

  void suspendUser(String userId) {
    final user = repository.getUserById(userId);
    if (user != null) user.accountStatus = AccountStatus.suspended;
    notifyListeners();
  }

  void resolveReport(String reportId, ReportStatus status) {
    final report = repository.reports.firstWhere((r) => r.reportId == reportId);
    report.status = status;
    if (status == ReportStatus.permanentBan) {
      suspendUser(report.reportedUserId);
    }
    notifyListeners();
  }

  void markAllNotificationsRead() {
    if (currentUser == null) return;
    for (final n in repository.getNotificationsForUser(currentUser!.userId)) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void addNotificationForCurrentUser({
    required String title,
    required String message,
    AppNotificationType type = AppNotificationType.general,
  }) {
    if (currentUser == null) return;
    repository.addNotification(AppNotification(
      id: _nextId('n'),
      userId: currentUser!.userId,
      title: title,
      message: message,
      type: type,
    ));
    notifyListeners();
  }

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