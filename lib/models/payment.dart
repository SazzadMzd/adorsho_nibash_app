class Payment {
  final String id;
  final String billId;
  final String tenantId;
  final double amount;
  final String method;
  final DateTime date;
  final String note;
  final String receiptNo;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.billId,
    required this.tenantId,
    required this.amount,
    this.method = 'cash',
    required this.date,
    this.note = '',
    this.receiptNo = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'billId': billId,
    'tenantId': tenantId,
    'amount': amount,
    'method': method,
    'date': date,
    'note': note,
    'receiptNo': receiptNo,
    'createdAt': createdAt,
  };

  factory Payment.fromMap(String id, Map<String, dynamic> map) => Payment(
    id: id,
    billId: map['billId'] ?? '',
    tenantId: map['tenantId'] ?? '',
    amount: (map['amount'] ?? 0).toDouble(),
    method: map['method'] ?? 'cash',
    date: (map['date'] as DateTime?) ?? DateTime.now(),
    note: map['note'] ?? '',
    receiptNo: map['receiptNo'] ?? '',
    createdAt: (map['createdAt'] as DateTime?) ?? DateTime.now(),
  );

  Payment copyWith({
    String? id,
    String? billId,
    String? tenantId,
    double? amount,
    String? method,
    DateTime? date,
    String? note,
    String? receiptNo,
    DateTime? createdAt,
  }) => Payment(
    id: id ?? this.id,
    billId: billId ?? this.billId,
    tenantId: tenantId ?? this.tenantId,
    amount: amount ?? this.amount,
    method: method ?? this.method,
    date: date ?? this.date,
    note: note ?? this.note,
    receiptNo: receiptNo ?? this.receiptNo,
    createdAt: createdAt ?? this.createdAt,
  );
}
