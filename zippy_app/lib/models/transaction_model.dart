/// Represents a monetary transaction record on the Zippy platform matching the Appwrite transactions collection.
class TransactionModel {
  /// Unique transaction identifier or Appwrite document ID.
  final String id;

  /// Transaction category/type (e.g., 'MERCHANT_PAYMENT' or 'SPLIT_SETTLEMENT').
  final String type;

  /// Settlement status (e.g., 'SETTLED', 'PENDING', or 'FAILED').
  final String status;

  /// Payment gateway authorization reference code (e.g., Stitch CAP authorization).
  final String authCode;

  /// Total gross transaction amount in ZAR.
  final double grossAmount;

  /// Zippy platform service fee in ZAR.
  final double zippyFee;

  /// Net amount paid out to the merchant or host account in ZAR.
  final double netPayout;

  /// Unique idempotency key preventing duplicate payment processing.
  final String idempotencyKey;

  /// The timestamp when the transaction record was created.
  final DateTime createdAt;

  /// Optional name of the customer who sent the payment.
  final String? customerName;

  /// Creates a new [TransactionModel] instance.
  const TransactionModel({
    required this.id,
    required this.type,
    required this.status,
    required this.authCode,
    required this.grossAmount,
    required this.zippyFee,
    required this.netPayout,
    required this.idempotencyKey,
    required this.createdAt,
    this.customerName,
  });

  /// Constructs a [TransactionModel] from an Appwrite database document map.
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map[r'$id'] as String? ?? map['id'] as String? ?? '',
      type: map['type'] as String? ?? 'MERCHANT_PAYMENT',
      status: map['status'] as String? ?? 'SETTLED',
      authCode: map['authCode'] as String? ?? '',
      grossAmount: (map['grossAmount'] as num?)?.toDouble() ?? 0.0,
      zippyFee: (map['zippyFee'] as num?)?.toDouble() ?? 0.0,
      netPayout: (map['netPayout'] as num?)?.toDouble() ?? 0.0,
      idempotencyKey: map['idempotencyKey'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : (map[r'$createdAt'] != null
              ? DateTime.parse(map[r'$createdAt'] as String)
              : DateTime.now()),
      customerName: map['customerName'] as String?,
    );
  }

  /// Converts this transaction instance into a JSON-compatible map for Appwrite.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'status': status,
      'authCode': authCode,
      'grossAmount': grossAmount,
      'zippyFee': zippyFee,
      'netPayout': netPayout,
      'idempotencyKey': idempotencyKey,
      'createdAt': createdAt.toIso8601String(),
      if (customerName != null) 'customerName': customerName,
    };
  }
}
