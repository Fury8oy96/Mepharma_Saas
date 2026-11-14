import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models/api_config.dart';
import '../l10n/generated/app_localizations.dart';
import '../presentation/auth/login_page.dart';
import '../presentation/backup/backup_page.dart';
import '../presentation/categories/categories_page.dart';
import '../presentation/common/placeholder_page.dart';
import '../presentation/customers/customers_page.dart';
import '../presentation/dashboard/dashboard_page.dart';
import '../presentation/expiry/expiry_page.dart';
import '../presentation/pos/pos_page.dart';
import '../presentation/products/products_page.dart';
import '../presentation/purchases/purchases_page.dart';
import '../presentation/reports/reports_page.dart';
import '../presentation/returns/returns_page.dart';
import '../presentation/sales/sales_history_page.dart';
import '../presentation/session/session_controller.dart';
import '../presentation/settings/settings_page.dart';
import '../presentation/setup/setup_wizard_page.dart';
import '../presentation/shell/app_shell.dart';
import '../presentation/shell/navigation.dart';
import '../presentation/suppliers/suppliers_page.dart';
import '../presentation/users/users_page.dart';
import 'providers.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  final sessionSub = ref.listen(sessionProvider, (_, _) => refresh.value++);
  final configSub = ref.listen(apiConfigProvider, (_, _) => refresh.value++);
  ref.onDispose(() {
    sessionSub.close();
    configSub.close();
  });

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) {
      final config = ref.read(apiConfigProvider);
      final atSetup = state.matchedLocation == '/setup';

      // If POS terminal is unconfigured in online mode, force Setup Wizard.
      // Standalone local offline mode bypasses online server setup.
      if (!config.isConfigured && config.mode != DatabaseMode.local) {
        return atSetup ? null : '/setup';
      }

      final user = ref.read(sessionProvider);
      final isLoggedIn = user != null;
      final atLogin = state.matchedLocation == '/login';

      if (!isLoggedIn) {
        // Allow unauthenticated access to setup if manually requested (e.g. license renewal)
        if (atSetup) return null;
        return atLogin ? null : '/login';
      }

      if (atLogin || atSetup) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/setup',
        name: 'setup',
        builder: (context, state) => const SetupWizardPage(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          for (final section in appSections)
            if (section.path != '/dashboard')
              GoRoute(
                path: section.path,
                name: section.name,
                redirect: (context, state) {
                  final user = ref.read(sessionProvider);
                  if (user != null) {
                    if (section.superAdminOnly && !user.role.isSuperAdmin) {
                      return '/dashboard';
                    }
                    if (section.adminOnly && !user.isAdmin) {
                      return '/dashboard';
                    }
                  }
                  return null;
                },
                builder: (context, state) => _sectionPage(context, section),
              ),
        ],
      ),
    ],
  );
});

Widget _sectionPage(BuildContext context, AppSection section) {
  switch (section.name) {
    case 'pos':
      return const PosPage();
    case 'sales':
      return const SalesHistoryPage();
    case 'returns':
      return const ReturnsPage();
    case 'products':
      return const ProductsPage();
    case 'categories':
      return const CategoriesPage();
    case 'customers':
      return const CustomersPage();
    case 'expiry':
      return const ExpiryPage();
    case 'suppliers':
      return const SuppliersPage();
    case 'purchases':
      return const PurchasesPage();
    case 'users':
      return const UsersPage();
    case 'reports':
      return const ReportsPage();
    case 'settings':
      return const SettingsPage();
    case 'backup':
      return const BackupPage();
    default:
      return PlaceholderPage(
        title: section.label(AppLocalizations.of(context)),
        icon: section.icon,
      );
  }
}
