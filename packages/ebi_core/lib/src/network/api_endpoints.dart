/// SuperMesh API endpoint definitions for ABP backend.
class ApiEndpoints {
  ApiEndpoints._();

  // ── ABP OAuth2 ──
  static const String connectToken = '/connect/token';
  static const String connectUserInfo = '/connect/userinfo';
  static const String connectRevocation = '/connect/revocation';

  // ── ABP Multi-Tenancy ──
  static String tenantByName(String name) =>
      '/api/abp/multi-tenancy/tenants/by-name/$name';
  static String tenantById(String id) =>
      '/api/abp/multi-tenancy/tenants/by-id/$id';

  // ── ABP Application ──
  static const String abpApplicationConfiguration =
      '/api/abp/application-configuration';
  static const String abpApplicationLocalization =
      '/api/abp/application-localization';

  // ── Notifications ──
  static const String notifications = '/api/app/notifications';
  static String notificationDetail(String id) =>
      '/api/app/notifications/$id';
  static const String notificationMarkAllRead =
      '/api/app/notifications/mark-all-as-read';

  // ── Orders ──
  static const String orders = '/api/app/orders';
  static String orderDetail(String id) => '/api/app/orders/$id';

  // ── Projects ──
  static const String projects = '/api/app/projects';
  static String projectDetail(String id) => '/api/app/projects/$id';

  // ── Quotations ──
  static const String quotations = '/api/app/quotations';
  static String quotationDetail(String id) => '/api/app/quotations/$id';

  // ── IM Chat ──
  static const String imMyLastMessages = '/api/im/chat/my-last-messages';
  static const String imMyMessages = '/api/im/chat/my-messages';
  static const String imGroupMessages = '/api/im/chat/group/messages';
  static const String imSendMessage = '/api/im/chat/send-message';
  static String imUserCard(String userId) => '/api/im/chat/user-card/$userId';

  // ── IM Groups ──
  static const String imGroups = '/api/im/chat/groups';
  static String imGroupDetail(String id) => '/api/im/chat/groups/$id';
  static String imGroupUsers(String groupId) =>
      '/api/im/chat/groups/$groupId/users';

  // ── SignalR Hubs ──
  static const String signalRNotifications = '/signalr-hubs/notifications';
  static const String signalRMessages = '/signalr-hubs/messages';
  static const String signalRCall = '/signalr-hubs/call';

  // ── IM Conversation Settings ──
  static const String imConversationSettings =
      '/api/im/conversation-settings';

  // ── OSS Management ──
  static const String ossGenerateUrl =
      '/api/oss-management/objects/generate-url';
  static const String ossPreviewInfo = '/api/oss-management/preview/info';
  static const String ossUpload = '/api/oss-management/objects';
}
