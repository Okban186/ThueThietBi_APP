abstract interface class AuthTokenStorage {
  Future<String?> getAccessToken();

  Future<String?> getRefreshToken();

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });

  Future<void> clearTokens();
}
