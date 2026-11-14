import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/utils/money.dart';
import '../../domain/models/app_product.dart';
import '../../domain/models/app_purchase.dart';
import '../../domain/models/app_supplier.dart';
import '../../domain/models/staff_product_feedback.dart';
import '../../l10n/generated/app_localizations.dart';
import '../products/staff_feedback_dialog.dart';
import '../session/session_controller.dart';
import 'purchase_detail_dialog.dart';
import 'purchase_form_dialog.dart';

class PurchasesPage extends ConsumerWidget {
  const PurchasesPage({super.key});

  Future<void> _openForm(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => const PurchaseFormDialog(),
    );
    if (saved == true) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.purchaseSaved)));
    }
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<AppPurchase> purchases,
    Map<int, String> supplierName,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    if (purchases.isEmpty) {
      return Center(
        child: Text(
          l10n.noPurchases,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: purchases.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final purchase = purchases[index];
        final isPending = purchase.status == PurchaseStatus.pending;
        return ListTile(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => PurchaseDetailDialog(
              purchaseId: purchase.id,
            ),
          ),
          leading: CircleAvatar(
            backgroundColor: isPending ? Colors.amber.shade100 : theme.colorScheme.primaryContainer,
            child: Icon(
              isPending ? Icons.pending_actions : Icons.inventory_2_outlined,
              color: isPending ? Colors.amber.shade900 : theme.colorScheme.onPrimaryContainer,
            ),
          ),
          title: Row(
            children: [
              Text(
                purchase.invoiceNumber,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isPending ? Colors.amber.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isPending ? Colors.amber.shade400 : Colors.green.shade400,
                  ),
                ),
                child: Text(
                  isPending ? l10n.pendingApproval : l10n.approved,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPending ? Colors.amber.shade900 : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text(
            [
              supplierName[purchase.supplierId] ?? l10n.noSupplier,
              DateFormat.yMd(l10n.localeName).format(purchase.purchaseDate),
            ].join(' · '),
          ),
          trailing: Text(
            formatMoney(
              purchase.totalAmount,
              symbol: ref.watch(currencySymbolProvider).valueOrNull ?? r'$',
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaffFeedbacksList(
    BuildContext context,
    WidgetRef ref,
    List<StaffProductFeedback> feedbacks,
    ThemeData theme,
    AppLocalizations l10n,
    bool isArabic,
  ) {
    if (feedbacks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_outlined,
                  size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                isArabic
                    ? 'لا توجد طلبات تزويد أصناف معلقة من الموظفين حالياً'
                    : 'No pending staff restock extension requests.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: feedbacks.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final fb = feedbacks[index];
        final isUrgent = fb.isUrgent;
        final isHighDemand = fb.isHighDemand;

        Color badgeColor = Colors.blue;
        String reasonLabel = isArabic ? 'تزويد اعتيادي' : 'Normal Restock';
        IconData reasonIcon = Icons.info_outline;

        if (isUrgent) {
          badgeColor = Colors.red;
          reasonLabel =
              isArabic ? 'نفاد مخزون / عاجل' : 'Urgent (Out of Stock)';
          reasonIcon = Icons.warning_amber_rounded;
        } else if (isHighDemand) {
          badgeColor = Colors.orange;
          reasonLabel =
              isArabic ? 'طلب متزايد / مبيعات سريعة' : 'High Demand (Sells Fast)';
          reasonIcon = Icons.local_fire_department_outlined;
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: badgeColor.withValues(alpha: 0.15),
            child: Icon(reasonIcon, color: badgeColor, size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  fb.productName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  reasonLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${isArabic ? "الكمية المقترحة" : "Suggested Qty"}: ${fb.suggestedQuantity} · ${isArabic ? "بواسطة" : "By"}: ${fb.staffUsername} · ${DateFormat.yMd(l10n.localeName).format(fb.createdAt)}',
                style: theme.textTheme.bodySmall,
              ),
              if (fb.notes != null && fb.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '${isArabic ? "ملاحظة" : "Note"}: ${fb.notes}',
                  style: TextStyle(
                      fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
          trailing: FilledButton.tonalIcon(
            onPressed: () async {
              AppProduct? prod;
              if (fb.productId != null) {
                prod = await ref
                    .read(productRepositoryProvider)
                    .findById(fb.productId!);
              }
              if (!context.mounted) return;
              final saved = await showDialog<bool>(
                context: context,
                builder: (context) => PurchaseFormDialog(
                  initialProducts: prod != null ? [prod] : null,
                  initialSupplierId: fb.supplierId,
                ),
              );
              if (saved == true) {
                await ref
                    .read(staffFeedbackRepositoryProvider)
                    .updateStatus(fb.id, 'ordered');
                ref.invalidate(branchStaffFeedbacksProvider);
                ref.invalidate(purchaseListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic
                              ? 'تم إنشاء أمر الشراء وتحديث حالة طلب التزويد بنجاح'
                              : 'Purchase order created and request updated!',
                        ),
                        backgroundColor: const Color(0xFF28C76F),
                      ),
                    );
                }
              }
            },
            icon: const Icon(Icons.add_shopping_cart, size: 16),
            label: Text(isArabic ? 'إنشاء أمر شراء' : 'Create PO'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final purchasesAsync = ref.watch(purchaseListProvider);
    final suppliersAsync = ref.watch(supplierListProvider);
    final suppliers = suppliersAsync.valueOrNull ?? const <AppSupplier>[];
    final supplierName = {for (final s in suppliers) s.id: s.name};

    final user = ref.watch(sessionProvider);
    final isAdmin = user?.isAdmin == true || user?.isBranchAdmin == true;
    final isArabic = l10n.localeName.startsWith('ar');
    final staffFeedbacks = isAdmin
        ? (ref.watch(branchStaffFeedbacksProvider(user?.branchId)).valueOrNull ??
            const <StaffProductFeedback>[])
        : const <StaffProductFeedback>[];

    final tabCount = isAdmin ? 3 : 2;

    return DefaultTabController(
      key: ValueKey('purchases_tabs_$tabCount'),
      length: tabCount,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: theme.colorScheme.primary,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          text: l10n.approved,
                        ),
                        Tab(
                          icon: const Icon(Icons.pending_actions, size: 18),
                          text: l10n.pendingApproval,
                        ),
                        if (isAdmin)
                          Tab(
                            icon: Badge(
                              isLabelVisible: staffFeedbacks.isNotEmpty,
                              label: Text(staffFeedbacks.length.toString()),
                              child: const Icon(Icons.extension_outlined,
                                  size: 18),
                            ),
                            text: isArabic
                                ? 'طلبات التزويد (الموظفين)'
                                : 'Staff Extension Requests',
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: () {
                      ref.read(purchaseRepositoryProvider).refresh();
                      if (isAdmin) {
                        ref.read(staffFeedbackRepositoryProvider).refresh();
                        ref.invalidate(branchStaffFeedbacksProvider);
                      }
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Refreshing stock purchases list...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                    },
                  ),
                  const SizedBox(width: 8),
                  if (isAdmin)
                    FilledButton.icon(
                      onPressed: () => _openForm(context),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.newPurchase),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () async {
                        final sent = await StaffFeedbackDialog.show(context);
                        if (sent == true && context.mounted) {
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  isArabic
                                      ? 'تم إرسال طلب تزويد الصنف للإدارة للمراجعة والطلب بنجاح'
                                      : 'Restock extension request submitted for admin review.',
                                ),
                                backgroundColor: const Color(0xFF28C76F),
                              ),
                            );
                        }
                      },
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: Text(
                        isArabic
                            ? 'طلب تزويد صنف (نواقص)'
                            : 'Request Item Extension',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  child: purchasesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Center(child: Text(l10n.errorOccurred)),
                    data: (purchases) {
                      final approved = purchases
                          .where((p) => p.status == PurchaseStatus.approved)
                          .toList();
                      final pending = purchases
                          .where((p) => p.status == PurchaseStatus.pending)
                          .toList();

                      return TabBarView(
                        children: [
                          _buildList(context, ref, approved, supplierName,
                              theme, l10n),
                          _buildList(context, ref, pending, supplierName,
                              theme, l10n),
                          if (isAdmin)
                            _buildStaffFeedbacksList(context, ref,
                                staffFeedbacks, theme, l10n, isArabic),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
