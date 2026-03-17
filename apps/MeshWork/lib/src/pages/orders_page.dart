import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';

/// Orders page placeholder.
class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EbiAppBar(title: 'Orders', showBack: false),
      body: const EbiEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No Orders Yet',
        subtitle: 'Your assigned orders will appear here.',
      ),
    );
  }
}
