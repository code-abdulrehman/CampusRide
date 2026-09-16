import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String code;
  final String message;
  final Map<String, dynamic>? fields;

  ApiException({
    this.statusCode,
    required this.code,
    required this.message,
    this.fields,
  });

  @override
  String toString() =>
      fields != null ? '$message (${fields.toString()})' : message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _tokenKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';

  String? _accessToken;
  String? _refreshToken;

  bool get isLoggedIn => _accessToken != null;

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshKey);
  }

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? expiresIn,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    await prefs.setString(_refreshKey, refreshToken);
    if (expiresIn != null) {
      final exp = DateTime.now().add(Duration(seconds: int.tryParse(expiresIn) ?? 900));
      await prefs.setString('auth_token_expiry', exp.toIso8601String());
    }
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshKey);
    await prefs.remove('auth_token_expiry');
  }

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final uri = query == null || query.isEmpty
        ? _uri(path)
        : _uri(path).replace(queryParameters: query.map((k, v) => MapEntry(k, '$v')));
    return _send(() => http.get(uri, headers: _headers));
  }

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) async {
    final uri = query == null || query.isEmpty
        ? _uri(path)
        : _uri(path).replace(queryParameters: query.map((k, v) => MapEntry(k, '$v')));
    return _send(
      () => http.post(uri, headers: _headers, body: body == null ? null : jsonEncode(body)),
    );
  }

  Future<dynamic> put(String path, {Object? body}) async {
    return _send(() => http.put(_uri(path), headers: _headers, body: body == null ? null : jsonEncode(body)));
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    return _send(() => http.patch(_uri(path), headers: _headers, body: body == null ? null : jsonEncode(body)));
  }

  Future<dynamic> delete(String path) async {
    return _send(() => http.delete(_uri(path), headers: _headers));
  }

  Future<dynamic> _send(Future<http.Response> Function() request, {bool isRetry = false}) async {
    final response = await request();
    final decoded = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final error = _extractError(decoded, response.statusCode);

    if (error.code == 'TOKEN_EXPIRED' && _refreshToken != null && !isRetry) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _send(request, isRetry: true);
      }
    }

    throw error;
  }

  Future<bool> _tryRefresh() async {
    try {
      final refresh = _refreshToken;
      if (refresh == null) return false;
      final response = await http.post(
        _uri('/auth/refresh'),
        headers: _headers,
        body: jsonEncode({'refreshToken': refresh}),
      );
      if (response.statusCode != 200) {
        await clearTokens();
        return false;
      }
      final decoded = _decode(response);
      final data = decoded['data'] as Map<String, dynamic>;
      final tokens = data['tokens'] as Map<String, dynamic>;
      await saveTokens(
        accessToken: tokens['accessToken'] as String,
        refreshToken: tokens['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      await clearTokens();
      return false;
    }
  }

  dynamic _decode(http.Response response) {
    final text = response.body;
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  ApiException _extractError(dynamic decoded, int status) {
    if (decoded is Map<String, dynamic>) {
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        return ApiException(
          statusCode: status,
          code: (error['code'] as String?) ?? 'UNKNOWN',
          message: (error['message'] as String?) ?? 'Request failed',
          fields: error['fields'] is Map<String, dynamic> ? error['fields'] as Map<String, dynamic> : null,
        );
      }
    }
    return ApiException(statusCode: status, code: 'UNKNOWN', message: 'Request failed ($status)');
  }

  // --- WebSocket helpers ---
  Uri wsUriFor(String path) {
    return Uri.parse('${ApiConfig.wsUrl}$path');
  }
}