import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/utils/money.dart';
import '../../domain/models/app_product.dart';
import '../../domain/models/app_sale.dart';
import '../../domain/models/report_depth.dart';
import '../../domain/models/staff_product_feedback.dart';
import '../../l10n/generated/app_localizations.dart';
import '../products/staff_feedback_dialog.dart';
import '../purchases/purchase_form_dialog.dart';
import '../session/session_controller.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(sessionProvider);
    
    String roleLabel = l10n.roleStaff;
    if (user?.isSuperAdmin == true) {
      roleLabel = l10n.superAdminRole;
    } else if (user?.isBranchAdmin == true) {
      roleLabel = l10n.branchAdminRole;
    } else if (user?.isAdmin == true) {
      roleLabel = l10n.roleAdmin;
    }

    final isAnyAdmin = user?.isAdmin == true;
    final lowStock = ref.watch(lowStockProductsProvider).valueOrNull ?? const [];
    final expiring = ref.watch(expiringProductsProvider).valueOrNull ?? const [];
    final todaySales = ref.watch(todaySalesProvider).valueOrNull;
    final currency = ref.watch(storeSettingsProvider).valueOrNull?.currencySymbol ?? r'$';
    final stockValuation = ref.watch(stockValuationProvider).valueOrNull;
    final purchases = ref.watch(purchaseListProvider).valueOrNull ?? const [];
    final pendingPurchases = purchases.where((p) => p.isPending).length;

    final staffFeedbacks = (user?.isBranchAdmin == true || user?.isAdmin == true)
        ? (ref.watch(branchStaffFeedbacksProvider(user?.branchId)).valueOrNull ??
            const <StaffProductFeedback>[])
        : const <StaffProductFeedback>[];

    final recentSales = ref
            .watch(
              salesHistoryListProvider(const (
                from: null,
                to: null,
                paymentMethod: null,
                status: null,
                search: null,
              )),
            )
            .valueOrNull ??
        const [];

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.welcomeBack(user?.username ?? ''),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.welcomeBackMessage(roleLabel),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isAnyAdmin
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (isAnyAdmin
                                ? theme.colorScheme.primary
                                : theme.colorScheme.secondary)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAnyAdmin ? Icons.verified_user : Icons.badge_outlined,
                          size: 18,
                          color: isAnyAdmin
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          roleLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isAnyAdmin
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // KPI Row
              SizedBox(
                height: 140,
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.point_of_sale,
                        title: l10n.pos,
                        subtitle: l10n.quickSale,
                        onTap: () => context.go('/pos'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.payments_outlined,
                        title: todaySales == null
                            ? '0'
                            : formatMoney(
                                todaySales.netRevenue,
                                symbol: currency,
                              ),
                        subtitle: '${l10n.todaySales} (${l10n.txCount(todaySales?.salesCount ?? 0)})',
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.warning_amber_rounded,
                        title: '${lowStock.length}',
                        subtitle: l10n.lowStockItems,
                        highlight: lowStock.isNotEmpty,
                        color: Colors.amber.shade800,
                        onTap: isAnyAdmin ? () => context.go('/products') : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.event_busy_outlined,
                        title: '${expiring.length}',
                        subtitle: l10n.expiringSoon,
                        highlight: expiring.isNotEmpty,
                        color: Colors.deepOrange,
                        onTap: isAnyAdmin ? () => context.go('/expiry') : null,
                      ),
                    ),
                  ],
                ),
              ),

              // Admin Secondary Metrics Row (Pending Purchases, Profit, Inventory Value)
              if (isAnyAdmin) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _AdminMiniStatCard(
                        icon: Icons.inventory_2_outlined,
                        title: l10n.pendingPurchases,
                        value: l10n.ordersCount(pendingPurchases),
                        color: Colors.blue,
                        onTap: () => context.go('/purchases'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _AdminMiniStatCard(
                        icon: Icons.pie_chart_outline,
                        title: l10n.estStockValuation,
                        value: stockValuation == null
                            ? '$currency 0'
                            : formatMoney(stockValuation.retailValue, symbol: currency),
                        color: Colors.teal,
                        onTap: () => context.go('/reports'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _AdminMiniStatCard(
                        icon: Icons.trending_up,
                        title: l10n.grossMarginCogs,
                        value: todaySales == null
                            ? '$currency 0'
                            : formatMoney(todaySales.netRevenue - todaySales.costOfGoods, symbol: currency),
                        color: Colors.green,
                        onTap: () => context.go('/reports'),
                      ),
                    ),
                  ],
                ),
              ],

              // Low Stock and Expiring Alerts
              if (lowStock.isNotEmpty || expiring.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (lowStock.isNotEmpty)
                      Expanded(child: _LowStockCard(products: lowStock)),
                    if (lowStock.isNotEmpty && expiring.isNotEmpty)
                      const SizedBox(width: 16),
                    if (expiring.isNotEmpty)
                      Expanded(child: _ExpiringCard(products: expiring)),
                  ],
                ),
              ],

              // Staff Restock Feedback / Reorder Recommendations (Branch Admin)
              if (staffFeedbacks.isNotEmpty) ...[
                const SizedBox(height: 24),
                _StaffFeedbackCard(feedbacks: staffFeedbacks),
              ],
              const SizedBox(height: 24),

              // Recent Sales & Quick Actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: _RecentSalesCard(
                      sales: recentSales,
                      currency: currency,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        if (isAnyAdmin) ...[
                          _StockValuationCard(
                            valuation: stockValuation,
                            currency: currency,
                          ),
                          const SizedBox(height: 16),
                        ],
                        _QuickActionsCard(
                          isSuperAdmin: user?.isSuperAdmin == true,
                          isBranchAdmin: user?.isBranchAdmin == true,
                          isStaff: user?.isStaff == true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminMiniStatCard extends StatelessWidget {
  const _AdminMiniStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.highlight = false,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlight;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = color ?? theme.colorScheme.primary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: highlight
              ? cardColor
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, size: 24, color: cardColor),
                  const Spacer(),
                  if (highlight)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: cardColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.products});

  final List<AppProduct> products;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.lowStockItems,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => PurchaseFormDialog(
                        initialProducts: products,
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart, size: 16, color: Colors.deepOrange),
                  label: Text(l10n.requestNewStock),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () => context.go('/products'),
                  child: Text(l10n.viewAll),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.take(4).length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final product = products[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(product.name),
                  subtitle: Text(product.sku),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          l10n.itemsLeft(product.stockQuantity),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.add_shopping_cart, size: 18, color: Colors.deepOrange),
                        tooltip: l10n.requestNewStock,
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => PurchaseFormDialog(
                              initialProducts: [product],
                              initialSupplierId: product.supplierId,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiringCard extends StatelessWidget {
  const _ExpiringCard({required this.products});

  final List<AppProduct> products;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.event_busy_outlined,
                    color: Colors.deepOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.expiringSoon,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/expiry'),
                  child: Text(l10n.viewAll),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.take(4).length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final product = products[index];
                final expiry = product.expiryDate;
                final dateStr = expiry == null
                    ? ''
                    : '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(product.name),
                  subtitle: Text(product.sku),
                  trailing: Text(
                    dateStr,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSalesCard extends StatelessWidget {
  const _RecentSalesCard({required this.sales, required this.currency});

  final List<AppSale> sales;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.salesHistory,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/sales'),
                  child: Text(l10n.viewAll),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sales.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    l10n.noRecentSales,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sales.take(5).length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final sale = sales[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      sale.invoiceNumber,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${DateFormat.Hm().format(sale.createdAt)} • ${sale.customerName ?? l10n.walkInCustomer} • ${sale.paymentMethod?.toUpperCase() ?? "CASH"}',
                    ),
                    trailing: Text(
                      formatMoney(sale.totalAmount, symbol: currency),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StockValuationCard extends StatelessWidget {
  const _StockValuationCard({
    required this.valuation,
    required this.currency,
  });

  final StockValuation? valuation;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cost = valuation?.costValue ?? 0;
    final retail = valuation?.retailValue ?? 0;
    final profit = retail - cost;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assessment_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.inventoryValuation,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildValuationRow(
              context,
              icon: Icons.inventory_2_outlined,
              label: l10n.totalCostValue,
              value: formatMoney(cost, symbol: currency),
            ),
            const SizedBox(height: 8),
            _buildValuationRow(
              context,
              icon: Icons.storefront_outlined,
              label: l10n.totalRetailValue,
              value: formatMoney(retail, symbol: currency),
            ),
            const Divider(height: 16),
            _buildValuationRow(
              context,
              icon: Icons.trending_up_outlined,
              label: l10n.potentialProfit,
              value: formatMoney(profit, symbol: currency),
              highlight: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValuationRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: highlight
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.isSuperAdmin,
    required this.isBranchAdmin,
    required this.isStaff,
  });

  final bool isSuperAdmin;
  final bool isBranchAdmin;
  final bool isStaff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.flash_on_outlined,
                    color: theme.colorScheme.tertiary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.quickActions,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ActionButton(
                  icon: Icons.point_of_sale,
                  label: l10n.pos,
                  color: theme.colorScheme.primary,
                  onTap: () => context.go('/pos'),
                ),
                _ActionButton(
                  icon: Icons.people_outline,
                  label: l10n.customers,
                  color: theme.colorScheme.secondary,
                  onTap: () => context.go('/customers'),
                ),
                if (isStaff) ...[
                  _ActionButton(
                    icon: Icons.rate_review_outlined,
                    label: l10n.sendRestockFeedback,
                    color: const Color(0xFF0EA5E9),
                    onTap: () => StaffFeedbackDialog.show(context),
                  ),
                  _ActionButton(
                    icon: Icons.inventory_2_outlined,
                    label: l10n.products,
                    color: Colors.teal,
                    onTap: () => context.go('/products'),
                  ),
                ],
                if (!isStaff) ...[
                  _ActionButton(
                    icon: Icons.inventory_2_outlined,
                    label: l10n.purchases,
                    color: Colors.teal,
                    onTap: () => context.go('/purchases'),
                  ),
                  _ActionButton(
                    icon: Icons.insert_chart_outlined,
                    label: l10n.reports,
                    color: Colors.indigo,
                    onTap: () => context.go('/reports'),
                  ),
                ],
                if (isSuperAdmin) ...[
                  _ActionButton(
                    icon: Icons.backup_outlined,
                    label: l10n.backups,
                    color: Colors.deepPurple,
                    onTap: () => context.go('/backup'),
                  ),
                  _ActionButton(
                    icon: Icons.settings_outlined,
                    label: l10n.hqSettings,
                    color: Colors.blueGrey,
                    onTap: () => context.go('/settings'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffFeedbackCard extends ConsumerWidget {
  const _StaffFeedbackCard({required this.feedbacks});

  final List<StaffProductFeedback> feedbacks;

  Future<void> _createPurchaseOrder(
    BuildContext context,
    WidgetRef ref,
    StaffProductFeedback feedback,
  ) async {
    final l10n = AppLocalizations.of(context);
    final allProducts = ref.read(productListProvider).valueOrNull ?? [];
    AppProduct? targetProduct;
    if (feedback.productId != null) {
      targetProduct =
          allProducts.where((p) => p.id == feedback.productId).firstOrNull;
    }
    targetProduct ??= allProducts
        .where((p) =>
            p.name.toLowerCase() == feedback.productName.toLowerCase())
        .firstOrNull;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => PurchaseFormDialog(
        initialProducts: targetProduct != null ? [targetProduct] : null,
        initialSupplierId: targetProduct?.supplierId ?? feedback.supplierId,
      ),
    );

    if (saved == true) {
      await ref
          .read(staffFeedbackRepositoryProvider)
          .updateStatus(feedback.id, 'ordered');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.purchaseApproval),
            backgroundColor: Colors.teal.shade800,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.rate_review_rounded,
                    color: Color(0xFF0EA5E9),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.branchRestockRequests,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        l10n.cashierFeedbackSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${feedbacks.length}',
                    style: const TextStyle(
                      color: Color(0xFF0EA5E9),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: feedbacks.take(5).length,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final f = feedbacks[index];
                final isUrgent = f.isUrgent;
                final isHighDemand = f.isHighDemand;

                final badgeColor = isUrgent
                    ? const Color(0xFFEF4444)
                    : (isHighDemand
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF0EA5E9));

                final badgeText = isUrgent
                    ? l10n.urgencyLowStock
                    : (isHighDemand
                        ? l10n.urgencyHighDemand
                        : l10n.urgencyNormal);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isUrgent
                            ? Icons.error_outline_rounded
                            : (isHighDemand
                                ? Icons.trending_up_rounded
                                : Icons.inventory_2_outlined),
                        color: badgeColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                f.productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Stock: ${f.currentStock}  •  ${l10n.suggestedQty}: ${f.suggestedQuantity}  •  ${l10n.reportedBy(f.staffUsername)}'
                            '${f.notes != null && f.notes!.isNotEmpty ? " • \"${f.notes}\"" : ""}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: () => _createPurchaseOrder(context, ref, f),
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: Text(l10n.createPurchaseOrderForDrug),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: l10n.dismissFeedback,
                      onPressed: () => ref
                          .read(staffFeedbackRepositoryProvider)
                          .updateStatus(f.id, 'dismissed'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

