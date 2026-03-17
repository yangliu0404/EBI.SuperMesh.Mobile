import 'package:flutter/material.dart';

/// A set of floating circular icon buttons for media preview pages
/// (image & video). Positioned at bottom-right corner.
class MediaActionButtons extends StatelessWidget {
  /// Called when the forward button is tapped.
  final VoidCallback? onForward;

  /// Called when the download/share button is tapped.
  final VoidCallback? onDownload;

  /// Called when the gallery button is tapped.
  final VoidCallback? onGallery;

  /// Called when the custom share panel button is tapped.
  final VoidCallback? onShare;

  const MediaActionButtons({
    super.key,
    this.onForward,
    this.onDownload,
    this.onGallery,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    if (onForward != null) {
      buttons.add(_CircleButton(icon: Icons.send_rounded, tooltip: '转发', onTap: onForward));
    }
    if (onDownload != null) {
      buttons.add(_CircleButton(icon: Icons.download_rounded, tooltip: '保存/下载', onTap: onDownload));
    }
    if (onGallery != null) {
      buttons.add(_CircleButton(icon: Icons.grid_view_rounded, tooltip: '历史多媒体', onTap: onGallery));
    }
    if (onShare != null) {
      buttons.add(_CircleButton(icon: Icons.more_horiz_rounded, tooltip: '更多', onTap: onShare));
    }

    final columnChildren = <Widget>[];
    for (int i = 0; i < buttons.length; i++) {
      columnChildren.add(buttons[i]);
      if (i < buttons.length - 1) {
        columnChildren.add(const SizedBox(height: 12));
      }
    }

    return Positioned(
      right: 16,
      bottom: 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: columnChildren,
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _CircleButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
