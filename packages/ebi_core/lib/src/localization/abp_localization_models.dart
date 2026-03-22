/// DTOs for ABP application localization API responses.

/// Response from `/api/abp/application-localization`.
class AbpLocalizationResult {
  final Map<String, AbpLocalizationResource> resources;

  const AbpLocalizationResult({this.resources = const {}});

  factory AbpLocalizationResult.fromJson(Map<String, dynamic> json) {
    final resourcesJson = json['resources'] as Map<String, dynamic>? ?? {};
    final resources = resourcesJson.map((key, value) {
      return MapEntry(
        key,
        AbpLocalizationResource.fromJson(value as Map<String, dynamic>),
      );
    });
    return AbpLocalizationResult(resources: resources);
  }
}

/// A single localization resource with texts and optional base resources.
class AbpLocalizationResource {
  final Map<String, String> texts;
  final List<String> baseResources;

  const AbpLocalizationResource({
    this.texts = const {},
    this.baseResources = const [],
  });

  factory AbpLocalizationResource.fromJson(Map<String, dynamic> json) {
    final textsJson = json['texts'] as Map<String, dynamic>? ?? {};
    final texts = textsJson.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    final baseResources = (json['baseResources'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    return AbpLocalizationResource(
      texts: texts,
      baseResources: baseResources,
    );
  }
}

/// Current culture info from ABP configuration.
class AbpCurrentCulture {
  final String? name;
  final String? cultureName;
  final String? displayName;
  final String? englishName;
  final String? nativeName;
  final String? twoLetterIsoLanguageName;
  final String? threeLetterIsoLanguageName;
  final bool isRightToLeft;
  final AbpDateTimeFormat? dateTimeFormat;

  const AbpCurrentCulture({
    this.name,
    this.cultureName,
    this.displayName,
    this.englishName,
    this.nativeName,
    this.twoLetterIsoLanguageName,
    this.threeLetterIsoLanguageName,
    this.isRightToLeft = false,
    this.dateTimeFormat,
  });

  factory AbpCurrentCulture.fromJson(Map<String, dynamic> json) {
    return AbpCurrentCulture(
      name: json['name'] as String?,
      cultureName: json['cultureName'] as String?,
      displayName: json['displayName'] as String?,
      englishName: json['englishName'] as String?,
      nativeName: json['nativeName'] as String?,
      twoLetterIsoLanguageName: json['twoLetterIsoLanguageName'] as String?,
      threeLetterIsoLanguageName:
          json['threeLetterIsoLanguageName'] as String?,
      isRightToLeft: json['isRightToLeft'] as bool? ?? false,
      dateTimeFormat: json['dateTimeFormat'] != null
          ? AbpDateTimeFormat.fromJson(
              json['dateTimeFormat'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Date/time format info from ABP.
class AbpDateTimeFormat {
  final String? calendarAlgorithmType;
  final String? dateTimeFormatLong;
  final String? shortDatePattern;
  final String? fullDateTimePattern;
  final String? dateSeparator;
  final String? shortTimePattern;
  final String? longTimePattern;

  const AbpDateTimeFormat({
    this.calendarAlgorithmType,
    this.dateTimeFormatLong,
    this.shortDatePattern,
    this.fullDateTimePattern,
    this.dateSeparator,
    this.shortTimePattern,
    this.longTimePattern,
  });

  factory AbpDateTimeFormat.fromJson(Map<String, dynamic> json) {
    return AbpDateTimeFormat(
      calendarAlgorithmType: json['calendarAlgorithmType'] as String?,
      dateTimeFormatLong: json['dateTimeFormatLong'] as String?,
      shortDatePattern: json['shortDatePattern'] as String?,
      fullDateTimePattern: json['fullDateTimePattern'] as String?,
      dateSeparator: json['dateSeparator'] as String?,
      shortTimePattern: json['shortTimePattern'] as String?,
      longTimePattern: json['longTimePattern'] as String?,
    );
  }
}

/// Language info from ABP.
class AbpLanguageInfo {
  final String cultureName;
  final String uiCultureName;
  final String displayName;
  final String? flagIcon;
  final bool isEnabled;
  final bool isDefault;

  const AbpLanguageInfo({
    required this.cultureName,
    required this.uiCultureName,
    required this.displayName,
    this.flagIcon,
    this.isEnabled = true,
    this.isDefault = false,
  });

  factory AbpLanguageInfo.fromJson(Map<String, dynamic> json) {
    return AbpLanguageInfo(
      cultureName: json['cultureName'] as String? ?? '',
      uiCultureName: json['uiCultureName'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      flagIcon: json['flagIcon'] as String?,
      isEnabled: json['isEnabled'] as bool? ?? true,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

/// Timing/timezone info from ABP configuration.
class AbpTimingInfo {
  final String? ianaTimeZoneName;
  final String? windowsTimeZoneId;

  const AbpTimingInfo({this.ianaTimeZoneName, this.windowsTimeZoneId});

  factory AbpTimingInfo.fromJson(Map<String, dynamic> json) {
    final timeZone = json['timeZone'] as Map<String, dynamic>? ?? {};
    final iana = timeZone['iana'] as Map<String, dynamic>?;
    final windows = timeZone['windows'] as Map<String, dynamic>?;
    return AbpTimingInfo(
      ianaTimeZoneName: iana?['timeZoneName'] as String?,
      windowsTimeZoneId: windows?['timeZoneId'] as String?,
    );
  }
}
