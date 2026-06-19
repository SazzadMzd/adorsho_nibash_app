import 'model_helpers.dart';

class Tenant {
  final String id;
  final String name;
  final String phone;
  final String nid;
  final String nidImageUrl;
  final String flatId;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final double securityDeposit;
  final String status;

  Tenant({
    required this.id,
    required this.name,
    this.phone = '',
    this.nid = '',
    this.nidImageUrl = '',
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
    'nid': nid,
    'nidImageUrl': nidImageUrl,
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
    nid: map['nid'] ?? '',
    nidImageUrl: map['nidImageUrl'] ?? '',
    flatId: map['flatId'] ?? '',
    joinedAt: timestampToDateTime(map['joinedAt']) ?? DateTime.now(),
    leftAt: timestampToDateTime(map['leftAt']),
    securityDeposit: (map['securityDeposit'] ?? 0).toDouble(),
    status: map['status'] ?? 'active',
  );

  Tenant copyWith({
    String? id,
    String? name,
    String? phone,
    String? nid,
    String? nidImageUrl,
    String? flatId,
    DateTime? joinedAt,
    DateTime? leftAt,
    double? securityDeposit,
    String? status,
  }) => Tenant(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    nid: nid ?? this.nid,
    nidImageUrl: nidImageUrl ?? this.nidImageUrl,
    flatId: flatId ?? this.flatId,
    joinedAt: joinedAt ?? this.joinedAt,
    leftAt: leftAt ?? this.leftAt,
    securityDeposit: securityDeposit ?? this.securityDeposit,
    status: status ?? this.status,
  );
}
