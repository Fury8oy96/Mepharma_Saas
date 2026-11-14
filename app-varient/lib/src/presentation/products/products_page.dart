import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:barcode_widget/barcode_widget.dart';

import '../../app/providers.dart';
import '../../core/services/api_client.dart';
import '../../core/services/product_csv_service.dart';
import '../../core/utils/barcode_symbologies.dart';
import '../../core/utils/money.dart';
import '../../core/utils/pricing_engine.dart';
import '../../domain/models/app_category.dart';
import '../../domain/models/app_product.dart';
import '../../domain/models/app_supplier.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/supplier_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../purchases/purchase_form_dialog.dart';
import '../session/session_controller.dart';
import 'product_form_dialog.dart';
import 'staff_feedback_dialog.dart';
import 'stock_adjustment_dialog.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _searchController = TextEditingController();
  final _tableHorizontalScrollController = ScrollController();
  bool _filterLowStockOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    _tableHorizontalScrollController.dispose();
    super.dispose();
  }

  void _scrollTableRight() {
    if (!_tableHorizontalScrollController.hasClients) return;
    final isRtl = Localizations.localeOf(context).languageCode == 'ar';
    final delta = isRtl ? -320.0 : 320.0;
    _tableHorizontalScrollController.animateTo(
      (_tableHorizontalScrollController.offset + delta).clamp(
        0.0,
        _tableHorizontalScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollTableLeft() {
    if (!_tableHorizontalScrollController.hasClients) return;
    final isRtl = Localizations.localeOf(context).languageCode == 'ar';
    final delta = isRtl ? 320.0 : -320.0;
    _tableHorizontalScrollController.animateTo(
      (_tableHorizontalScrollController.offset + delta).clamp(
        0.0,
        _tableHorizontalScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _simulateBarcodePrint(AppProduct product) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final barcodeData = (product.barcode != null && product.barcode!.trim().isNotEmpty)
        ? product.barcode!.trim()
        : product.sku.trim();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.print_outlined, color: Theme.of(context).colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'محاكاة طباعة ملصق الباركود' : 'Simulate Barcode Label Print',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      isArabic ? 'خاص بإدارة النظام فقط (Admin Tools)' : 'Admin System Diagnostic Tool',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade400, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'ج.س ${product.sellingPrice}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      BarcodeWidget(
                        barcode: SmartBarcodeEngine.resolveRenderer(barcodeData),
                        data: barcodeData,
                        width: 260,
                        height: 60,
                        style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SKU: ${product.sku}',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 10),
                          ),
                          Text(
                            product.expiryDate != null
                                ? 'EXP: ${product.expiryDate.toString().split(' ').first}'
                                : 'EXP: -',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isArabic
                      ? 'يمكنك محاكاة إرسال أمر طباعة ملصق الباركود لطابعة الملصقات الحرارية والتأكد من جاهزيته.'
                      : 'Simulate sending barcode label print job to thermal sticker printer.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.print_outlined, color: Colors.greenAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isArabic
                                  ? 'تمت محاكاة إرسال ملصق باركود (${product.name}) لطابعة الملصقات بنجاح!'
                                  : 'Simulated printing barcode label for ${product.name} successfully!',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF1E293B),
                    ),
                  );
              },
              icon: const Icon(Icons.print_outlined, size: 18),
              label: Text(isArabic ? 'محاكاة طباعة الملصق' : 'Simulate Label Print'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openForm({AppProduct? product}) async {
    final l10n = AppLocalizations.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => ProductFormDialog(
        product: product,
        categories: ref.read(categoryListProvider).valueOrNull ?? const [],
        suppliers: ref.read(supplierListProvider).valueOrNull ?? const [],
      ),
    );
    if (saved == true && mounted) {
      ref.read(productRepositoryProvider).refresh();
      ref.invalidate(productListProvider);
      ref.invalidate(lowStockProductsProvider);
      ref.invalidate(expiringProductsProvider);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(product == null ? l10n.productAdded : l10n.productSaved)),
        );
    }
  }

  Future<void> _openAdjustStock(AppProduct product) async {
    final l10n = AppLocalizations.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StockAdjustmentDialog(product: product),
    );
    if (saved == true && mounted) {
      ref.read(productRepositoryProvider).refresh();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.stockAdjusted),
            backgroundColor: Colors.teal.shade800,
          ),
        );
    }
  }

  Future<void> _openRestockPurchase({List<AppProduct>? products, int? supplierId}) async {
    final l10n = AppLocalizations.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => PurchaseFormDialog(
        initialProducts: products,
        initialSupplierId: supplierId,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.purchaseApproval),
            backgroundColor: Colors.teal.shade800,
          ),
        );
    }
  }

  Future<void> _confirmDelete(AppProduct product) async {
    final l10n = AppLocalizations.of(context);
    final isSuperAdmin = ref.read(sessionProvider)?.isSuperAdmin ?? false;
    if (!isSuperAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.managedBySuperAdmin),
              backgroundColor: Colors.orange.shade800,
            ),
          );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDeleteProduct(product.name)),
        content: Text(l10n.confirmDeleteProductMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await ref.read(productRepositoryProvider).delete(product.id);
        ref.read(productRepositoryProvider).refresh();
        ref.invalidate(productListProvider);
        ref.invalidate(lowStockProductsProvider);
        ref.invalidate(expiringProductsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(l10n.productDeleted)));
        }
      } catch (e) {
        if (mounted) {
          final msg = (e is ApiException && e.message.isNotEmpty)
              ? e.message
              : l10n.errorOccurred;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: Colors.red.shade800,
              ),
            );
        }
      }
    }
  }



  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final products = ref.read(productRepositoryProvider);
    final categories = await ref.read(categoryRepositoryProvider).getAll();
    final suppliers = await ref.read(supplierRepositoryProvider).getAll();
    final categoryNames = {for (final c in categories) c.id: c.name};
    final supplierNames = {for (final s in suppliers) s.id: s.name};

    final all = await products.getAll();
    final rows = [
      for (final p in all)
        ProductCsvRow(
          sku: p.sku,
          name: p.name,
          barcode: p.barcode,
          categoryName: categoryNames[p.categoryId] ?? '',
          supplierName: supplierNames[p.supplierId] ?? '',
          costPrice: p.costPrice,
          sellingPrice: p.sellingPrice,
          stockQuantity: p.stockQuantity,
          lowStockThreshold: p.lowStockThreshold,
          expiryDate: p.expiryDate,
          description: p.description,
        ),
    ];
    final path = await exportProductsCsv(rows);
    if (path != null && mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.exportComplete(path))));
    }
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    final result = await importProductsCsv();
    if (result == null) {
      return;
    }
    if (result.rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(l10n.noProductsImported)));
      }
      return;
    }

    final productRepo = ref.read(productRepositoryProvider);
    final categoryRepo = ref.read(categoryRepositoryProvider);
    final supplierRepo = ref.read(supplierRepositoryProvider);
    var created = 0;
    var updated = 0;
    var skipped = 0;

    final marginStr = ref.read(storeSettingsProvider).valueOrNull?.profitMargin ?? '0.3';
    final margin = double.tryParse(marginStr) ?? 0.3;

    for (final row in result.rows) {
      try {
        final existing = await productRepo.findBySku(row.sku);
        final category = await _resolveCategory(categoryRepo, row.categoryName);
        final supplier = await _resolveSupplier(supplierRepo, row.supplierName);
        final effectiveSellingPrice = (row.sellingPrice > row.costPrice)
            ? row.sellingPrice
            : PricingEngine.calculateSellingPrice(row.costPrice, margin);

        if (existing == null) {
          await productRepo.create(
            sku: row.sku,
            name: row.name,
            barcode: row.barcode,
            categoryId: category?.id,
            supplierId: supplier?.id,
            costPrice: row.costPrice,
            sellingPrice: effectiveSellingPrice,
            stockQuantity: row.stockQuantity,
            lowStockThreshold: row.lowStockThreshold,
            expiryDate: row.expiryDate,
            description: row.description,
          );
          created++;
        } else {
          await productRepo.update(
            existing.id,
            name: row.name,
            barcode: row.barcode,
            categoryId: category?.id,
            supplierId: supplier?.id,
            costPrice: row.costPrice,
            sellingPrice: effectiveSellingPrice,
            lowStockThreshold: row.lowStockThreshold,
            expiryDate: row.expiryDate,
            description: row.description,
          );
          updated++;
        }
      } catch (_) {
        skipped++;
      }
    }

    if (mounted) {
      final errors = result.errors.length + skipped;
      final message = l10n.importComplete(created, updated, errors);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<AppCategory?> _resolveCategory(
    CategoryRepository repo,
    String name,
  ) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final all = await repo.getAll();
    final lower = trimmed.toLowerCase();
    for (final c in all) {
      if (c.name.toLowerCase() == lower) {
        return c;
      }
    }
    return repo.create(name: trimmed);
  }

  Future<AppSupplier?> _resolveSupplier(
    SupplierRepository repo,
    String name,
  ) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final all = await repo.getAll();
    final lower = trimmed.toLowerCase();
    for (final s in all) {
      if (s.name.toLowerCase() == lower) {
        return s;
      }
    }
    return repo.create(name: trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final productsAsync = ref.watch(productListProvider);
    final categories = ref.watch(categoryListProvider).valueOrNull ?? const [];
    final suppliers = ref.watch(supplierListProvider).valueOrNull ?? const [];
    final currency = ref.watch(currencySymbolProvider).valueOrNull ?? 'ج.س';
    final currentUser = ref.watch(sessionProvider);
    final isStaff = currentUser?.isStaff ?? false;
    final isSuperAdmin = currentUser?.isSuperAdmin ?? false;

    final categoryNames = {for (final c in categories) c.id: c.name};
    final supplierNames = {for (final s in suppliers) s.id: s.name};

    final query = _searchController.text.trim().toLowerCase();
    final allProducts = productsAsync.valueOrNull ?? const <AppProduct>[];
    final lowStockProducts = allProducts.where((p) => p.isLowStock).toList();

    final filtered = allProducts.where((p) {
      if (_filterLowStockOnly && !p.isLowStock) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return p.name.toLowerCase().contains(query) ||
          p.sku.toLowerCase().contains(query) ||
          (p.barcode?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: l10n.searchProducts,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: Text('${l10n.allProductsFilter} (${allProducts.length})'),
                  selected: !_filterLowStockOnly,
                  onSelected: (selected) {
                    if (selected) setState(() => _filterLowStockOnly = false);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: lowStockProducts.isNotEmpty
                      ? Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade900)
                      : null,
                  label: Text('${l10n.lowStockFilter} (${lowStockProducts.length})'),
                  selected: _filterLowStockOnly,
                  selectedColor: Colors.amber.shade100,
                  onSelected: (selected) {
                    setState(() => _filterLowStockOnly = selected);
                  },
                ),
                const SizedBox(width: 12),
                if (!isStaff && lowStockProducts.isNotEmpty) ...[
                  FilledButton.tonalIcon(
                    onPressed: () => _openRestockPurchase(products: lowStockProducts),
                    icon: const Icon(Icons.add_shopping_cart, color: Colors.deepOrange),
                    label: Text(l10n.restockAllLowStock),
                  ),
                  const SizedBox(width: 8),
                ],
                if (!isStaff) ...[
                  OutlinedButton.icon(
                    onPressed: _import,
                    icon: const Icon(Icons.file_download_outlined),
                    label: Text(l10n.import),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _export,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: Text(l10n.export),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.refresh,
                  onPressed: () {
                    ref.read(productRepositoryProvider).refresh();
                  },
                ),
                const SizedBox(width: 8),
                if (isStaff)
                  FilledButton.icon(
                    onPressed: () => StaffFeedbackDialog.show(context),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: Text(l10n.sendRestockFeedback),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addProduct),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: productsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(child: Text(l10n.errorOccurred)),
                  data: (_) => filtered.isEmpty
                      ? Center(
                          child: Text(
                            l10n.noProducts,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Top Navigation & Action Bar for Horizontal Scroll
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                border: Border(
                                  bottom: BorderSide(
                                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.swap_horiz_rounded, size: 20, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.localeName.startsWith('ar')
                                        ? 'شريط التنقل والتمرير الأفقي بين أعمدة الجدول'
                                        : 'Table Horizontal Navigation Bar',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      l10n.localeName.startsWith('ar')
                                          ? 'إجمالي: ${filtered.length} منتج'
                                          : 'Total: ${filtered.length} items',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton.tonalIcon(
                                    onPressed: _scrollTableRight,
                                    icon: const Icon(Icons.arrow_forward, size: 16),
                                    label: Text(l10n.localeName.startsWith('ar') ? 'سحب يمين' : 'Scroll Right'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.tonalIcon(
                                    onPressed: _scrollTableLeft,
                                    icon: const Icon(Icons.arrow_back, size: 16),
                                    label: Text(l10n.localeName.startsWith('ar') ? 'سحب يسار' : 'Scroll Left'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Expanded Table with Visible Scrollbar
                            Expanded(
                              child: Scrollbar(
                                controller: _tableHorizontalScrollController,
                                thumbVisibility: true,
                                trackVisibility: true,
                                interactive: true,
                                thickness: 9.0,
                                radius: const Radius.circular(5),
                                child: SingleChildScrollView(
                                  controller: _tableHorizontalScrollController,
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    physics: const BouncingScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(minWidth: 1300),
                                      child: DataTable(
                                        columnSpacing: 26,
                                        horizontalMargin: 16,
                                        columns: [
                                          DataColumn(label: Text(l10n.productName)),
                                          DataColumn(label: Text(l10n.sku)),
                                          DataColumn(label: Text(l10n.barcode)),
                                          DataColumn(label: Text(l10n.category)),
                                          DataColumn(label: Text(l10n.supplier)),
                                          DataColumn(label: Text(l10n.costPrice)),
                                          DataColumn(label: Text(l10n.sellingPrice)),
                                          DataColumn(label: Text(l10n.stock)),
                                          DataColumn(label: Text(l10n.expiryDate)),
                                          DataColumn(label: Text(l10n.actions)),
                                        ],
                                        rows: [
                                for (final p in filtered)
                                  DataRow(
                                    color: p.isLowStock
                                        ? WidgetStateProperty.all(
                                            Colors.amber.withValues(alpha: 0.08),
                                          )
                                        : null,
                                    cells: [
                                      DataCell(
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              p.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (p.description != null &&
                                                p.description!.isNotEmpty)
                                              Text(
                                                p.description!,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(p.sku)),
                                      DataCell(Text(p.barcode ?? '-')),
                                      DataCell(
                                        Text(
                                          categoryNames[p.categoryId] ??
                                              l10n.noCategory,
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          supplierNames[p.supplierId] ??
                                              l10n.noSupplier,
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          formatMoney(p.costPrice, symbol: currency),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          formatMoney(
                                            p.sellingPrice,
                                            symbol: currency,
                                          ),
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataCell(_StockCell(product: p)),
                                      DataCell(
                                        _ExpiryCell(
                                          expiryDate: p.expiryDate,
                                          expired: p.isExpired,
                                          daysLeft: p.daysUntilExpiry,
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isStaff) ...[
                                              IconButton(
                                                tooltip: l10n.sendRestockFeedback,
                                                icon: Icon(
                                                  p.isLowStock
                                                      ? Icons.feedback_outlined
                                                      : Icons.rate_review_outlined,
                                                  color: p.isLowStock
                                                      ? Colors.deepOrange
                                                      : const Color(0xFF0EA5E9),
                                                ),
                                                onPressed: () => StaffFeedbackDialog.show(
                                                  context,
                                                  product: p,
                                                ),
                                              ),
                                            ] else ...[
                                              if (p.isLowStock)
                                                IconButton(
                                                  tooltip: l10n.requestNewStock,
                                                  icon: const Icon(
                                                    Icons.add_shopping_cart,
                                                    color: Colors.deepOrange,
                                                  ),
                                                  onPressed: () => _openRestockPurchase(
                                                    products: [p],
                                                    supplierId: p.supplierId,
                                                  ),
                                                ),
                                              IconButton(
                                                tooltip: l10n.localeName.startsWith('ar')
                                                    ? 'محاكاة طباعة ملصق الباركود'
                                                    : 'Simulate Barcode Label Print',
                                                icon: const Icon(Icons.print_outlined),
                                                onPressed: () => _simulateBarcodePrint(p),
                                              ),
                                              IconButton(
                                                tooltip: l10n.edit,
                                                icon: const Icon(Icons.edit_outlined),
                                                onPressed: () => _openForm(product: p),
                                              ),
                                              IconButton(
                                                tooltip: l10n.adjustStock,
                                                icon: const Icon(Icons.exposure),
                                                onPressed: () => _openAdjustStock(p),
                                              ),
                                              if (isSuperAdmin)
                                                IconButton(
                                                  tooltip: l10n.delete,
                                                  icon: const Icon(Icons.delete_outline),
                                                  onPressed: () => _confirmDelete(p),
                                                ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Bottom bar with instructions and arrows
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      border: Border(
                        top: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.touch_app_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          l10n.localeName.startsWith('ar')
                              ? 'استخدم شريط التمرير أو أزرار الأسهم للتنقل بين كافة تفاصيل وأعمدة الجدول'
                              : 'Use scrollbar or arrow buttons to navigate table columns smoothly',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        IconButton.filledTonal(
                          onPressed: _scrollTableRight,
                          icon: const Icon(Icons.arrow_forward_ios, size: 13),
                          tooltip: l10n.localeName.startsWith('ar') ? 'سحب لليمين' : 'Scroll Right',
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          onPressed: _scrollTableLeft,
                          icon: const Icon(Icons.arrow_back_ios_new, size: 13),
                          tooltip: l10n.localeName.startsWith('ar') ? 'سحب لليسار' : 'Scroll Left',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockCell extends StatelessWidget {
  const _StockCell({required this.product});

  final AppProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final low = product.isLowStock;
    final zero = product.stockQuantity == 0;

    final color = zero
        ? theme.colorScheme.error
        : (low ? Colors.orange.shade800 : theme.colorScheme.onSurface);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (low) ...[
          Icon(
            zero ? Icons.error_outline : Icons.warning_amber_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          '${product.stockQuantity}',
          style: TextStyle(
            color: color,
            fontWeight: low ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (low) ...[
          const SizedBox(width: 4),
          Text(
            '(${l10n.lowStockThreshold}: ${product.lowStockThreshold})',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

class _ExpiryCell extends StatelessWidget {
  const _ExpiryCell({
    required this.expiryDate,
    required this.expired,
    required this.daysLeft,
  });

  final DateTime? expiryDate;
  final bool expired;
  final int? daysLeft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final date = expiryDate;
    if (date == null) {
      return const Text('-');
    }

    final formatted =
        DateFormat.yMd(AppLocalizations.of(context).localeName).format(date);

    if (expired) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
          const SizedBox(width: 4),
          Text(
            '$formatted (${l10n.expired})',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    final days = daysLeft;
    if (days != null && days <= 30) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Colors.orange.shade800,
          ),
          const SizedBox(width: 4),
          Text(
            '$formatted (${l10n.itemsLeft(days)})',
            style: TextStyle(
              color: Colors.orange.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return Text(formatted);
  }
}
