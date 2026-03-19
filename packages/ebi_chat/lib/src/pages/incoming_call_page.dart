import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_chat/src/models/call_models.dart';
import 'package:ebi_chat/src/providers/call_providers.dart';

/// Full-screen incoming call page with accept/reject buttons.
class IncomingCallPage extends ConsumerStatefulWidget {
  const IncomingCallPage({super.key});

  @override
  ConsumerState<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends ConsumerState<IncomingCallPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
    final incoming = callState.currentIncomingCall;

    // Pop if no incoming call.
    if (incoming == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(backgroundColor: Color(0xFF111827));
    }

    // Also pop when user accepted and call becomes active.
    ref.listen<CallState>(callStateProvider, (prev, next) {
      if (next.hasActiveCall && mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });

    final isVideo = incoming.callType == CallType.video;
    final callerName = incoming.callerUserName.isNotEmpty
        ? incoming.callerUserName
        : '未知用户';

    // Incoming call gradient background (dark premium feel)
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1F2937), Color(0xFF111827), Colors.black],
              ),
            ),
          ),
          
          // Foreground overlay
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
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            callerName.isNotEmpty
                                ? callerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Name and Type
                Text(
                  callerName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isVideo ? '视频通话' : '语音通话',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '来电中…',
                  style: TextStyle(fontSize: 14, color: Color(0xFF4ADE80)),
                ),

                const Spacer(),

                // Accept / Reject buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Reject
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              ref
                                  .read(callStateProvider.notifier)
                                  .rejectIncomingCall();
                            },
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFEF4444),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 36,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '拒绝',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      // Accept
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              ref
                                  .read(callStateProvider.notifier)
                                  .acceptIncomingCall();
                            },
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF22C55E),
                              ),
                              child: const Icon(
                                Icons.phone,
                                size: 36,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '接听',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
