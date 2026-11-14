import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../app/providers.dart';
import '../common/network_status_banner.dart';
import '../common/language_switcher.dart';
import '../common/theme_mode_switcher.dart';
import '../session/session_controller.dart';
import '../settings/hardware_devices_section.dart';
import '../common/update_notification_dialog.dart';
import 'navigation.dart';

/// Modern Vuexy-inspired Shell: collapsible/expandable grouped sidebar,
/// breadcrumb navigation, live sync telemetry, and adaptive dark/light aesthetic.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;
  static bool _hasCheckedUpdateToday = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    if (user == null) {
      return Scaffold(body: child);
    }

    // Watch background sync listener to ensure events are processed
    ref.watch(syncEventListener);

    final theme = Theme.of(context);
    final isExpanded = ref.watch(sidebarExpandedProvider);

    // Listen to events stream to show SnackBar alerts to the branch user
    ref.listen<AsyncValue<String>>(syncEventsProvider, (prev, next) {
      if (next.hasValue) {
        final data = next.value!;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final eventName = json['event'] as String?;
          if (eventName == 'purchase_approved') {
            final invoice = json['invoice_number'] as String?;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Purchase request $invoice has been approved and stock is restocked!',
                ),
                backgroundColor: theme.colorScheme.primary,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } catch (_) {}
      }
    });

    final location = GoRouterState.of(context).uri.path;
    final activeSection = appSections.firstWhere(
      (s) => s.path == location,
      orElse: () => appSections.first,
    );
    final l10n = AppLocalizations.of(context);

    // Daily Background Update Check (Non-intrusive)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_hasCheckedUpdateToday) {
        _hasCheckedUpdateToday = true;
        final updateService = ref.read(updateCheckerServiceProvider);
        final updateInfo = await updateService.checkForUpdate(force: false);
        if (updateInfo != null && context.mounted) {
          UpdateNotificationDialog.show(
            context,
            updateInfo: updateInfo,
            onDismissPermanently: () => updateService.dismissVersion(updateInfo.version),
          );
        }
      }
    });

    return Scaffold(
      body: Row(
        children: [
          // Collapsible / Expandable Sidebar
          _ModernSidebar(
            isExpanded: isExpanded,
            currentPath: location,
            userRole: user.role,
            username: user.username,
            onToggle: () {
              ref.read(sidebarExpandedProvider.notifier).state = !isExpanded;
            },
            onNavigate: (path) => context.go(path),
            onLogout: () => ref.read(sessionProvider.notifier).logout(),
          ),

          // Main Page Content with Floating Top Header
          Expanded(
            child: Column(
              children: [
                _ModernHeader(
                  activeSection: activeSection,
                  username: user.username,
                  roleLabel: user.role.isSuperAdmin
                      ? l10n.superAdminRole
                      : (user.role.isBranchAdmin ? l10n.branchAdminRole : l10n.roleStaff),
                  onLogout: () => ref.read(sessionProvider.notifier).logout(),
                ),
                const NetworkStatusBanner(),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernSidebar extends StatelessWidget {
  const _ModernSidebar({
    required this.isExpanded,
    required this.currentPath,
    required this.userRole,
    required this.username,
    required this.onToggle,
    required this.onNavigate,
    required this.onLogout,
  });

  final bool isExpanded;
  final String currentPath;
  final dynamic userRole;
  final String username;
  final VoidCallback onToggle;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;

  List<Widget> _buildNavigationList(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final widgets = <Widget>[];

    for (final cat in NavigationCategory.values) {
      final items = appSections
          .where((s) => s.category == cat && s.isVisibleTo(userRole))
          .toList();

      if (items.isEmpty) continue;

      if (isExpanded) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 14, bottom: 6),
            child: Text(
              cat.label(l10n).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(height: 8, thickness: 0.5),
          ),
        );
      }

      for (final section in items) {
        widgets.add(
          _SidebarNavItem(
            section: section,
            isSelected: currentPath == section.path,
            isExpanded: isExpanded,
            onTap: () => onNavigate(section.path),
          ),
        );
        widgets.add(const SizedBox(height: 2));
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.localeName.startsWith('ar');
    final width = isExpanded ? 248.0 : 76.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      width: width,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Sidebar Top Brand Header
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: isExpanded ? 16 : 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showFullHeader = isExpanded && constraints.maxWidth > 140;
                return ClipRect(
                  child: Row(
                    mainAxisAlignment: showFullHeader
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.asset(
                                'assets/logo/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          if (showFullHeader) ...[
                            const SizedBox(width: 10),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppConstants.appName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Text(
                                  isArabic ? 'نظام التشغيل الصيدلاني' : 'OPERATING SYSTEM',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      if (showFullHeader)
                        IconButton(
                          icon: Icon(
                            Icons.menu_open,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          tooltip: isArabic ? 'طي القائمة الجانبية' : 'Collapse Sidebar',
                          onPressed: onToggle,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Categorized Navigation List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              children: _buildNavigationList(context, theme, l10n),
            ),
          ),

          // Sidebar Footer: Expand button (when collapsed) & User Profile
          if (!isExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IconButton(
                icon: Icon(
                  Icons.menu,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: isArabic ? 'توسيع القائمة الجانبية' : 'Expand Sidebar',
                onPressed: onToggle,
              ),
            ),

          Container(
            padding: EdgeInsets.all(isExpanded ? 12 : 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showFullProfile = isExpanded && constraints.maxWidth > 140;
                if (!showFullProfile) {
                  return Tooltip(
                    message: '$username (${l10n.logout})',
                    child: InkWell(
                      onTap: onLogout,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            username.isNotEmpty ? username[0].toUpperCase() : 'U',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return ClipRect(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          username.isNotEmpty ? username[0].toUpperCase() : 'U',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              isArabic ? 'جلسة نشطة' : 'Active Session',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, size: 18),
                        tooltip: l10n.logout,
                        onPressed: onLogout,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.section,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  final AppSection section;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final label = section.label(l10n);

    final bg = isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
        : Colors.transparent;
    final fg = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.05),
        child: Container(
          height: 42,
          padding: EdgeInsets.symmetric(horizontal: isExpanded ? 12 : 0),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showText = isExpanded && constraints.maxWidth > 80;
              return ClipRect(
                child: Row(
                  mainAxisAlignment: showText
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Icon(
                        section.icon,
                        color: fg,
                        size: 20,
                      ),
                    ),
                    if (showText) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: fg,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    if (!isExpanded) {
      return Tooltip(
        message: label,
        preferBelow: false,
        child: tile,
      );
    }

    return tile;
  }
}

class _ModernHeader extends ConsumerWidget {
  const _ModernHeader({
    required this.activeSection,
    required this.username,
    required this.roleLabel,
    required this.onLogout,
  });

  final AppSection activeSection;
  final String username;
  final String roleLabel;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final monitor = ref.watch(networkMonitorProvider);
    final isOnline = monitor.isOnline;
    final isSyncing = monitor.isSyncing;

    final badgeColor = isSyncing
        ? const Color(0xFF0091FF)
        : (isOnline ? const Color(0xFF28C76F) : const Color(0xFFFF9F43));

    final isArabic = l10n.localeName.startsWith('ar');
    final badgeText = isSyncing
        ? (isArabic ? 'جاري المزامنة...' : 'Syncing...')
        : (isOnline
            ? (isArabic ? 'متصل مباشر' : 'Live Online')
            : (isArabic ? 'غير متصل (محلي)' : 'Offline (Local)'));

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Breadcrumbs (Scrollable to prevent any header overflow)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    activeSection.category.label(l10n),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '/',
                      style: TextStyle(color: theme.colorScheme.outlineVariant),
                    ),
                  ),
                  Text(
                    activeSection.label(l10n),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Live Sync Telemetry Indicator (Dynamic)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Compact Theme Mode Switcher
          const ThemeModeSwitcher(),
          const SizedBox(width: 8),

          // Language Switcher
          const LanguageSwitcher(),
          const SizedBox(width: 8),

          // Quick Hardware & Devices Setup (accessible to all POS operators & managers)
          IconButton(
            icon: const Icon(Icons.print_outlined, size: 20),
            tooltip: Localizations.localeOf(context).languageCode == 'ar'
                ? 'إدارة الطابعات والأجهزة المتصلة'
                : 'Connected Hardware & Printers',
            onPressed: () => HardwareDevicesDialog.show(context),
          ),
          const SizedBox(width: 10),

          // User Profile Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  roleLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: l10n.logout,
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}
