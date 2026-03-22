import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_markdown_community/flutter_markdown.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/models/file_preview_info.dart';
import 'package:ebi_chat/src/services/oss_url_service.dart';

/// Inline text/code/JSON/Markdown/CSV viewer.
///
/// Downloads the file content then renders based on [FilePreviewMode]:
/// - `inlineText` → scrollable text
/// - `inlineCode`, `inlineJson` → syntax-highlighted code
/// - `inlineMarkdown` → rendered Markdown
/// - `inlineHtml` → rendered as plain text
/// - `csvClientRender` → simple table
class TextPreviewWidget extends ConsumerStatefulWidget {
  final String ossPath;
  final FilePreviewMode previewMode;
  final String? fileName;

  const TextPreviewWidget({
    super.key,
    required this.ossPath,
    required this.previewMode,
    this.fileName,
  });

  @override
  ConsumerState<TextPreviewWidget> createState() => _TextPreviewWidgetState();
}

class _TextPreviewWidgetState extends ConsumerState<TextPreviewWidget> {
  String? _content;
  bool _isLoading = true;
  double _downloadProgress = 0.0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final ossService = ref.read(ossUrlServiceProvider);
      final path = await ossService.downloadToTemp(
        widget.ossPath,
        onProgress: (progress) {
          if (mounted) setState(() => _downloadProgress = progress);
        },
      );
      final file = File(path);
      final content = await file.readAsString();
      if (mounted) {
        setState(() {
          _content = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is OssUrlException
              ? e.message
              : 'Failed to load file content';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
            ),
            const SizedBox(height: 16),
            Text(
              _downloadProgress > 0
                  ? 'Loading ${(_downloadProgress * 100).toInt()}%'
                  : 'Loading file...',
              style: TextStyle(fontSize: 14, color: EbiColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                  _downloadProgress = 0.0;
                });
                _loadContent();
              },
              icon: const Icon(Icons.refresh),
              label: Text(context.L('Retry')),
            ),
          ],
        ),
      );
    }

    final content = _content!;

    switch (widget.previewMode) {
      case FilePreviewMode.inlineMarkdown:
        return _buildMarkdownView(content);
      case FilePreviewMode.inlineCode:
      case FilePreviewMode.inlineJson:
        return _buildCodeView(content);
      case FilePreviewMode.csvClientRender:
        return _buildCsvView(content);
      default:
        return _buildPlainTextView(content);
    }
  }

  Widget _buildPlainTextView(String content) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        content,
        style: const TextStyle(
          fontSize: 14,
          fontFamily: 'monospace',
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildCodeView(String content) {
    final language = _detectLanguage();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: HighlightView(
        content,
        language: language,
        theme: githubTheme,
        padding: const EdgeInsets.all(16),
        textStyle: const TextStyle(
          fontSize: 13,
          fontFamily: 'monospace',
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildMarkdownView(String content) {
    return Markdown(
      data: content,
      selectable: true,
      padding: const EdgeInsets.all(16),
    );
  }

  Widget _buildCsvView(String content) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return _buildPlainTextView(content);

    final rows = lines.map((line) => line.split(',')).toList();
    final headerRow = rows.first;
    final dataRows = rows.length > 1 ? rows.sublist(1) : <List<String>>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            EbiColors.primaryBlue.withValues(alpha: 0.05),
          ),
          columns: headerRow
              .map((h) => DataColumn(
                    label: Text(
                      h.trim(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ))
              .toList(),
          rows: dataRows
              .map((row) => DataRow(
                    cells: List.generate(
                      headerRow.length,
                      (i) => DataCell(
                        Text(i < row.length ? row[i].trim() : ''),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  String _detectLanguage() {
    if (widget.previewMode == FilePreviewMode.inlineJson) return 'json';

    final ext = _extFromName(widget.fileName);
    switch (ext) {
      case 'js':
      case 'jsx':
        return 'javascript';
      case 'ts':
      case 'tsx':
        return 'typescript';
      case 'py':
        return 'python';
      case 'java':
        return 'java';
      case 'dart':
        return 'dart';
      case 'kt':
        return 'kotlin';
      case 'swift':
        return 'swift';
      case 'go':
        return 'go';
      case 'rb':
        return 'ruby';
      case 'rs':
        return 'rust';
      case 'c':
      case 'h':
        return 'c';
      case 'cpp':
      case 'cc':
      case 'cxx':
      case 'hpp':
        return 'cpp';
      case 'cs':
        return 'csharp';
      case 'php':
        return 'php';
      case 'html':
      case 'htm':
        return 'html';
      case 'css':
        return 'css';
      case 'xml':
        return 'xml';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'sql':
        return 'sql';
      case 'sh':
      case 'bash':
        return 'bash';
      default:
        return 'plaintext';
    }
  }

  static String? _extFromName(String? name) {
    if (name == null) return null;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
  }
}
