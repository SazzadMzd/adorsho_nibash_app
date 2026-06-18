class SecurityTransaction {
  final String id;
  final String tenantId;
  final String type;
  final double amount;
  final DateTime date;
  final String note;
  final DateTime createdAt;

  SecurityTransaction({
    required this.id,
    required this.tenantId,
    required this.type,
    required this.amount,
    required this.date,
    this.note = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'tenantId': tenantId,
    'type': type,
    'amount': amount,
    'date': date,
    'note': note,
    'createdAt': createdAt,
  };

  factory SecurityTransaction.fromMap(String id, Map<String, dynamic> map) =>
      SecurityTransaction(
        id: id,
        tenantId: map['tenantId'] ?? '',
        type: map['type'] ?? 'deposit',
        amount: (map['amount'] ?? 0).toDouble(),
        date: (map['date'] as DateTime?) ?? DateTime.now(),
        note: map['note'] ?? '',
        createdAt: (map['createdAt'] as DateTime?) ?? DateTime.now(),
      );
}
