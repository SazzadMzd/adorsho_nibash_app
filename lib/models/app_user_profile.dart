import 'model_helpers.dart';

class AppUserProfile {
  final String id;
  final String name;
  final String email;
  final bool isActive;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppUserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.isActive = true,
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'isActive': isActive,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory AppUserProfile.fromMap(String id, Map<String, dynamic> map) =>
      AppUserProfile(
        id: id,
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        isActive: map['isActive'] ?? true,
        notes: map['notes'] ?? '',
        createdAt: timestampToDateTime(map['createdAt']) ?? DateTime.now(),
        updatedAt: timestampToDateTime(map['updatedAt']) ?? DateTime.now(),
      );
}
