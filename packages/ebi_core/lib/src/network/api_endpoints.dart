/// SuperMesh API endpoint definitions.
class ApiEndpoints {
  ApiEndpoints._();

  // ── Base URLs ──
  static const String devBaseUrl = 'https://dev-api.supermesh.e-bi.com';
  static const String stagingBaseUrl = 'https://staging-api.supermesh.e-bi.com';
  static const String prodBaseUrl = 'https://api.supermesh.e-bi.com';

  // ── API Version ──
  static const String apiVersion = '/v1';

  // ── Auth ──
  static const String login = '$apiVersion/auth/login';
  static const String refreshToken = '$apiVersion/auth/refresh';
  static const String logout = '$apiVersion/auth/logout';
  static const String profile = '$apiVersion/auth/profile';

  // ── Orders ──
  static const String orders = '$apiVersion/orders';
  static String orderDetail(String id) => '$apiVersion/orders/$id';

  // ── Projects ──
  static const String projects = '$apiVersion/projects';
  static String projectDetail(String id) => '$apiVersion/projects/$id';

  // ── Quotations ──
  static const String quotations = '$apiVersion/quotations';
  static String quotationDetail(String id) => '$apiVersion/quotations/$id';

  // ── Notifications ──
  static const String notifications = '$apiVersion/notifications';
}
