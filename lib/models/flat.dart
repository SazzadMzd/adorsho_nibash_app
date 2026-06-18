class Flat {
  final String id;
  final String flatNo;
  final String floor;
  final double rent;
  final double gas;
  final double water;
  final double garage;
  final String meterNo;
  final double unitRate;
  final bool isActive;
  final DateTime createdAt;

  Flat({
    required this.id,
    required this.flatNo,
    this.floor = '',
    required this.rent,
    this.gas = 0,
    this.water = 0,
    this.garage = 0,
    this.meterNo = '',
    this.unitRate = 0,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get totalFixedBills => rent + gas + water + garage;

  Map<String, dynamic> toMap() => {
    'flatNo': flatNo,
    'floor': floor,
    'rent': rent,
    'gas': gas,
    'water': water,
    'garage': garage,
    'meterNo': meterNo,
    'unitRate': unitRate,
    'isActive': isActive,
    'createdAt': createdAt,
  };

  factory Flat.fromMap(String id, Map<String, dynamic> map) => Flat(
    id: id,
    flatNo: map['flatNo'] ?? '',
    floor: map['floor'] ?? '',
    rent: (map['rent'] ?? 0).toDouble(),
    gas: (map['gas'] ?? 0).toDouble(),
    water: (map['water'] ?? 0).toDouble(),
    garage: (map['garage'] ?? 0).toDouble(),
    meterNo: map['meterNo'] ?? '',
    unitRate: (map['unitRate'] ?? 0).toDouble(),
    isActive: map['isActive'] ?? true,
    createdAt: (map['createdAt'] as DateTime?) ?? DateTime.now(),
  );

  Flat copyWith({
    String? id,
    String? flatNo,
    String? floor,
    double? rent,
    double? gas,
    double? water,
    double? garage,
    String? meterNo,
    double? unitRate,
    bool? isActive,
    DateTime? createdAt,
  }) => Flat(
    id: id ?? this.id,
    flatNo: flatNo ?? this.flatNo,
    floor: floor ?? this.floor,
    rent: rent ?? this.rent,
    gas: gas ?? this.gas,
    water: water ?? this.water,
    garage: garage ?? this.garage,
    meterNo: meterNo ?? this.meterNo,
    unitRate: unitRate ?? this.unitRate,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
  );
}
