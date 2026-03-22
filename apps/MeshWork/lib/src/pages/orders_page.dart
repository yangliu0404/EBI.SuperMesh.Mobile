import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';

/// Orders page placeholder.
class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EbiAppBar(title: context.L('Orders'), showBack: false),
      body: EbiEmptyState(
        icon: Icons.inventory_2_outlined,
        title: context.L('NoOrdersYet'),
        subtitle: context.L('NoOrdersDescription'),
      ),
    );
  }
}
