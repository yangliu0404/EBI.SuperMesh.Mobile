import 'package:dio/dio.dart';
import 'package:ebi_core/src/auth/tenant_storage.dart';

/// Dio interceptor that injects the ABP `__tenant` header on every request.
class TenantInterceptor extends Interceptor {
  final TenantStorage _tenantStorage;

  TenantInterceptor(this._tenantStorage);

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
