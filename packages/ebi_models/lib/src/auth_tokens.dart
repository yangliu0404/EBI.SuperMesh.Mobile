/// ABP OAuth2 token response model.
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;
  final String? scope;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.tokenType = 'Bearer',
    this.scope,
  });

  /// Parse directly from OAuth2 `/connect/token` response.
  factory AuthTokens.fromOAuthResponse(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String? ?? '',
      expiresIn: json['expires_in'] as int? ?? 3600,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      scope: json['scope'] as String?,
    );
  }

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens.fromOAuthResponse(json);
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_in': expiresIn,
        'token_type': tokenType,
        if (scope != null) 'scope': scope,
      };
}
