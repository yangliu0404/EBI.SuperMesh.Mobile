import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';

/// Orders page for MeshPortal.
class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EbiAppBar(title: 'My Orders', showBack: false),
      body: const EbiEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No Orders',
        subtitle: 'Your orders and quotations will appear here.',
      ),
    );
  }
}
