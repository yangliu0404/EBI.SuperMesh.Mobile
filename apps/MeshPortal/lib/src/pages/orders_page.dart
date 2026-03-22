import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';

/// Orders page for MeshPortal.
class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EbiAppBar(title: context.L('MyOrders'), showBack: false),
      body: EbiEmptyState(
        icon: Icons.receipt_long_outlined,
        title: context.L('NoOrders'),
        subtitle: context.L('NoOrdersPortalDescription'),
      ),
    );
  }
}
