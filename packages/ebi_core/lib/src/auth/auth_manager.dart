import 'package:ebi_core/src/auth/token_storage.dart';
import 'package:ebi_core/src/network/api_client.dart';
import 'package:ebi_core/src/network/api_endpoints.dart';

/// Manages authentication state and login/logout flows.
class AuthManager {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  AuthManager({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage;

  /// Whether the user currently has a valid token stored.
  Future<bool> get isAuthenticated => _tokenStorage.hasValidToken();

  /// Log in with email/phone and password.
  Future<Map<String, dynamic>> login({
    required String account,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.connectToken,
      data: {
        'account': account,
        'password': password,
      },
    );

    final data = response.data as Map<String, dynamic>;
    await _tokenStorage.saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String? ?? '',
    );

    return data;
  }

  /// Log out and clear stored tokens.
  Future<void> logout() async {
    try {
      await _apiClient.post(ApiEndpoints.connectRevocation);
    } catch (_) {
      // Ignore errors during logout — clear tokens regardless.
    }
    await _tokenStorage.clearTokens();
  }

  /// Fetch the current user's profile.
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _apiClient.get(ApiEndpoints.connectUserInfo);
    return response.data as Map<String, dynamic>;
  }
}
