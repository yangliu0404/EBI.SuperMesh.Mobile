import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/models/im_group_models.dart';
import 'package:ebi_chat/src/pages/user_settings_page.dart';
import 'package:ebi_chat/src/providers/chat_providers.dart';
import 'package:ebi_chat/src/pages/group_settings_page.dart';
import 'package:ebi_chat/src/widgets/forward_sheet.dart';
import 'package:ebi_chat/src/models/im_models.dart';
import 'package:ebi_chat/src/models/call_models.dart';
import 'package:ebi_chat/src/providers/call_providers.dart';
import 'package:ebi_chat/src/pages/outgoing_call_page.dart';

/// User profile page — DingDing exact visual match.
class UserProfilePage extends ConsumerStatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  ConsumerState<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends ConsumerState<UserProfilePage> {
  ImUserCard? _userCard;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserCard();
  }

  Future<void> _loadUserCard() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(groupApiServiceProvider);
      final card = await api.getUserCard(widget.userId);
      if (!mounted) return;
      setState(() {
        _userCard = card;
        _loading = false;
      });
    } catch (e) {
      AppLogger.error('[UserProfile] Failed to load', e);
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Center(child: EbiLoading(message: context.L('Loading'))),
      );
    }

    if (_userCard == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.L('UserInfo'))),
        body: const EbiEmptyState(icon: Icons.person_off, title: '无法获取用户信息'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Light gray background
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserSettingsPage(
                    userId: widget.userId,
                    userName: _userCard!.displayName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Top Gradient Background ─────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF3B82F6), // bright blue
                    Color(0xFF60A5FA), // lighter blue
                    Color(0xFF93C5FD), // soft blue
                  ],
                ),
              ),
              // Add some deco circles to mimic the DingDing wavy background
              child: Stack(
                children: [
                  Positioned(
                    top: -50,
                    right: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 100,
                    left: -80,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // ── Scrollable Content ──────────────────────────
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 100, bottom: 40),
                  children: [
                    // Top Identity Card
                    _buildIdentityCard(_userCard!),
                    
                    const SizedBox(height: 16),
                    
                    // Enterprise Info Card
                    _buildEnterpriseCard(_userCard!),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              // Bottom Action Bar
              _buildBottomBar(_userCard!),
            ],
          ),
        ],
      ),
    );
  }

  // ── Top Identity Card ──────────────────────────────────────────────────

  Widget _buildIdentityCard(ImUserCard card) {
    const double avatarSize = 100; // Increased avatar size
    const double overlapTop = 40;  // How much the card overlaps the gradient
    const double avatarTopOffset = 32; // Avatar moved higher up

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The white card body
          Container(
            margin: const EdgeInsets.only(top: overlapTop),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Empty space for avatar on left, Names on right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Padding to leave space for the avatar. 
                    // Width 124 ensures name starts after the 100px avatar + 24px gap.
                    // Height 56 ensures the row pushes down content below so avatar doesn't obscure it.
                    const SizedBox(width: 124, height: 56), 
                    // Name Section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (card.firstName != null || card.lastName != null) ...[
                            Text(
                              '${card.firstName ?? ''} ${card.lastName ?? ''}'.trim(),
                              style: const TextStyle(
                                fontSize: 24, // First line large
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111111),
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (card.nativeName != null && card.nativeName!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  card.nativeName!,
                                  style: const TextStyle(
                                    fontSize: 15, // Second line smaller
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF666666),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ] else ...[
                            // Fallback if no first/last name
                            Text(
                              card.fullName ?? card.displayName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111111),
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Add some space below the avatar/name row
                const SizedBox(height: 20),
                
                // Company / Auth Badge
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        (card.company?.isNotEmpty == true) ? card.company! : '默认企业/组织',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified, size: 12, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 4),
                          Text(context.L('EnterpriseMember'), style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Status Placeholder
                Row(
                  children: [
                    const Text('💻', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      card.online ? context.L('Online') : context.L('Offline'),
                      style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Bottom actions row (Schedule, Interactions, etc.)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _smallActionButton(Icons.calendar_month, context.L('Schedule'), const Color(0xFF10B981)),
                        const SizedBox(width: 16),
                        _smallActionButton(Icons.group_outlined, context.L('CommonConnections'), const Color(0xFF3B82F6)),
                      ],
                    ),
                    // Action Pill
                    GestureDetector(
                      onTap: () => _shareUser(card),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          context.L('ShareCard'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Overlapping Avatar (Squircle)
          Positioned(
            top: overlapTop - avatarTopOffset,
            left: 16,
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4FD),
                borderRadius: BorderRadius.circular(28), // Squircle effect
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                image: (card.avatarUrl != null && card.avatarUrl!.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(card.avatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: (card.avatarUrl == null || card.avatarUrl!.isEmpty)
                  ? Text(
                      card.displayName.isNotEmpty
                          ? card.displayName.characters.first
                          : '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B82F6),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallActionButton(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
        ),
      ],
    );
  }

  // ── Enterprise Info Card ───────────────────────────────────────────────

  Widget _buildEnterpriseCard(ImUserCard card) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header text
            Text(
              (card.company?.isNotEmpty == true) ? card.company! : '企业/组织信息',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 16),
            
            // Enterprise Rows
            _buildInfoRow('企业/组织', card.company, placeholder: '-'),
            _buildInfoRow('姓名', card.fullName ?? card.displayName, placeholder: '-'),
            _buildInfoRow('邮箱', card.email, placeholder: '未绑定'),
            _buildInfoRow('部门', card.department, placeholder: '未设置部门', hasArrow: true),
            _buildInfoRow('职位', card.position, placeholder: '未设置'),
            _buildInfoRow('工号', card.employeeNumber, placeholder: '-'),
            _buildInfoRow('手机号', card.phoneNumber, placeholder: '未绑定'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value, {required String placeholder, bool hasArrow = false}) {
    final displayValue = (value != null && value.isNotEmpty) ? value : placeholder;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF6B7280), // Gray text for label
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF111827), // Dark text for value
              ),
            ),
          ),
          if (hasArrow)
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFFD1D5DB)),
        ],
      ),
    );
  }

  // ── Bottom Action Bar ──────────────────────────────────────────────────

  Widget _buildBottomBar(ImUserCard card) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB), // Very light gray
        border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Send Message Button
            Expanded(
              flex: 3,
              child: _mainBottomButton(
                icon: Icons.chat_bubble_outline,
                label: context.L('SendMessage'),
                onTap: () => Navigator.of(context).pop(card.userId),
                primary: true,
              ),
            ),
            const SizedBox(width: 8),
            // Voice Call Button
            Expanded(
              flex: 2,
              child: _mainBottomButton(
                icon: Icons.call_outlined,
                label: context.L('Voice'),
                onTap: () {
                  ref.read(callStateProvider.notifier).startCall(
                    targetUserId: widget.userId,
                    targetUserName: card.displayName,
                    callType: CallType.voice,
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OutgoingCallPage()),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            // Video Call Button
            Expanded(
              flex: 2,
              child: _mainBottomButton(
                icon: Icons.videocam_outlined,
                label: context.L('Video'),
                onTap: () {
                  ref.read(callStateProvider.notifier).startCall(
                    targetUserId: widget.userId,
                    targetUserName: card.displayName,
                    callType: CallType.video,
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OutgoingCallPage()),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            // More Button
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: IconButton(
                icon: const Icon(Icons.more_horiz, color: Color(0xFF374151)),
                onPressed: () {
                   Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserSettingsPage(
                        userId: widget.userId,
                        userName: card.displayName,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mainBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: primary ? const Color(0xFF3B82F6) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: primary ? null : Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              size: 18, 
              color: primary ? Colors.white : const Color(0xFF3B82F6)
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: primary ? Colors.white : const Color(0xFF3B82F6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareUser(ImUserCard card) async {
    final target = await showForwardSheet(context, ref);
    if (target == null || !mounted) return;

    try {
      final repo = ref.read(chatRepositoryProvider);
      final currentUserId = ref.read(authProvider).user?.id ?? '';
      
      final cardContent = card.displayName;
      
      final extraProps = <String, dynamic>{
        'UserId': widget.userId,
        'UserName': card.displayName,
        if (card.avatarUrl != null) 'AvatarUrl': card.avatarUrl!,
      };

      final fwdMessage = ImChatMessage(
        messageId: '',
        formUserId: currentUserId,
        formUserName: '', // backend can fill
        toUserId: target.type == 'user' ? target.conversationKey : null,
        groupId: target.groupId ?? '',
        content: cardContent,
        sendTime: DateTime.now().toUtc().toIso8601String(),
        messageType: ImMessageType.contactCard.value,
        source: ImMessageSourceType.user.value,
        extraProperties: extraProps,
      );
      
      await repo.sendMessage(fwdMessage);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('名片已发送给 ${target.displayName}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    }
  }
}
