import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/src/theme/ebi_colors.dart';

/// Loading indicator with e-bi brand color.
class EbiLoading extends StatelessWidget {
  final double size;
  final String? message;

  const EbiLoading({
    super.key,
    this.size = 36,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              color: EbiColors.primaryBlue,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(
                fontSize: 14,
                color: EbiColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
