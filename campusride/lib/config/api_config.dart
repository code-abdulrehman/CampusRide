import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  ApiConfig._();

  static const String _baseUrlKey = 'api_base_url';

  // Android emulator -> host machine at 10.0.2.2. iOS sim -> localhost.
  // Override at build time with: --dart-define=API_BASE_URL=http://<host>:3000/api/v1
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );

  static String _baseUrl = defaultBaseUrl;

  static String get baseUrl => _baseUrl;

  static String get wsUrl {
    final base = _baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
    final ws = base.startsWith('https') ? base.replaceFirst('https', 'wss') : base.replaceFirst('http', 'ws');
    return '$ws/ws';
  }

  static void setBaseUrl(String url) {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.isEmpty) return;
    _baseUrl = clean.endsWith('/api/v1') ? clean : '$clean/api/v1';
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_baseUrlKey, _baseUrl));
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_baseUrlKey);
    if (saved != null && saved.isNotEmpty) {
      _baseUrl = saved;
    }
  }
}

class ApiPaths {
  ApiPaths._();

  // Auth
  static const register = '/auth/register';
  static const login = '/auth/login';
  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';

  // Users
  static const me = '/users/me';
  static const bootstrap = '/users/bootstrap';
  static const profile = '/users/profile';
  static const emergencyContact = '/users/emergency-contact';

  // Campuses
  static const campuses = '/campuses';

  // Vehicles
  static const vehicles = '/vehicles';

  // Rides
  static const rides = '/rides';
  static const rideSearch = '/rides/search';
  static const ridesMine = '/rides/mine';

  // Ride requests
  static const rideRequests = '/ride-requests';
  static const rideRequestsMine = '/ride-requests/mine';

  // Bookings
  static const bookingsMine = '/bookings/mine';

  // Notifications
  static const notifications = '/notifications';
  static const notificationsReadAll = '/notifications/read-all';

  static String rideUpdate(String id) => '$rides/$id';
  static String rideCancel(String id) => '$rides/$id/cancel';
  static String rideStart(String id) => '$rides/$id/start';
  static String rideComplete(String id) => '$rides/$id/complete';
  static String rideDetail(String id) => '$rides/$id';
  static String rideLatestLocation(String id) => '$rides/$id/latest-location';
  static String rideBookings(String id) => '$rides/$id/bookings';
  static String bookingForRide(String rideId) => '$rides/$rideId/bookings';

  static String bookingDetail(String id) => '/bookings/$id';
  static String bookingAccept(String id) => '/bookings/$id/accept';
  static String bookingReject(String id) => '/bookings/$id/reject';
  static String bookingCancel(String id) => '/bookings/$id/cancel';
  static String bookingCheckin(String id) => '/bookings/$id/checkin';
  static String bookingNoShow(String id) => '/bookings/$id/no-show';

  static String reportCreate() => '/reports';

  static String notificationRead(String id) => '/notifications/$id/read';

  // Admin
  static const adminDashboard = '/admin/dashboard';
  static const adminUsers = '/admin/users';
  static const adminReports = '/admin/reports';
}