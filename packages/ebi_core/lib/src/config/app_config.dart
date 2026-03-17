/// Environment configuration for SuperMesh ABP backend.
enum AppEnvironment { dev, staging, prod }

/// Centralized app configuration constants.
class AppConfig {
  AppConfig._();

  // ── Server URLs ──
  static const String baseServer = 'https://10.1.1.8:44380';
  static const String buyerServer = 'https://10.1.1.8:44388';
  static const String supplierServer = 'https://10.1.1.8:44399';

  // ── OAuth2 Client IDs ──
  static const String meshWorkClientId = 'SuperMesh_MeshWork';
  static const String meshPortalClientId = 'SuperMesh_MeshPortal';

  // ── OAuth2 Scopes ──
  static const String defaultScopes =
      'openid offline_access profile email phone roles BaseServer';

  // ── Tenant ──
  static const String tenantHeaderKey = '__tenant';

  // ── SignalR Hubs ──
  static const String signalRServer = 'https://10.1.1.8:44390';
  static const String notificationHub =
      '$signalRServer/signalr-hubs/notifications';
  static const String messageHub = '$signalRServer/signalr-hubs/messages';
  static const String callHub = '$signalRServer/signalr-hubs/call';

  /// Returns the base URL for the given environment.
  static String baseUrlFor(AppEnvironment env) {
    switch (env) {
      case AppEnvironment.dev:
        return baseServer;
      case AppEnvironment.staging:
        return baseServer; // Same for now; update when staging is available.
      case AppEnvironment.prod:
        return baseServer;
    }
  }
}
