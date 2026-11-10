import 'package:flutter/material.dart';

import '../../data/db/enums.dart';
import '../../l10n/generated/app_localizations.dart';

/// Navigation section categories for clear visual hierarchy.
enum NavigationCategory {
  operations,
  inventory,
  commercial,
  admin;

  String label(AppLocalizations l10n) {
    final isArabic = l10n.localeName.startsWith('ar');
    switch (this) {
      case NavigationCategory.operations:
        return isArabic ? 'العمليات' : 'Operations';
      case NavigationCategory.inventory:
        return isArabic ? 'المخزون والمستودع' : 'Inventory & Stock';
      case NavigationCategory.commercial:
        return isArabic ? 'الشبكة التجارية' : 'Commercial Network';
      case NavigationCategory.admin:
        return isArabic ? 'الإدارة والنظام' : 'Administration';
    }
  }
}

/// A top-level navigation section shown in the sidebar.
class AppSection {
  const AppSection({
    required this.name,
    required this.path,
    required this.icon,
    this.category = NavigationCategory.operations,
    this.adminOnly = false,
    this.superAdminOnly = false,
  });

  final String name;
  final String path;
  final IconData icon;
  final NavigationCategory category;
  final bool adminOnly;
  final bool superAdminOnly;

  bool isVisibleTo(UserRole role) {
    if (superAdminOnly) {
      return role.isSuperAdmin;
    }
    if (adminOnly) {
      return role.isAnyAdmin;
    }
    return true;
  }

  String label(AppLocalizations l10n) {
    switch (name) {
      case 'dashboard':
        return l10n.dashboard;
      case 'pos':
        return l10n.pos;
      case 'sales':
        return l10n.salesHistory;
      case 'products':
        return l10n.products;
      case 'categories':
        return l10n.categories;
      case 'customers':
        return l10n.customers;
      case 'expiry':
        return l10n.expiry;
      case 'suppliers':
        return l10n.suppliers;
      case 'purchases':
        return l10n.purchases;
      case 'users':
        return l10n.users;
      case 'reports':
        return l10n.reports;
      case 'settings':
        return l10n.settings;
      case 'backup':
        return l10n.backup;
      default:
        return name;
    }
  }
}

const appSections = <AppSection>[
  // Operations & POS
  AppSection(
    name: 'dashboard',
    path: '/dashboard',
    icon: Icons.dashboard_outlined,
    category: NavigationCategory.operations,
    adminOnly: false,
  ),
  AppSection(
    name: 'pos',
    path: '/pos',
    icon: Icons.point_of_sale_outlined,
    category: NavigationCategory.operations,
    adminOnly: false,
  ),
  AppSection(
    name: 'sales',
    path: '/sales',
    icon: Icons.receipt_long_outlined,
    category: NavigationCategory.operations,
    adminOnly: false,
  ),

  // Inventory & Stock
  AppSection(
    name: 'products',
    path: '/products',
    icon: Icons.medication_outlined,
    category: NavigationCategory.inventory,
    adminOnly: false,
  ),
  AppSection(
    name: 'purchases',
    path: '/purchases',
    icon: Icons.inventory_2_outlined,
    category: NavigationCategory.inventory,
    adminOnly: true,
  ),
  AppSection(
    name: 'categories',
    path: '/categories',
    icon: Icons.category_outlined,
    category: NavigationCategory.inventory,
    adminOnly: true,
  ),
  AppSection(
    name: 'expiry',
    path: '/expiry',
    icon: Icons.event_busy_outlined,
    category: NavigationCategory.inventory,
    adminOnly: true,
  ),

  // Commercial & CRM
  AppSection(
    name: 'customers',
    path: '/customers',
    icon: Icons.people_outline,
    category: NavigationCategory.commercial,
    adminOnly: false,
  ),
  AppSection(
    name: 'suppliers',
    path: '/suppliers',
    icon: Icons.local_shipping_outlined,
    category: NavigationCategory.commercial,
    adminOnly: true,
  ),

  // Administration & Security (Settings is strictly SuperAdmin)
  AppSection(
    name: 'reports',
    path: '/reports',
    icon: Icons.insert_chart_outlined,
    category: NavigationCategory.admin,
    adminOnly: true,
  ),
  AppSection(
    name: 'users',
    path: '/users',
    icon: Icons.group_outlined,
    category: NavigationCategory.admin,
    adminOnly: true,
  ),
  AppSection(
    name: 'settings',
    path: '/settings',
    icon: Icons.settings_outlined,
    category: NavigationCategory.admin,
    adminOnly: true,
  ),
  AppSection(
    name: 'backup',
    path: '/backup',
    icon: Icons.backup_outlined,
    category: NavigationCategory.admin,
    superAdminOnly: true,
  ),
];
