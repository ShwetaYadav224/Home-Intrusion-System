import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/alert_polling_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isLoggedIn = false;
  Map<String, dynamic>? _user;
  String? _error;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  Map<String, dynamic>? get user => _user;
  String? get error => _error;

  String get displayName {
    if (_user == null) return '';
    final first = _user!['first_name'] ?? '';
    final last = _user!['last_name'] ?? '';
    final full = '$first $last'.trim();
    return full.isNotEmpty ? full : _user!['username'] ?? '';
  }

  String get role => _user?['role'] ?? 'member';
  Map<String, dynamic>? get household => _user?['household'];

  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    final loggedIn = await ApiClient.isLoggedIn;
    if (loggedIn) {
      final resp = await AuthService.getProfile();
      if (resp.success) {
        _user = resp.data;
        _isLoggedIn = true;
        await AlertPollingService.startPolling();
      } else {
        await ApiClient.clearTokens();
        await AlertPollingService.stopPolling();
        _isLoggedIn = false;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final resp = await AuthService.login(identifier: identifier, password: password);

    if (resp.success) {
      _user = resp.data['user'];
      _isLoggedIn = true;
      _error = null;
      await AlertPollingService.startPolling();
    } else {
      _error = resp.message;
    }

    _isLoading = false;
    notifyListeners();
    return resp.success;
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    String firstName = '',
    String lastName = '',
    String phone = '',
    String? householdName,
    String? inviteCode,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final resp = await AuthService.register(
      username: username,
      email: email,
      password: password,
      passwordConfirm: passwordConfirm,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      householdName: householdName,
      inviteCode: inviteCode,
    );

    if (resp.success) {
      _user = resp.data['user'];
      _isLoggedIn = true;
      _error = null;
      await AlertPollingService.startPolling();
    } else {
      _error = resp.message;
    }

    _isLoading = false;
    notifyListeners();
    return resp.success;
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await AuthService.logout();
    await AlertPollingService.stopPolling();
    _user = null;
    _isLoggedIn = false;
    _error = null;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    final resp = await AuthService.getProfile();
    if (resp.success) {
      _user = resp.data;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
