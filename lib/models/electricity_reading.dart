import 'model_helpers.dart';

class ElectricityReading {
  final String id;
  final String flatId;
  final String month;
  final double previousReading;
  final double currentReading;
  final double unitsUsed;
  final double billAmount;
  final DateTime createdAt;

  ElectricityReading({
    required this.id,
    required this.flatId,
    required this.month,
    required this.previousReading,
    required this.currentReading,
    double? unitsUsed,
    double? billAmount,
    double unitRate = 0,
    DateTime? createdAt,
  })  : unitsUsed = unitsUsed ?? (currentReading - previousReading),
        billAmount = billAmount ?? ((currentReading - previousReading) * unitRate),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'flatId': flatId,
    'month': month,
    'previousReading': previousReading,
    'currentReading': currentReading,
    'unitsUsed': unitsUsed,
    'billAmount': billAmount,
    'createdAt': createdAt,
  };

  factory ElectricityReading.fromMap(
    String id,
    Map<String, dynamic> map, {
    double unitRate = 0,
  }) =>
      ElectricityReading(
        id: id,
        flatId: map['flatId'] ?? '',
        month: map['month'] ?? '',
        previousReading: (map['previousReading'] ?? 0).toDouble(),
        currentReading: (map['currentReading'] ?? 0).toDouble(),
        unitsUsed: (map['unitsUsed'] ?? 0).toDouble(),
        billAmount: (map['billAmount'] ?? 0).toDouble(),
        unitRate: unitRate,
        createdAt: timestampToDateTime(map['createdAt']) ?? DateTime.now(),
      );
}
