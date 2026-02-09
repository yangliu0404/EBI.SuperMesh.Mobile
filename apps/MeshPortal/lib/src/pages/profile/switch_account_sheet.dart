import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';

/// Bottom sheet for switching between available tenants.
class SwitchAccountSheet extends ConsumerWidget {
  const SwitchAccountSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final tenants = authState.availableTenants;
    final currentTenant = authState.currentTenant;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: EbiColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Switch Account', style: EbiTextStyles.h3),
          const SizedBox(height: 8),
          if (tenants.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No other accounts available.',
                style: EbiTextStyles.bodyMedium.copyWith(
                  color: EbiColors.textSecondary,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: tenants.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16),
              itemBuilder: (context, index) {
                final tenant = tenants[index];
                final isSelected = currentTenant?.id == tenant.id;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: EbiColors.secondaryCyan.withValues(alpha: 0.1),
                    child: Text(
                      (tenant.displayName ?? tenant.name)
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        color: EbiColors.secondaryCyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  title: Text(
                    tenant.displayName ?? tenant.name,
                    style: EbiTextStyles.bodyLarge,
                  ),
                  subtitle: Text(tenant.name, style: EbiTextStyles.bodySmall),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: EbiColors.secondaryCyan)
                      : null,
                  onTap: () {
                    ref.read(authProvider.notifier).selectTenant(tenant);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
