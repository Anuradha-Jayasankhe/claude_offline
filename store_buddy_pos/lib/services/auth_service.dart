import 'dart:convert';

import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _apiClient;

  static const String _platformEmail = 'admin@storebuddy.com';
  static const String _platformPassword = 'admin123';
  static const String _storeLoginsKey = 'store_logins';

  AuthService(this._apiClient);

  Future<void> _storeSessionUser(User user, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('refresh_token', 'local-refresh-token');
    await prefs.setString('user_data', jsonEncode(user.toJson()));

    if (user.tenantId != 'platform') {
      await prefs.setString('tenant_id', user.tenantId);
    }
  }

  Future<User?> login(
    String email,
    String password, {
    bool isPlatform = false,
  }) async {
    if (isPlatform) {
      if (email == _platformEmail && password == _platformPassword) {
        final user = User(
          id: 'platform-admin-1',
          tenantId: 'platform',
          name: 'Platform Admin',
          email: email,
          role: 'platform_admin',
          isActive: true,
        );

        await _storeSessionUser(user, 'platform-session-token');
        return user;
      }
      return null;
    }

    final storeLogins = await getStoreLogins();
    final matched = storeLogins.where((entry) {
      return entry['email'] == email && entry['password'] == password;
    }).toList();

    if (matched.isEmpty) {
      return null;
    }

    final account = matched.first;
    final tenantId = account['tenantId'] ?? '';
    final storeName = account['storeName'] ?? 'Store';
    final userName = account['userName'] ?? storeName;
    final role = (account['role'] ?? 'manager').toString();
    final trialEndsAtRaw = account['trialEndsAt'];

    if (tenantId.isEmpty) {
      return null;
    }

    if (trialEndsAtRaw is String && trialEndsAtRaw.isNotEmpty) {
      final trialEndsAt = DateTime.tryParse(trialEndsAtRaw);
      if (trialEndsAt != null && DateTime.now().isAfter(trialEndsAt)) {
        return null;
      }
    }

    final user = User(
      id: 'store-user-$tenantId',
      tenantId: tenantId,
      name: userName,
      email: email,
      role: role,
      isActive: true,
    );

    await _storeSessionUser(user, 'store-session-token-$tenantId');
    return user;
  }

  Future<bool> createStoreLogin({
    required String storeName,
    required String tenantId,
    required String email,
    required String password,
    String role = 'manager',
    String? userName,
    DateTime? trialStartsAt,
    DateTime? trialEndsAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeLoginsKey);
    final List<dynamic> current = raw != null ? jsonDecode(raw) : <dynamic>[];

    final exists = current.any((entry) => entry['email'] == email);
    if (exists) {
      return false;
    }

    current.add({
      'storeName': storeName,
      'tenantId': tenantId,
      'email': email,
      'password': password,
      'role': role,
      'userName': userName ?? storeName,
      'trialStartsAt': trialStartsAt?.toIso8601String(),
      'trialEndsAt': trialEndsAt?.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    });

    await prefs.setString(_storeLoginsKey, jsonEncode(current));
    return true;
  }

  Future<List<Map<String, dynamic>>> getStoreLogins() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeLoginsKey);
    if (raw == null) {
      return <Map<String, dynamic>>[];
    }

    final List<dynamic> decoded = jsonDecode(raw);
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<bool> hasAnyStoreLogins() async {
    final logins = await getStoreLogins();
    return logins.isNotEmpty;
  }

  Future<bool> createTrialStoreOwner({
    required String storeName,
    required String ownerEmail,
    required String ownerPassword,
  }) async {
    final normalizedStore = storeName.trim();
    final normalizedEmail = ownerEmail.trim().toLowerCase();
    final normalizedPassword = ownerPassword.trim();

    if (normalizedStore.isEmpty ||
        normalizedEmail.isEmpty ||
        normalizedPassword.isEmpty) {
      return false;
    }

    final tenantSlug = normalizedStore
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final tenantId = tenantSlug.isEmpty
        ? 'store-${DateTime.now().millisecondsSinceEpoch}'
        : tenantSlug;

    final trialStart = DateTime.now();
    final trialEnd = trialStart.add(const Duration(days: 7));

    return createStoreLogin(
      storeName: normalizedStore,
      tenantId: tenantId,
      email: normalizedEmail,
      password: normalizedPassword,
      trialStartsAt: trialStart,
      trialEndsAt: trialEnd,
    );
  }

  Future<User?> register(
    String name,
    String email,
    String password,
    String role,
  ) async {
    try {
      final response = await _apiClient.post(
        '/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'role': role,
        },
      );

      if (response.statusCode == 201) {
        return User.fromJson(response.data['user']);
      }
    } catch (_) {}

    return null;
  }

  Future<User?> getProfile() async {
    try {
      final response = await _apiClient.get('/auth/profile');
      if (response.statusCode == 200) {
        return User.fromJson(response.data);
      }
    } catch (_) {}

    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_data');
    await prefs.remove('tenant_id');
  }

  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData != null) {
      return User.fromJson(jsonDecode(userData));
    }

    return null;
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return token != null && !isTokenExpired(token);
  }

  bool isTokenExpired(String token) {
    if (token.startsWith('platform-session-token') ||
        token.startsWith('store-session-token-')) {
      return false;
    }

    try {
      return JwtDecoder.isExpired(token);
    } catch (_) {
      return true;
    }
  }

  Future<String?> getTenantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('tenant_id');
  }
}
