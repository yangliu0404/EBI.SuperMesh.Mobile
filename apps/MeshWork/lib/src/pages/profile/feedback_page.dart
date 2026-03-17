import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';

/// Feedback category types.
enum FeedbackType {
  suggestion('Suggestion', Icons.lightbulb_outline, 'Ideas to improve the app'),
  bug('Bug Report', Icons.bug_report_outlined, 'Something isn\'t working'),
  feature('Feature', Icons.extension_outlined, 'Request new functionality'),
  performance('Performance', Icons.speed_outlined, 'Speed or resource issues'),
  ui('UI / UX', Icons.design_services_outlined, 'Design and usability'),
  other('Other', Icons.more_horiz, 'General feedback');

  final String label;
  final IconData icon;
  final String desc;
  const FeedbackType(this.label, this.icon, this.desc);
}

/// Feedback page for MeshWork app — flat tech style.
class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  FeedbackType _selectedType = FeedbackType.suggestion;
  final _contentController = TextEditingController();
  final _contactController = TextEditingController();
  bool _isSubmitting = false;

  static const _accent = EbiColors.primaryBlue;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _contactController.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _contentController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _contentController.text.trim().length >= 10 && !_isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EbiColors.bgMeshWork,
      appBar: const EbiAppBar(title: 'Feedback'),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── Type Selector ──
            _buildTypeSelector(),

            const SizedBox(height: 16),

            // ── Content Input ──
            _buildContentInput(),

            const SizedBox(height: 16),

            // ── Contact Info ──
            _buildContactInput(),

            const SizedBox(height: 24),

            // ── Submit Button ──
            _buildSubmitButton(),

            const SizedBox(height: 16),

            // ── Privacy Note ──
            Center(
              child: Text(
                'Your feedback helps us improve MeshWork.',
                style: EbiTextStyles.bodySmall.copyWith(
                  color: EbiColors.textHint,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Flat Tech Type Selector ──
  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'SELECT CATEGORY',
            style: EbiTextStyles.labelSmall.copyWith(
              color: EbiColors.textSecondary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: FeedbackType.values.map((type) {
            final isSelected = _selectedType == type;
            return GestureDetector(
              onTap: () => setState(() => _selectedType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _accent.withValues(alpha: 0.08)
                      : EbiColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? _accent
                        : EbiColors.divider,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      type.icon,
                      size: 16,
                      color: isSelected ? _accent : EbiColors.textHint,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? _accent
                            : EbiColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            _selectedType.desc,
            style: EbiTextStyles.bodySmall.copyWith(
              color: EbiColors.textHint,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  // ── Content Input ──
  Widget _buildContentInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'DESCRIPTION',
            style: EbiTextStyles.labelSmall.copyWith(
              color: EbiColors.textSecondary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: EbiColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: EbiColors.divider),
          ),
          child: Column(
            children: [
              TextFormField(
                controller: _contentController,
                maxLines: 5,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontSize: 14,
                  color: EbiColors.textPrimary,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: _hintForType(_selectedType),
                  hintStyle: EbiTextStyles.bodyMedium.copyWith(
                    color: EbiColors.textHint,
                  ),
                  filled: true,
                  fillColor: EbiColors.white,
                  contentPadding: const EdgeInsets.all(14),
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
              // ── Bottom toolbar ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(7),
                    bottomRight: Radius.circular(7),
                  ),
                  border: Border(
                    top: BorderSide(color: EbiColors.divider.withValues(alpha: 0.5)),
                  ),
                ),
                child: Row(
                  children: [
                    _toolbarButton(
                      Icons.image_outlined,
                      'Image',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Image attachment coming soon'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _toolbarButton(
                      Icons.attach_file,
                      'File',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('File attachment coming soon'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    Text(
                      '${_contentController.text.length} / 500',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'RobotoMono',
                        color: _contentController.text.length > 450
                            ? EbiColors.warning
                            : EbiColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toolbarButton(IconData icon, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: EbiColors.divider),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: EbiColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: EbiColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _hintForType(FeedbackType type) {
    switch (type) {
      case FeedbackType.suggestion:
        return 'Tell us what we can improve...';
      case FeedbackType.bug:
        return 'Describe the issue and steps to reproduce...';
      case FeedbackType.feature:
        return 'Describe the feature you would like...';
      case FeedbackType.performance:
        return 'Describe the performance issue...';
      case FeedbackType.ui:
        return 'Describe the UI/UX issue or suggestion...';
      case FeedbackType.other:
        return 'Share your thoughts with us...';
    }
  }

  // ── Contact Input ──
  Widget _buildContactInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Text(
                'CONTACT',
                style: EbiTextStyles.labelSmall.copyWith(
                  color: EbiColors.textSecondary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: EbiColors.divider.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'OPTIONAL',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: EbiColors.textHint,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        EbiTextField(
          controller: _contactController,
          hintText: 'Email or phone for follow-up',
          prefixIcon: Icons.alternate_email,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  // ── Submit Button ──
  Widget _buildSubmitButton() {
    return EbiButton(
      text: 'Submit Feedback',
      icon: Icons.send_outlined,
      width: double.infinity,
      isLoading: _isSubmitting,
      onPressed: _canSubmit ? _submitFeedback : null,
    );
  }

  Future<void> _submitFeedback() async {
    setState(() => _isSubmitting = true);

    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    _showSuccessDialog();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: EbiColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: EbiColors.success,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Thank You!',
              style: EbiTextStyles.h3.copyWith(color: EbiColors.darkNavy),
            ),
            const SizedBox(height: 8),
            Text(
              'Your feedback has been submitted successfully. We appreciate your input!',
              style: EbiTextStyles.bodyMedium.copyWith(
                color: EbiColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
