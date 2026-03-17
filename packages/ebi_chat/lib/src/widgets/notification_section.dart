import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';

/// Notification category model for the message center.
class NotificationCategory {
  final IconData icon;
  final String title;
  final int count;
  final Color color;

  const NotificationCategory({
    required this.icon,
    required this.title,
    this.count = 0,
    required this.color,
  });
}

/// Horizontal scrollable notification icons at the top of the Messages page.
class NotificationSection extends StatelessWidget {
  const NotificationSection({super.key});

  static const _categories = [
    NotificationCategory(
      icon: Icons.local_shipping,
      title: 'Logistics',
      count: 3,
      color: Color(0xFF3B82F6),
    ),
    NotificationCategory(
      icon: Icons.receipt_long,
      title: 'Orders',
      count: 1,
      color: Color(0xFFF59E0B),
    ),
    NotificationCategory(
      icon: Icons.verified,
      title: 'QC',
      count: 0,
      color: Color(0xFF22C55E),
    ),
    NotificationCategory(
      icon: Icons.payments,
      title: 'Payments',
      count: 2,
      color: Color(0xFF8B5CF6),
    ),
    NotificationCategory(
      icon: Icons.campaign,
      title: 'Announcements',
      count: 0,
      color: Color(0xFFEC4899),
    ),
    NotificationCategory(
      icon: Icons.inventory,
      title: 'Inventory',
      count: 4,
      color: Color(0xFF14B8A6),
    ),
    NotificationCategory(
      icon: Icons.schedule,
      title: 'Deadlines',
      count: 1,
      color: Color(0xFFEF4444),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) =>
            _buildCategoryIcon(_categories[index], context),
      ),
    );
  }

  Widget _buildCategoryIcon(NotificationCategory cat, BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${cat.title} — coming in Phase 1'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 24),
                ),
                if (cat.count > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: EbiColors.error,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: EbiColors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(
                        '${cat.count}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: EbiColors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              cat.title,
              style: EbiTextStyles.labelSmall.copyWith(fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
