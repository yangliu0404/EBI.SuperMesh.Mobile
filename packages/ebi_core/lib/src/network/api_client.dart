import 'package:dio/dio.dart';
import 'package:ebi_core/src/auth/token_storage.dart';
import 'package:ebi_core/src/auth/tenant_storage.dart';
import 'package:ebi_core/src/config/app_config.dart';
import 'package:ebi_core/src/network/api_endpoints.dart';
import 'package:ebi_core/src/network/api_exception.dart';
import 'package:ebi_core/src/network/api_response.dart';
import 'package:ebi_core/src/utils/logger.dart';

/// Central API client wrapping Dio with ABP interceptors.
class ApiClient {
  late final Dio _dio;
  final TokenStorage _tokenStorage;
  final TenantStorage _tenantStorage;
  final String clientId;

  /// Callback invoked when token refresh fails (401).
  /// The app should navigate to the login page.
  void Function()? onSessionExpired;

  /// Returns the current language culture name for Accept-Language header.
  String Function()? getLanguage;

  ApiClient({
    required this.clientId,
    required TokenStorage tokenStorage,
    required TenantStorage tenantStorage,
    this.onSessionExpired,
    this.getLanguage,
  })  : _tokenStorage = tokenStorage,
        _tenantStorage = tenantStorage {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseServer,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _TenantInterceptor(_tenantStorage),
      _AcceptLanguageInterceptor(this),
      _AuthInterceptor(
        tokenStorage: _tokenStorage,
        dio: _dio,
        clientId: clientId,
        onSessionExpired: () => onSessionExpired?.call(),
      ),
      _AbpErrorInterceptor(),
      _WrapResultInterceptor(),
      _LoggingInterceptor(),
    ]);
  }

  /// The underlying Dio instance (for advanced use, e.g. SignalR).
  Dio get dio => _dio;

  /// GET request.
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(path,
          queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// POST request.
  Future<Response> post(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    try {
      return await _dio.post(path, data: data, options: options);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// PUT request.
  Future<Response> put(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    try {
      return await _dio.put(path, data: data, options: options);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// DELETE request.
  Future<Response> delete(
    String path, {
    Options? options,
  }) async {
    try {
      return await _dio.delete(path, options: options);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Upload file with multipart.
  Future<Response> upload(
    String path, {
    required String filePath,
    String fieldName = 'file',
    Map<String, dynamic>? extraFields,
  }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath),
        ...?extraFields,
      });
      return await _dio.post(path, data: formData);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Upload file with multipart and progress callback.
  Future<Response> uploadWithProgress(
    String path, {
    required String filePath,
    required String fileName,
    String fieldName = 'file',
    Map<String, dynamic>? extraFields,
    void Function(double progress)? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath, filename: fileName),
        ...?extraFields,
      });
      return await _dio.post(
        path,
        data: formData,
        onSendProgress: onSendProgress != null
            ? (count, total) {
                if (total > 0) {
                  onSendProgress(count / total);
                }
              }
            : null,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Download a file from a URL to a local path.
  ///
  /// The [url] can be absolute or relative (relative is resolved against baseUrl).
  /// Uses Dio internally, so it inherits HttpOverrides (self-signed cert trust).
  Future<void> downloadToFile(
    String url,
    String savePath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onProgress != null
            ? (received, total) {
                if (total > 0) {
                  onProgress(received / total);
                }
              }
            : null,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetch the current user's profile detail (Volo.Abp.Account.ProfileDto).
  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final response = await _dio.get('/api/account/my-profile');
      final data = response.data as Map<String, dynamic>;
      if (data.containsKey('result') && data['result'] is Map<String, dynamic>) {
        return data['result'] as Map<String, dynamic>;
      }
      return data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Update the current user's profile on the server.
  Future<void> updateMyProfile(Map<String, dynamic> data) async {
    try {
      await _dio.put('/api/account/my-profile', data: data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  ApiException _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException.timeout();
      case DioExceptionType.connectionError:
        return ApiException.noConnection();
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        if (statusCode == 401) return ApiException.unauthorized();
        // Try to parse ABP error format.
        if (data is Map<String, dynamic> && data.containsKey('error')) {
          final abpError = AbpErrorResponse.fromJson(data);
          return ApiException(
            statusCode: statusCode,
            message: abpError.fullMessage,
            errorCode: abpError.code,
            data: data,
          );
        }
        return ApiException(
          statusCode: statusCode,
          message: data is Map ? (data['message']?.toString() ?? 'Request failed') : 'Request failed',
          errorCode: data is Map ? data['error']?.toString() : null,
          data: data,
        );
      default:
        return ApiException(message: e.message ?? 'Unknown error');
    }
  }
}

/// Injects `__tenant` header for ABP multi-tenancy.
class _TenantInterceptor extends Interceptor {
  final TenantStorage _tenantStorage;

  _TenantInterceptor(this._tenantStorage);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final tenantId = await _tenantStorage.getTenantId();
    if (tenantId != null && tenantId.isNotEmpty) {
      options.headers['__tenant'] = tenantId;
    }
    handler.next(options);
  }
}

/// Injects `Accept-Language` header from the current app language setting.
class _AcceptLanguageInterceptor extends Interceptor {
  final ApiClient _client;

  _AcceptLanguageInterceptor(this._client);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final lang = _client.getLanguage?.call() ?? 'en';
    options.headers['Accept-Language'] = lang;
    handler.next(options);
  }
}

/// Attaches Bearer token and handles 401 refresh via ABP OAuth2.
class _AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage;
  final Dio _dio;
  final String _clientId;
  final void Function() _onSessionExpired;
  bool _isRefreshing = false;

  _AuthInterceptor({
    required TokenStorage tokenStorage,
    required Dio dio,
    required String clientId,
    required void Function() onSessionExpired,
  })  : _tokenStorage = tokenStorage,
        _dio = dio,
        _clientId = clientId,
        _onSessionExpired = onSessionExpired;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip token for token endpoint itself.
    if (options.path == ApiEndpoints.connectToken) {
      handler.next(options);
      return;
    }
    final token = await _tokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        err.requestOptions.path == ApiEndpoints.connectToken) {
      handler.next(err);
      return;
    }

    if (_isRefreshing) {
      handler.next(err);
      return;
    }

    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) {
      await _tokenStorage.clearTokens();
      _onSessionExpired();
      handler.next(err);
      return;
    }

    _isRefreshing = true;
    try {
      final response = await _dio.post(
        ApiEndpoints.connectToken,
        data: {
          'grant_type': 'refresh_token',
          'client_id': _clientId,
          'refresh_token': refreshToken,
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final newAccessToken = data['access_token'] as String;
      final newRefreshToken = data['refresh_token'] as String;
      await _tokenStorage.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );

      // Retry the original request with new token.
      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      final retryResponse = await _dio.fetch(retryOptions);
      _isRefreshing = false;
      return handler.resolve(retryResponse);
    } catch (_) {
      _isRefreshing = false;
      await _tokenStorage.clearTokens();
      _onSessionExpired();
    }
    handler.next(err);
  }
}

/// Handles ABP `{ error: { code, message, details, validationErrors } }` format.
class _AbpErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final data = err.response?.data;
    if (data is Map<String, dynamic> && data.containsKey('error')) {
      final abpError = AbpErrorResponse.fromJson(data);
      handler.next(err.copyWith(message: abpError.fullMessage));
      return;
    }
    // Handle OAuth2 error_description (from /connect/token failures).
    if (data is Map<String, dynamic> && data.containsKey('error_description')) {
      handler.next(err.copyWith(
        message: data['error_description'] as String? ?? data['error'] as String? ?? 'Authentication failed',
      ));
      return;
    }
    handler.next(err);
  }
}

/// Handles ABP WrapResult format `{ code, message, result }`.
/// If `_abpwrapresult` response header is `true`, unwraps the result.
class _WrapResultInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;
    if (data is Map<String, dynamic> && data.containsKey('code') && data.containsKey('result')) {
      final code = data['code']?.toString() ?? '0';
      if (code != '0') {
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            message: data['details']?.toString() ??
                data['message']?.toString() ??
                'Server error',
          ),
        );
        return;
      }
    }
    handler.next(response);
  }
}

/// Logs requests and responses.
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.debug('→ ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    AppLogger.debug(
      '← ${response.statusCode} ${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.error(
      '✕ ${err.requestOptions.method} ${err.requestOptions.uri}',
      err,
    );
    handler.next(err);
  }
}
