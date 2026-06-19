import 'model_helpers.dart';

class Bill {
  final String id;
  final String tenantId;
  final String flatId;
  final String month;
  final double rent;
  final double gas;
  final double water;
  final double garage;
  final double electricity;
  final double total;
  final double paidAmount;
  final String status;
  final double prevMeterReading;
  final double currentMeterReading;
  final String signedBy;
  final DateTime createdAt;

  Bill({
    required this.id,
    required this.tenantId,
    required this.flatId,
    required this.month,
    this.rent = 0,
    this.gas = 0,
    this.water = 0,
    this.garage = 0,
    this.electricity = 0,
    double? total,
    this.paidAmount = 0,
    this.status = 'pending',
    this.prevMeterReading = 0,
    this.currentMeterReading = 0,
    this.signedBy = '',
    DateTime? createdAt,
  })  : total = total ?? (rent + gas + water + garage + electricity),
        createdAt = createdAt ?? DateTime.now();

  double get due => total - paidAmount;
  bool get isPaid => paidAmount >= total;
  bool get isPartial => paidAmount > 0 && paidAmount < total;
  bool get isPending => paidAmount == 0;

  String get computedStatus {
    if (paidAmount >= total) return 'paid';
    if (paidAmount > 0) return 'partial';
    return 'pending';
  }

  Map<String, dynamic> toMap() => {
    'tenantId': tenantId,
    'flatId': flatId,
    'month': month,
    'rent': rent,
    'gas': gas,
    'water': water,
    'garage': garage,
    'electricity': electricity,
    'total': total,
    'paidAmount': paidAmount,
    'status': status,
    'prevMeterReading': prevMeterReading,
    'currentMeterReading': currentMeterReading,
    'signedBy': signedBy,
    'createdAt': createdAt,
  };

  factory Bill.fromMap(String id, Map<String, dynamic> map) => Bill(
    id: id,
    tenantId: map['tenantId'] ?? '',
    flatId: map['flatId'] ?? '',
    month: map['month'] ?? '',
    rent: (map['rent'] ?? 0).toDouble(),
    gas: (map['gas'] ?? 0).toDouble(),
    water: (map['water'] ?? 0).toDouble(),
    garage: (map['garage'] ?? 0).toDouble(),
    electricity: (map['electricity'] ?? 0).toDouble(),
    total: (map['total'] ?? 0).toDouble(),
    paidAmount: (map['paidAmount'] ?? 0).toDouble(),
    status: map['status'] ?? 'pending',
    prevMeterReading: (map['prevMeterReading'] ?? 0).toDouble(),
    currentMeterReading: (map['currentMeterReading'] ?? 0).toDouble(),
    signedBy: map['signedBy'] ?? '',
    createdAt: timestampToDateTime(map['createdAt']) ?? DateTime.now(),
  );

  Bill copyWith({
    String? id,
    String? tenantId,
    String? flatId,
    String? month,
    double? rent,
    double? gas,
    double? water,
    double? garage,
    double? electricity,
    double? total,
    double? paidAmount,
    String? status,
    double? prevMeterReading,
    double? currentMeterReading,
    String? signedBy,
    DateTime? createdAt,
  }) => Bill(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    flatId: flatId ?? this.flatId,
    month: month ?? this.month,
    rent: rent ?? this.rent,
    gas: gas ?? this.gas,
    water: water ?? this.water,
    garage: garage ?? this.garage,
    electricity: electricity ?? this.electricity,
    total: total ?? this.total,
    paidAmount: paidAmount ?? this.paidAmount,
    status: status ?? this.status,
    prevMeterReading: prevMeterReading ?? this.prevMeterReading,
    currentMeterReading: currentMeterReading ?? this.currentMeterReading,
    signedBy: signedBy ?? this.signedBy,
    createdAt: createdAt ?? this.createdAt,
  );
}
