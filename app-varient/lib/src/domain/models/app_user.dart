import '../../data/db/enums.dart';

/// Domain representation of an authenticated user.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.branchId = 1,
  });

  final int id;
  final String username;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;
  final int branchId;

  bool get isSuperAdmin => role.isSuperAdmin;
  bool get isPharmacyAdmin => role.isPharmacyAdmin;
  bool get isBranchAdmin => role.isBranchAdmin;
  bool get isAdmin => role.isAnyAdmin;
  bool get isStaff => role.isStaff;
  bool get canAuthorizeSupervisor => role.canAuthorizeSupervisor;
  bool get canApprovePurchases => role.canApprovePurchases;
}
