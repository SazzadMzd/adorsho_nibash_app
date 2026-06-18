class Tenant {
  final String id;
  final String name;
  final String phone;
  final String whatsapp;
  final String flatId;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final double securityDeposit;
  final String status;

  Tenant({
    required this.id,
    required this.name,
    this.phone = '',
    this.whatsapp = '',
    required this.flatId,
    required this.joinedAt,
    this.leftAt,
    this.securityDeposit = 0,
    this.status = 'active',
  });

  bool get isActive => status == 'active';

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'whatsapp': whatsapp,
    'flatId': flatId,
    'joinedAt': joinedAt,
    'leftAt': leftAt,
    'securityDeposit': securityDeposit,
    'status': status,
  };

  factory Tenant.fromMap(String id, Map<String, dynamic> map) => Tenant(
    id: id,
    name: map['name'] ?? '',
    phone: map['phone'] ?? '',
    whatsapp: map['whatsapp'] ?? '',
    flatId: map['flatId'] ?? '',
    joinedAt: (map['joinedAt'] as DateTime?) ?? DateTime.now(),
    leftAt: map['leftAt'] as DateTime?,
    securityDeposit: (map['securityDeposit'] ?? 0).toDouble(),
    status: map['status'] ?? 'active',
  );

  Tenant copyWith({
    String? id,
    String? name,
    String? phone,
    String? whatsapp,
    String? flatId,
    DateTime? joinedAt,
    DateTime? leftAt,
    double? securityDeposit,
    String? status,
  }) => Tenant(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    whatsapp: whatsapp ?? this.whatsapp,
    flatId: flatId ?? this.flatId,
    joinedAt: joinedAt ?? this.joinedAt,
    leftAt: leftAt ?? this.leftAt,
    securityDeposit: securityDeposit ?? this.securityDeposit,
    status: status ?? this.status,
  );
}
