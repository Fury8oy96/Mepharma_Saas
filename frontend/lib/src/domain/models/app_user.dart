import '../../data/db/enums.dart';

/// Domain representation of an authenticated user.
class AppUser {
  const AppUser({
    required this.id,
    this.name,
    required this.username,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.branchId = 1,
  });

  final int id;
  final String? name;
  final String username;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;
  final int branchId;

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name!.trim() : username;

  bool get isSuperAdmin => role.isSuperAdmin;
  bool get isPharmacyAdmin => role.isPharmacyAdmin;
  bool get isBranchAdmin => role.isBranchAdmin;
  bool get isAdmin => role.isAnyAdmin;
  bool get isStaff => role.isStaff;
  bool get canAuthorizeSupervisor => role.canAuthorizeSupervisor;
  bool get canApprovePurchases => role.canApprovePurchases;
}
