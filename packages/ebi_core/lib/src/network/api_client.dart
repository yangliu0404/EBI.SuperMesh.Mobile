import 'package:dio/dio.dart';
import 'package:ebi_core/src/auth/token_storage.dart';
import 'package:ebi_core/src/network/api_endpoints.dart';
import 'package:ebi_core/src/network/api_exception.dart';
import 'package:ebi_core/src/utils/logger.dart';

/// Environment configuration.
enum AppEnvironment { dev, staging, prod }

/// Central API client wrapping Dio with auth interceptor and error handling.
class ApiClient {
  late final Dio _dio;
  final TokenStorage _tokenStorage;
  final AppEnvironment environment;

  ApiClient({
    required this.environment,
    required TokenStorage tokenStorage,
  }) : _tokenStorage = tokenStorage {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(_tokenStorage, _dio),
      _LoggingInterceptor(),
    ]);
  }

  String get _baseUrl {
    switch (environment) {
      case AppEnvironment.dev:
        return ApiEndpoints.devBaseUrl;
      case AppEnvironment.staging:
        return ApiEndpoints.stagingBaseUrl;
      case AppEnvironment.prod:
        return ApiEndpoints.prodBaseUrl;
    }
  }

  /// GET request.
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// POST request.
  Future<Response> post(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// PUT request.
  Future<Response> put(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// DELETE request.
  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
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
        return ApiException(
          statusCode: statusCode,
          message: data?['message'] ?? 'Request failed',
          errorCode: data?['error'],
          data: data,
        );
      default:
        return ApiException(message: e.message ?? 'Unknown error');
    }
  }
}

/// Interceptor that attaches Bearer token and handles 401 refresh.
class _AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage;
  final Dio _dio;

  _AuthInterceptor(this._tokenStorage, this._dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken != null) {
        try {
          final response = await _dio.post(
            ApiEndpoints.refreshToken,
            data: {'refresh_token': refreshToken},
          );
          final newAccessToken = response.data['data']['access_token'] as String;
          final newRefreshToken =
              response.data['data']['refresh_token'] as String;
          await _tokenStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );

          // Retry the original request with the new token.
          final retryOptions = err.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          final retryResponse = await _dio.fetch(retryOptions);
          return handler.resolve(retryResponse);
        } catch (_) {
          await _tokenStorage.clearTokens();
        }
      }
    }
    handler.next(err);
  }
}

/// Interceptor that logs requests and responses in debug mode.
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
