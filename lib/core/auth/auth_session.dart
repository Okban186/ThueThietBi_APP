import 'package:flutter/foundation.dart';
import 'package:thuethietbi_app/features/auth/data/models/user.dart';

import '../storage/secure_storage.dart';
import 'auth_token_storage.dart';

class AuthSession extends ChangeNotifier implements AuthTokenStorage {
  AuthSession({required SecureStorage secureStorage})
    : _secureStorage = secureStorage;

  final SecureStorage _secureStorage;

  User? _currentUser;
  String? _accessToken;
  String? _refreshToken;

  User? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  bool get isAuthenticated =>
      _accessToken != null && _accessToken!.isNotEmpty && _currentUser != null;

  @override
  Future<String?> getAccessToken() async {
    return _accessToken;
  }

  @override
  Future<String?> getRefreshToken() async {
    return _refreshToken;
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    _accessToken = accessToken;
    _refreshToken = refreshToken;

    notifyListeners();
  }

  @override
  Future<void> clearTokens() async {
    await _secureStorage.clearTokens();

    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;

    notifyListeners();
  }

  Future<void> restoreTokens() async {
    _accessToken = await _secureStorage.getAccessToken();
    _refreshToken = await _secureStorage.getRefreshToken();

    notifyListeners();
  }

  Future<void> startSession({
    required String accessToken,
    required String refreshToken,
    required User user,
  }) async {
    await saveTokens(accessToken: accessToken, refreshToken: refreshToken);

    _currentUser = user;
    notifyListeners();
  }

  Future<void> endSession() async {
    await clearTokens();
  }

  void setCurrentUser(User user) {
    _currentUser = user;
    notifyListeners();
  }
}
