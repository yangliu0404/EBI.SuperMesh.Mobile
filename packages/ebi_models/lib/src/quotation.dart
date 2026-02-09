/// Quotation status.
enum QuotationStatus { draft, sent, approved, rejected, expired }

/// Represents a price quotation sent to a client.
class Quotation {
  final String id;
  final String quotationNumber;
  final String projectId;
  final String? customerId;
  final String? customerName;
  final QuotationStatus status;
  final double totalAmount;
  final String currency;
  final DateTime? validUntil;
  final String? pdfUrl;
  final String? remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Quotation({
    required this.id,
    required this.quotationNumber,
    required this.projectId,
    this.customerId,
    this.customerName,
    required this.status,
    required this.totalAmount,
    this.currency = 'USD',
    this.validUntil,
    this.pdfUrl,
    this.remarks,
    this.createdAt,
    this.updatedAt,
  });

  bool get isExpired =>
      validUntil != null && validUntil!.isBefore(DateTime.now());

  factory Quotation.fromJson(Map<String, dynamic> json) {
    return Quotation(
      id: json['id'] as String,
      quotationNumber: json['quotation_number'] as String,
      projectId: json['project_id'] as String,
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String?,
      status: QuotationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => QuotationStatus.draft,
      ),
      totalAmount: (json['total_amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      validUntil: json['valid_until'] != null
          ? DateTime.parse(json['valid_until'] as String)
          : null,
      pdfUrl: json['pdf_url'] as String?,
      remarks: json['remarks'] as String?,
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
        'quotation_number': quotationNumber,
        'project_id': projectId,
        'customer_id': customerId,
        'customer_name': customerName,
        'status': status.name,
        'total_amount': totalAmount,
        'currency': currency,
        'valid_until': validUntil?.toIso8601String(),
        'pdf_url': pdfUrl,
        'remarks': remarks,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}
