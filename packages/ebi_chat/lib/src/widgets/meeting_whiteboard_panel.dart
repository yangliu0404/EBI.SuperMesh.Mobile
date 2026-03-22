import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ebi_core/ebi_core.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Collaborative whiteboard panel using WebView with pure JSON stroke sync.
/// No Yjs dependency — strokes are synchronized as raw JSON arrays via DataChannel.
class MeetingWhiteboardPanel extends StatefulWidget {
  final VoidCallback onClose;
  final void Function(List<dynamic> strokes)? onStrokesChanged;
  final VoidCallback? onReady;

  const MeetingWhiteboardPanel({
    super.key,
    required this.onClose,
    this.onStrokesChanged,
    this.onReady,
  });

  @override
  MeetingWhiteboardPanelState createState() => MeetingWhiteboardPanelState();
}

class MeetingWhiteboardPanelState extends State<MeetingWhiteboardPanel> {
  WebViewController? _controller;
  bool _isReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      final html = await rootBundle.loadString(
        'packages/ebi_chat/assets/whiteboard/whiteboard.html',
      );

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF2D3748))
        ..setNavigationDelegate(NavigationDelegate(
          onWebResourceError: (error) {
            debugPrint('[Whiteboard] WebView error: ${error.description}');
            if (mounted) setState(() => _error = error.description);
          },
        ))
        ..addJavaScriptChannel(
          'FlutterBridge',
          onMessageReceived: _onMessage,
        )
        ..loadHtmlString(html);

      if (mounted) setState(() => _controller = controller);
    } catch (e) {
      debugPrint('[Whiteboard] init error: $e');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _onMessage(JavaScriptMessage message) {
    try {
      final data = json.decode(message.message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'ready') {
        setState(() => _isReady = true);
        widget.onReady?.call();
      } else if (type == 'strokes-changed') {
        final strokes = data['strokes'] as List<dynamic>?;
        if (strokes != null) {
          widget.onStrokesChanged?.call(strokes);
        }
      }
    } catch (e) {
      debugPrint('[Whiteboard] message error: $e');
    }
  }

  /// Set strokes from remote (replaces all local strokes and redraws).
  void setStrokes(List<dynamic> strokes) {
    if (!_isReady || _controller == null) return;
    final jsonStr = json.encode(strokes);
    // Use base64 to avoid JS string escaping issues
    final b64 = base64Encode(utf8.encode(jsonStr));
    _controller!.runJavaScript("setStrokes(atob('$b64'))");
  }

  /// Get current strokes as JSON string.
  Future<String?> getStrokesJson() async {
    if (!_isReady || _controller == null) return null;
    try {
      final result = await _controller!.runJavaScriptReturningResult('getStrokes()');
      return result.toString().replaceAll('"', '');
    } catch (e) {
      debugPrint('[Whiteboard] getStrokes error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0, top: 0, bottom: 60, width: 340,
      child: Material(
        color: const Color(0xFF1A202C),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                Text(context.L('Whiteboard'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(onTap: widget.onClose, child: const Icon(Icons.close, color: Colors.white54, size: 20)),
              ]),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: _error != null
                  ? Center(child: Text('加载失败: $_error', style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center))
                  : _controller != null
                      ? WebViewWidget(controller: _controller!)
                      : const Center(child: CircularProgressIndicator(color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }
}
