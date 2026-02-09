/// Unified API response wrapper.
class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;
  final PaginationMeta? meta;

  const ApiResponse({
    required this.code,
    required this.message,
    this.data,
    this.meta,
  });

  bool get isSuccess => code >= 200 && code < 300;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      code: json['code'] as int,
      message: json['message'] as String,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      meta: json['meta'] != null
          ? PaginationMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
    );
  }
}

class PaginationMeta {
  final int page;
  final int perPage;
  final int total;

  const PaginationMeta({
    required this.page,
    required this.perPage,
    required this.total,
  });

  int get totalPages => (total / perPage).ceil();
  bool get hasNextPage => page < totalPages;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      page: json['page'] as int,
      perPage: json['per_page'] as int,
      total: json['total'] as int,
    );
  }
}
