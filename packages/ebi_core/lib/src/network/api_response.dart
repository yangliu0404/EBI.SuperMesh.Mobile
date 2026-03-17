/// Unified API response wrapper for ABP backend.
///
/// ABP uses two response patterns:
/// 1. WrapResult: `{ code: "0", message: "...", result: ... }`
/// 2. Direct data (most endpoints return data directly)
/// 3. Paged: `{ totalCount: N, items: [...] }`
class AbpWrapResult<T> {
  final String code;
  final String message;
  final T? result;
  final String? details;

  const AbpWrapResult({
    required this.code,
    required this.message,
    this.result,
    this.details,
  });

  bool get isSuccess => code == '0';

  factory AbpWrapResult.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return AbpWrapResult<T>(
      code: (json['code'] ?? '0').toString(),
      message: json['message'] as String? ?? '',
      result: json['result'] != null && fromJsonT != null
          ? fromJsonT(json['result'])
          : json['result'] as T?,
      details: json['details'] as String?,
    );
  }
}

/// ABP paged result format: `{ totalCount, items }`.
class AbpPagedResult<T> {
  final int totalCount;
  final List<T> items;

  const AbpPagedResult({
    required this.totalCount,
    required this.items,
  });

  bool get hasMore => items.length < totalCount;

  factory AbpPagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return AbpPagedResult<T>(
      totalCount: json['totalCount'] as int? ?? 0,
      items: rawItems
          .map((e) => fromJsonT(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// ABP paged request parameters.
class AbpPagedRequest {
  final int skipCount;
  final int maxResultCount;
  final String? sorting;
  final String? filter;

  const AbpPagedRequest({
    this.skipCount = 0,
    this.maxResultCount = 20,
    this.sorting,
    this.filter,
  });

  Map<String, dynamic> toQueryParameters() {
    return {
      'SkipCount': skipCount,
      'MaxResultCount': maxResultCount,
      if (sorting != null) 'Sorting': sorting,
      if (filter != null) 'Filter': filter,
    };
  }
}

/// ABP error response: `{ error: { code, message, details, validationErrors } }`.
class AbpErrorResponse {
  final String? code;
  final String message;
  final String? details;
  final List<AbpValidationError> validationErrors;

  const AbpErrorResponse({
    this.code,
    required this.message,
    this.details,
    this.validationErrors = const [],
  });

  factory AbpErrorResponse.fromJson(Map<String, dynamic> json) {
    final error = json['error'] as Map<String, dynamic>? ?? json;
    final rawValidations =
        error['validationErrors'] as List<dynamic>? ?? [];
    return AbpErrorResponse(
      code: error['code'] as String?,
      message: error['message'] as String? ?? 'Unknown error',
      details: error['details'] as String?,
      validationErrors: rawValidations
          .map((e) =>
              AbpValidationError.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get fullMessage {
    final buffer = StringBuffer(message);
    for (final ve in validationErrors) {
      buffer.write('\n${ve.message}');
    }
    return buffer.toString();
  }
}

class AbpValidationError {
  final String message;
  final List<String> members;

  const AbpValidationError({
    required this.message,
    this.members = const [],
  });

  factory AbpValidationError.fromJson(Map<String, dynamic> json) {
    return AbpValidationError(
      message: json['message'] as String? ?? '',
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}
