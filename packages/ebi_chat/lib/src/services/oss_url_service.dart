import 'dart:io';
import 'package:dio/dio.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/models/file_preview_info.dart';
import 'package:ebi_storage/ebi_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Thrown when an OSS signed URL cannot be generated.
class OssUrlException implements Exception {
  final String message;
  final Object? cause;

  const OssUrlException(this.message, [this.cause]);

  @override
  String toString() => 'OssUrlException: $message';
}

/// Resolves OSS blob paths to signed download/preview URLs.
///
/// Aligns with the Web project's `useImUpload.getFileUrl()` logic.
/// OSS path format: `blobs:im/<convKey>/<subPath>/<uniqueFileName>`
///
/// Uses a two-level cache:
/// - **L1**: fast in-memory map (`_cache`) for hot lookups within the
///   current isolate / service lifetime.
/// - **L2**: persistent database cache via [OssCacheDao] that survives
///   app restarts and has no fixed size limit.
///
/// Signed URLs typically expire after minutes, so both layers respect a TTL.
class OssUrlService {
  final ApiClient _apiClient;
  final OssCacheDao? _dao;

  /// In-memory L1 cache: ossPath → signed URL.
  final Map<String, _CacheEntry> _cache = {};

  /// Cache entries older than this are considered stale.
  /// Images are also cached on disk by CachedNetworkImage (using stable
  /// cacheKey), so even after URL expiry the image pixels remain available.
  static const _cacheTtl = Duration(minutes: 30);

  /// Maximum number of entries kept in the in-memory L1 cache.
  static const _maxCacheSize = 200;

  OssUrlService({
    required ApiClient apiClient,
    OssCacheDao? ossCacheDao,
  })  : _apiClient = apiClient,
        _dao = ossCacheDao {
    // Kick off expired-entry cleanup in the background.
    _dao?.deleteExpired();
  }

  /// Parse an ossPath into bucket, directory path, and file name.
  ///
  /// Aligns with Web's `useImUpload.getFileUrl()`:
  ///   ossPath = `"blobs:im/convKey/subDir/uniqueFile.jpg"`
  ///   → bucket: `"blobs"`, path: `"im/convKey/subDir"`, object: `"uniqueFile.jpg"`
  static ({String bucket, String path, String object}) _parseOssPath(
      String ossPath) {
    // Split at the first colon → bucket : fullPath
    final colonIndex = ossPath.indexOf(':');
    if (colonIndex < 0) {
      // No colon — treat entire string as object name with empty bucket/path.
      return (bucket: '', path: '', object: ossPath);
    }

    final bucket = ossPath.substring(0, colonIndex); // e.g. "blobs"
    final fullPath = ossPath.substring(colonIndex + 1); // e.g. "im/conv/sub/file.jpg"

    // Split fullPath at last slash → directory path + file name
    final lastSlash = fullPath.lastIndexOf('/');
    if (lastSlash < 0) {
      return (bucket: bucket, path: '', object: fullPath);
    }
    return (
      bucket: bucket,
      path: fullPath.substring(0, lastSlash), // "im/conv/sub"
      object: fullPath.substring(lastSlash + 1), // "file.jpg"
    );
  }

  /// Resolve an ossPath to a signed download URL.
  ///
  /// Throws [OssUrlException] if the path is empty, the API call fails,
  /// or the API returns an empty/unrecognised response.
  Future<String> getFileUrl(String ossPath) async {
    if (ossPath.isEmpty) {
      throw const OssUrlException('OSS path is empty');
    }

    // L1: check in-memory cache first.
    final cached = _cache[ossPath];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    // L2: check persistent DB cache.
    final dbUrl = await _dao?.getValidUrl(ossPath);
    if (dbUrl != null && dbUrl.isNotEmpty) {
      // Promote to L1 for subsequent fast access.
      _cache[ossPath] = _CacheEntry(url: dbUrl, createdAt: DateTime.now());
      return dbUrl;
    }

    final parsed = _parseOssPath(ossPath);


    try {
      // GET with query params — aligns with Web's generateUrlApi().
      // Response is a raw string (the signed URL itself).
      final response = await _apiClient.get(
        ApiEndpoints.ossGenerateUrl,
        queryParameters: {
          'bucket': parsed.bucket,
          'object': parsed.object,
          if (parsed.path.isNotEmpty) 'path': parsed.path,
          'mD5': false,
        },
      );


      // The API returns the signed URL as a plain string.
      final data = response.data;
      String url = '';
      if (data is String) {
        url = data;
      } else if (data is Map<String, dynamic>) {
        // Fallback: some ABP wrappers may envelope the result.
        final result = data['result'];
        if (result is String) {
          url = result;
        } else {
          url = (data['url'] ?? data['signedUrl'] ?? '') as String;
        }
      }

      if (url.isEmpty) {
        throw const OssUrlException('Server returned empty URL');
      }

      // Server may return a relative path (e.g. "/api/oss-management/objects/download/...")
      // instead of a full URL. Prepend the base server URL in that case.
      if (url.startsWith('/')) {
        url = '${AppConfig.baseServer}$url';
      }

      _putCache(ossPath, url);
      return url;
    } on OssUrlException {
      rethrow;
    } catch (e) {

      throw OssUrlException('Failed to generate signed URL', e);
    }
  }

  /// Resolve an ossPath to a thumbnail URL with image processing parameters.
  ///
  /// Throws [OssUrlException] on failure (delegates to [getFileUrl]).
  Future<String> getImageThumbnailUrl(
    String ossPath, {
    int maxWidth = 200,
    int maxHeight = 200,
  }) async {
    final url = await getFileUrl(ossPath);
    // Append OSS image processing query parameter.
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}x-oss-process=image/resize,m_lfit,w_$maxWidth,h_$maxHeight';
  }

  /// Fetch preview metadata for an OSS file.
  ///
  /// Calls `GET /api/oss-management/preview/info` with bucket, path, and name
  /// query parameters. Returns [FilePreviewInfo] with preview mode and signed
  /// URLs for rendering in [FilePreviewPage].
  Future<FilePreviewInfo> getPreviewInfo(String ossPath) async {
    if (ossPath.isEmpty) {
      throw const OssUrlException('OSS path is empty');
    }

    final parsed = _parseOssPath(ossPath);


    try {
      final response = await _apiClient.get(
        ApiEndpoints.ossPreviewInfo,
        queryParameters: {
          'bucket': parsed.bucket,
          if (parsed.path.isNotEmpty) 'path': parsed.path,
          'name': parsed.object,
        },
      );


      final data = response.data;
      Map<String, dynamic> json;
      if (data is Map<String, dynamic>) {
        // ABP WrapResult: {"code":"0","result":{...}}
        final result = data['result'];
        if (result is Map<String, dynamic>) {
          json = result;
        } else {
          json = data;
        }
      } else {
        throw const OssUrlException('Unexpected preview info response format');
      }

      final info = FilePreviewInfo.fromJson(json);

      // Resolve relative URLs to absolute.
      return FilePreviewInfo(
        bucket: info.bucket,
        fileName: info.fileName,
        path: info.path,
        fileType: info.fileType,
        contentType: info.contentType,
        size: info.size,
        previewMode: info.previewMode,
        previewUrl: _resolveUrl(info.previewUrl),
        downloadUrl:
            info.downloadUrl != null ? _resolveUrl(info.downloadUrl!) : null,
        isPreviewable: info.isPreviewable,
      );
    } on OssUrlException {
      rethrow;
    } catch (e) {
      throw OssUrlException('Failed to fetch preview info', e);
    }
  }

  /// Prepend base server URL if the value is a relative path.
  static String _resolveUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final slash = url.startsWith('/') ? '' : '/';
    return '${AppConfig.baseServer}$slash$url';
  }

  /// Upload a local file to OSS and return the ossPath.
  ///
  /// The returned ossPath follows the convention:
  ///   `blobs:im/<conversationKey>/<subDir>/<uniqueFileName>`
  ///
  /// [localPath] — absolute local file path.
  /// [fileName] — original file name (used for server-side storage).
  /// [conversationKey] — e.g. `group_<id>` or `user_<id>`.
  /// [subDir] — media subdirectory: `image`, `file`, `video`, `voice`.
  /// [onProgress] — 0.0–1.0 upload progress callback.
  Future<String> uploadFile({
    required String localPath,
    required String fileName,
    required String conversationKey,
    required String subDir,
    void Function(double)? onProgress,
  }) async {
    // Replace colon in group keys for safe path (same as Web).
    final safeKey = conversationKey.replaceAll(':', '_');
    final path = 'im/$safeKey/$subDir';
    final bucket = 'blobs';

    // Add unique prefix to filename to avoid collisions (same as Web).
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = timestamp.toRadixString(36).substring(0, 6);
    final uniqueName = '${timestamp}_${randomSuffix}_$fileName';

    try {
      final response = await _apiClient.uploadWithProgress(
        ApiEndpoints.ossUpload,
        filePath: localPath,
        fileName: fileName,
        fieldName: 'file',
        extraFields: {
          'bucket': bucket,
          'path': path,
          'fileName': uniqueName,
          'overwrite': 'false',
        },
        onSendProgress: onProgress,
      );

      // The API may return the ossPath directly or wrapped.
      final data = response.data;
      if (data is String && data.isNotEmpty) return data;
      if (data is Map<String, dynamic>) {
        final result = data['result'];
        if (result is String && result.isNotEmpty) return result;
      }

      // Construct the ossPath from known components.
      return '$bucket:$path/$uniqueName';
    } catch (e) {
      throw OssUrlException('Upload failed', e);
    }
  }

  /// Download an OSS file to a local temp path.
  ///
  /// Uses a **clean Dio instance** (no ABP interceptors, no `Accept: json`
  /// header) to download binary content correctly. The main ApiClient's Dio
  /// has interceptors that can corrupt binary downloads or cause format
  /// mismatches.
  Future<String> downloadToTemp(
    String ossPath, {
    void Function(double)? onProgress,
  }) async {
    final signedUrl = await getFileUrl(ossPath);
    final parsed = _parseOssPath(ossPath);
    final fileName = parsed.object.isNotEmpty ? parsed.object : 'download';

    final tempDir = await getTemporaryDirectory();
    final savePath = '${tempDir.path}/ebi_preview/$fileName';

    // Ensure parent directory exists.
    final dir = Directory('${tempDir.path}/ebi_preview');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // If already downloaded and exists, skip re-download.
    final file = File(savePath);
    if (await file.exists() && await file.length() > 0) {
      return savePath;
    }

    try {
      await _downloadRaw(signedUrl, savePath, onProgress: onProgress);
      return savePath;
    } catch (e) {
      throw OssUrlException('Download failed', e);
    }
  }

  /// Download using a clean Dio instance — no ABP interceptors, no
  /// `Accept: application/json` header, just raw binary download.
  Future<void> _downloadRaw(
    String url,
    String savePath, {
    void Function(double)? onProgress,
  }) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
    ));
    try {
      await dio.download(
        url,
        savePath,
        onReceiveProgress: onProgress != null
            ? (received, total) {
                if (total > 0) {
                  onProgress(received / total);
                }
              }
            : null,
      );
    } finally {
      dio.close();
    }
  }

  /// Evict a single entry (useful after a known expiry or error).
  void evict(String ossPath) {
    _cache.remove(ossPath);
    _dao?.evict(ossPath);
  }

  /// Download a file from a direct URL to a local path.
  ///
  /// This is useful for downloading converted files (e.g. officeToPdf
  /// preview URLs) that are not OSS blob paths.
  Future<void> downloadUrlToFile(
    String url,
    String savePath, {
    void Function(double)? onProgress,
  }) async {
    try {
      await _downloadRaw(url, savePath, onProgress: onProgress);
    } catch (e) {
      throw OssUrlException('Download failed', e);
    }
  }

  /// Clear both in-memory (L1) and persistent DB (L2) caches.
  void clearCache() {
    _cache.clear();
    _dao?.clearAll();
  }

  // ── Cache internals ──

  void _putCache(String key, String url) {
    // Simple LRU eviction: drop oldest entry when over limit.
    if (_cache.length >= _maxCacheSize) {
      final oldest = _cache.entries.first.key;
      _cache.remove(oldest);
    }
    _cache[key] = _CacheEntry(url: url, createdAt: DateTime.now());
    // Persist to DB (L2) — fire-and-forget.
    _dao?.put(key, url, ttl: _cacheTtl);
  }
}

class _CacheEntry {
  final String url;
  final DateTime createdAt;

  const _CacheEntry({required this.url, required this.createdAt});

  bool get isExpired =>
      DateTime.now().difference(createdAt) > OssUrlService._cacheTtl;
}

/// Riverpod provider for [OssUrlService].
final ossUrlServiceProvider = Provider<OssUrlService>((ref) {
  final apiClient = ref.read(apiClientProvider);
  OssCacheDao? dao;
  try { dao = ref.read(ossCacheDaoProvider); } catch (_) {}
  return OssUrlService(apiClient: apiClient, ossCacheDao: dao);
});
