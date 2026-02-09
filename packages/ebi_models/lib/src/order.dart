/// Order status within the supply chain lifecycle.
enum OrderStatus {
  draft,
  confirmed,
  inProduction,
  qualityCheck,
  shipped,
  delivered,
  completed,
  cancelled,
}

/// Represents a purchase order (PO).
class Order {
  final String id;
  final String orderNumber;
  final String projectId;
  final String? customerId;
  final String? customerName;
  final OrderStatus status;
  final double totalAmount;
  final String currency;
  final DateTime? orderDate;
  final DateTime? deliveryDate;
  final String? description;
  final List<OrderItem>? items;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.projectId,
    this.customerId,
    this.customerName,
    required this.status,
    required this.totalAmount,
    this.currency = 'USD',
    this.orderDate,
    this.deliveryDate,
    this.description,
    this.items,
    this.createdAt,
    this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String,
      projectId: json['project_id'] as String,
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String?,
      status: OrderStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => OrderStatus.draft,
      ),
      totalAmount: (json['total_amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      orderDate: json['order_date'] != null
          ? DateTime.parse(json['order_date'] as String)
          : null,
      deliveryDate: json['delivery_date'] != null
          ? DateTime.parse(json['delivery_date'] as String)
          : null,
      description: json['description'] as String?,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_number': orderNumber,
        'project_id': projectId,
        'customer_id': customerId,
        'customer_name': customerName,
        'status': status.name,
        'total_amount': totalAmount,
        'currency': currency,
        'order_date': orderDate?.toIso8601String(),
        'delivery_date': deliveryDate?.toIso8601String(),
        'description': description,
        'items': items?.map((e) => e.toJson()).toList(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}

/// A single line item in an order.
class OrderItem {
  final String id;
  final String productName;
  final String? sku;
  final int quantity;
  final double unitPrice;
  final String? unit;

  const OrderItem({
    required this.id,
    required this.productName,
    this.sku,
    required this.quantity,
    required this.unitPrice,
    this.unit,
  });

  double get subtotal => quantity * unitPrice;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      productName: json['product_name'] as String,
      sku: json['sku'] as String?,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      unit: json['unit'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_name': productName,
        'sku': sku,
        'quantity': quantity,
        'unit_price': unitPrice,
        'unit': unit,
      };
}
