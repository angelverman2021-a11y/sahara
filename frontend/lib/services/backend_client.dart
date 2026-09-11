import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// HTTP Client for SAHARA Cloud & LAN Backend Server.
/// Uses standard dart:io HttpClient (zero third-party dependencies).
class BackendClient {
  static const String prefKeyBackendUrl = 'sahara_backend_url';
  static const String envBackendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  String _baseUrl;

  BackendClient({String? initialUrl}) : _baseUrl = initialUrl ?? envBackendUrl;

  String get baseUrl => _baseUrl;

  void setBaseUrl(String newUrl) {
    var trimmed = newUrl.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    _baseUrl = trimmed;
  }

  /// Loads saved backend URL from local storage or defaults to environment.
  static Future<String> getStoredBackendUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefKeyBackendUrl);
      if (saved != null && saved.trim().isNotEmpty) {
        return saved.trim();
      }
    } catch (_) {}
    return envBackendUrl;
  }

  /// Saves custom backend URL to persistent local storage.
  static Future<void> saveStoredBackendUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var trimmed = url.trim();
      if (trimmed.endsWith('/')) {
        trimmed = trimmed.substring(0, trimmed.length - 1);
      }
      await prefs.setString(prefKeyBackendUrl, trimmed);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Internal HTTP Helpers
  // ---------------------------------------------------------------------------

  HttpClient _createHttpClient() {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    return client;
  }

  Future<Map<String, dynamic>?> _getJson(String path) async {
    final client = _createHttpClient();
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');

      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<List<dynamic>?> _getListJson(String path) async {
    final client = _createHttpClient();
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');

      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as List<dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>?> _postJson(String path, dynamic bodyData, {int expectedStatus = 200}) async {
    final client = _createHttpClient();
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final request = await client.postUrl(uri).timeout(const Duration(seconds: 5));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');

      final payloadBytes = utf8.encode(jsonEncode(bodyData));
      request.headers.set(HttpHeaders.contentLengthHeader, payloadBytes.length.toString());
      request.add(payloadBytes);

      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode == expectedStatus || (response.statusCode >= 200 && response.statusCode < 300)) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Public API Endpoints
  // ---------------------------------------------------------------------------

  /// GET /health — Checks server reachability
  Future<bool> checkHealth() async {
    final res = await _getJson('/health');
    return res != null && res['status'] == 'ok';
  }

  /// POST /api/users — Registers or updates a user profile
  Future<Map<String, dynamic>?> registerUser({
    required String name,
    required String phone,
    String status = 'SAFE',
    String? userId,
  }) async {
    final payload = {
      'name': name,
      'phone': phone,
      'status': status,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
    };
    return _postJson('/api/users', payload, expectedStatus: 201);
  }

  /// `GET /api/lookup/phone/<phone>` — Phone number lookup for discovery
  Future<Map<String, dynamic>?> lookupByPhone(String phone) async {
    final encoded = Uri.encodeComponent(phone);
    return _getJson('/api/lookup/phone/$encoded');
  }

  /// `GET /api/users/<user_id>` — Retrieves user profile
  Future<Map<String, dynamic>?> getUser(String userId) async {
    return _getJson('/api/users/$userId');
  }

  /// `POST /api/users/<user_id>/status` — Updates user status
  Future<Map<String, dynamic>?> updateUserStatus(String userId, String status) async {
    return _postJson('/api/users/$userId/status', {'status': status});
  }

  /// `POST /api/family` — Links a family member
  Future<Map<String, dynamic>?> addFamilyLink({
    required String familyId,
    required String userId,
    required String familyMemberId,
    required String relationship,
  }) async {
    final payload = {
      'family_id': familyId,
      'user_id': userId,
      'family_member_id': familyMemberId,
      'relationship': relationship,
    };
    return _postJson('/api/family', payload, expectedStatus: 201);
  }

  /// `GET /api/family/<user_id>` — Retrieves family members
  Future<List<Map<String, dynamic>>> getFamilyMembers(String userId) async {
    final list = await _getListJson('/api/family/$userId');
    if (list == null) return [];
    return list.cast<Map<String, dynamic>>();
  }

  /// `POST /api/sync/messages` — Batch synchronizes offline messages
  Future<Map<String, dynamic>?> syncMessages(List<Map<String, dynamic>> messages) async {
    if (messages.isEmpty) return {'synced': 0, 'duplicates': 0, 'total': 0};
    return _postJson('/api/sync/messages', messages);
  }

  /// `GET /api/messages/<user_id>` — Retrieves synced messages for this user
  Future<List<Map<String, dynamic>>> getSyncedMessages(String userId) async {
    final list = await _getListJson('/api/messages/$userId');
    if (list == null) return [];
    return list.cast<Map<String, dynamic>>();
  }

  /// `POST /api/sync/emergency` — Batch synchronizes emergency reports
  Future<Map<String, dynamic>?> syncEmergencyReports(List<Map<String, dynamic>> reports) async {
    if (reports.isEmpty) return {'synced': 0, 'duplicates': 0, 'total': 0};
    return _postJson('/api/sync/emergency', reports);
  }

  /// `GET /api/emergency/feed` — Retrieves priority emergency feed
  Future<List<Map<String, dynamic>>> getEmergencyFeed() async {
    final list = await _getListJson('/api/emergency/feed');
    if (list == null) return [];
    return list.cast<Map<String, dynamic>>();
  }
}
