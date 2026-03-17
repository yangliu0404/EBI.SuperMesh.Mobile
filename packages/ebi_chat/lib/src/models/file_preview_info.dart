/// File type classification aligned with Web's `preview.ts`.
enum FileType {
  image(0),
  video(1),
  audio(2),
  word(3),
  excel(4),
  ppt(5),
  pdf(6),
  text(7),
  code(8),
  json(9),
  markdown(10),
  html(11),
  xml(12),
  zip(13),
  font(14),
  other(99);

  final int value;
  const FileType(this.value);

  static FileType fromValue(int v) =>
      FileType.values.firstWhere((e) => e.value == v, orElse: () => other);
}

/// Preview rendering mode aligned with Web's `FilePreviewMode`.
enum FilePreviewMode {
  downloadOnly(0),
  inlineImage(1),
  inlinePdf(2),
  excelClientRender(3),
  csvClientRender(4),
  wordClientRender(5),
  pptClientRender(6),
  inlineText(7),
  inlineCode(8),
  inlineJson(9),
  inlineMarkdown(10),
  inlineHtml(11),
  inlineAudio(12),
  inlineVideo(13),
  officeToPdf(20),
  officeToHtml(21);

  final int value;
  const FilePreviewMode(this.value);

  static FilePreviewMode fromValue(int v) => FilePreviewMode.values
      .firstWhere((e) => e.value == v, orElse: () => downloadOnly);
}

/// File preview metadata returned by the backend preview/info API.
class FilePreviewInfo {
  final String? bucket;
  final String fileName;
  final String? path;
  final FileType fileType;
  final String? contentType;
  final int size;
  final FilePreviewMode previewMode;
  final String previewUrl;
  final String? downloadUrl;
  final bool isPreviewable;

  const FilePreviewInfo({
    this.bucket,
    required this.fileName,
    this.path,
    required this.fileType,
    this.contentType,
    required this.size,
    required this.previewMode,
    required this.previewUrl,
    this.downloadUrl,
    required this.isPreviewable,
  });

  factory FilePreviewInfo.fromJson(Map<String, dynamic> json) {
    return FilePreviewInfo(
      bucket: json['bucket'] as String?,
      fileName: (json['fileName'] ?? json['name'] ?? '') as String,
      path: json['path'] as String?,
      fileType: FileType.fromValue((json['fileType'] ?? 99) as int),
      contentType: json['contentType'] as String?,
      size: (json['size'] ?? 0) as int,
      previewMode: FilePreviewMode.fromValue((json['previewMode'] ?? 0) as int),
      previewUrl: (json['previewUrl'] ?? '') as String,
      downloadUrl: json['downloadUrl'] as String?,
      isPreviewable: (json['isPreviewable'] ?? false) as bool,
    );
  }
}
