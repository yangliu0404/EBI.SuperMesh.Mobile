import 'package:dio/dio.dart';
import 'package:ebi_models/ebi_models.dart';
import 'package:ebi_core/src/auth/auth_repository.dart';
import 'package:ebi_core/src/auth/token_storage.dart';
import 'package:ebi_core/src/config/app_config.dart';
import 'package:ebi_core/src/network/api_endpoints.dart';

/// Real ABP backend implementation of [AuthRepository].
class AbpAuthRepository implements AuthRepository {
  final Dio _dio;
  final TokenStorage _tokenStorage;
  final String clientId;

  AbpAuthRepository({
    required Dio dio,
    required TokenStorage tokenStorage,
    required this.clientId,
  })  : _dio = dio,
        _tokenStorage = tokenStorage;

  @override
  Future<List<Tenant>> getTenants() async {
    // ABP does not have a "list all tenants" endpoint.
    // Return empty list; use findTenantByName instead.
    return const [];
  }

  @override
  Future<FindTenantResult> findTenantByName(String name) async {
    try {
      final response = await _dio.get(ApiEndpoints.tenantByName(name));
      final data = response.data as Map<String, dynamic>;
      return FindTenantResult.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const FindTenantResult(success: false);
      }
      rethrow;
    }
  }

  @override
  Future<AuthTokens> login({
    required String username,
    required String password,
    String? tenantId,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.connectToken,
      data: {
        'grant_type': 'password',
        'client_id': clientId,
        'username': username,
        'password': password,
        'scope': AppConfig.defaultScopes,
      },
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        // Don't attach Bearer token for the token endpoint.
        extra: {'ignoreToken': true},
      ),
    );

    final data = response.data as Map<String, dynamic>;

    // Check for OAuth2 error response.
    if (data.containsKey('error')) {
      throw Exception(
        data['error_description'] as String? ??
            data['error'] as String? ??
            'Authentication failed',
      );
    }

    return AuthTokens.fromOAuthResponse(data);
  }

  @override
  Future<void> logout() async {
    try {
      final token = await _tokenStorage.getAccessToken();
      if (token != null) {
        await _dio.post(
          ApiEndpoints.connectRevocation,
          data: {
            'token': token,
            'token_type_hint': 'access_token',
            'client_id': clientId,
          },
          options: Options(
            contentType: 'application/x-www-form-urlencoded',
          ),
        );
      }
    } catch (_) {
      // Ignore revocation errors — clear tokens regardless.
    }
    await _tokenStorage.clearTokens();
  }

  @override
  Future<User> getProfile() async {
    final response = await _dio.get(ApiEndpoints.connectUserInfo);
    final data = response.data as Map<String, dynamic>;
    return User.fromUserInfo(data);
  }
}
