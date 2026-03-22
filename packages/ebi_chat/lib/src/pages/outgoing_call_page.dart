import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/models/call_models.dart';
import 'package:ebi_chat/src/providers/call_providers.dart';
import 'package:ebi_chat/src/pages/call_page.dart';

/// Full-screen outgoing call page (dialing state with cancel button).
class OutgoingCallPage extends ConsumerStatefulWidget {
  const OutgoingCallPage({super.key});

  @override
  ConsumerState<OutgoingCallPage> createState() => _OutgoingCallPageState();
}

class _OutgoingCallPageState extends ConsumerState<OutgoingCallPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _hasNavigatedToCall = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
    _pulseAnimation = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callStateProvider);

    // Pop only when outgoing call status is completely cleared (null).
    final shouldShow = callState.outgoingCallStatus != null;
    if (!shouldShow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        } catch (_) {}
      });
      return const Scaffold(backgroundColor: Color(0xFF111827));
    }

    ref.listen<CallState>(callStateProvider, (prev, next) {
      if (!_hasNavigatedToCall &&
          next.activeCall?.status == CallStatus.connected &&
          mounted) {
        _hasNavigatedToCall = true;
        // Replace OutgoingCallPage with the active CallPage.
        try {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const CallPage(),
              fullscreenDialog: true,
            ),
          );
        } catch (e) {
          debugPrint('[OutgoingCallPage] pushReplacement failed: $e');
        }
      }
    });

    final targetName = callState.outgoingCallTargetName ?? context.L('UnknownUser');
    final targetAvatarUrl = callState.outgoingCallTargetAvatarUrl;
    final isTerminal = callState.isDialingTerminal;

    String statusText = context.L('Calling');
    if (callState.outgoingCallStatus == 'rejected') statusText = context.L('CallRejected');
    if (callState.outgoingCallStatus == 'busy') statusText = context.L('CallBusy');
    if (callState.outgoingCallStatus == 'no-answer') statusText = context.L('NoAnswer');
    if (callState.outgoingCallStatus == 'cancelled') statusText = context.L('CallCancelled');

    final textStatusColor = isTerminal ? const Color(0xFFF87171) : Colors.white70;

    return Scaffold(
      backgroundColor: Colors.black, // Dark fallback
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background (Blurred Avatar or Gradient)
          if (targetAvatarUrl != null && targetAvatarUrl.isNotEmpty) ...[
            Image.network(targetAvatarUrl, fit: BoxFit.cover),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ] else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1F2937), Color(0xFF111827), Colors.black],
                ),
              ),
            ),

          // 2. Foreground overlay
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                
                // Avatar with pulse effect
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (callState.isDialing)
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (_, __) => Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(
                                    alpha: 0.15 * (2.0 - _pulseAnimation.value)),
                              ),
                            ),
                          ),
                        ),
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2B3245),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 2,
                          ),
                          image: (targetAvatarUrl != null &&
                                  targetAvatarUrl.isNotEmpty)
                              ? DecorationImage(
                                  image: NetworkImage(targetAvatarUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: (targetAvatarUrl == null ||
                                targetAvatarUrl.isEmpty)
                            ? Center(
                                child: Text(
                                  targetName.isNotEmpty
                                      ? targetName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Name and Status
                Text(
                  targetName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    color: textStatusColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const Spacer(),

                // Bottom Controls
                if (callState.isDialing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 60),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            ref
                                .read(callStateProvider.notifier)
                                .cancelOutgoingCall();
                          },
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFEF4444),
                            ),
                            child: Transform.rotate(
                              angle: 135 * 3.1415926 / 180,
                              child: const Icon(
                                Icons.phone,
                                size: 36,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.L('Cancel'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
