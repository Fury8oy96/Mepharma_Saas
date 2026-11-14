/// Enums used across the data and domain layers.
///
/// Stored as TEXT in the database (see tables.dart).
enum UserRole {
  admin,
  staff,
  superAdmin,
  branchAdmin,
  pharmacyAdmin,
  supervisor,
  pharmacist;

  bool get isSuperAdmin => this == UserRole.superAdmin;
  bool get isPharmacyAdmin =>
      this == UserRole.pharmacyAdmin ||
      this == UserRole.admin;
  bool get isBranchAdmin => this == UserRole.branchAdmin;
  bool get isAnyAdmin => isSuperAdmin || isPharmacyAdmin || isBranchAdmin;
  bool get isSupervisor => this == UserRole.supervisor;
  bool get isPharmacist => this == UserRole.pharmacist || this == UserRole.staff;
  bool get isStaff => isPharmacist || isSupervisor;
  bool get isDesktopPosUser =>
      isPharmacist ||
      isSupervisor ||
      isPharmacyAdmin ||
      isBranchAdmin;
  bool get canAuthorizeSupervisor =>
      isSupervisor ||
      isPharmacyAdmin ||
      isBranchAdmin;
  bool get canApprovePurchases =>
      isBranchAdmin ||
      isPharmacyAdmin ||
      isSupervisor;
}

enum DiscountType { percentage, fixed }

enum SaleStatus { completed, returned, voided }

enum BackupStatus { success, failed }
