import 'dart:convert';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/services/thermal_printer_service.dart';
import '../../core/utils/barcode_symbologies.dart';
import '../../core/utils/money.dart';
import '../../data/db/enums.dart';
import '../../domain/models/app_product.dart';
import '../../domain/models/app_sales_hold.dart';
import '../../domain/models/cart_item.dart';
import '../../domain/models/customer.dart';
import '../../domain/models/payment_method.dart';
import '../../domain/models/receipt_data.dart';
import '../../domain/models/sale_receipt.dart';
import '../../l10n/generated/app_localizations.dart';
import '../products/staff_feedback_dialog.dart';
import '../session/session_controller.dart';
import 'holds_dialog.dart';
import 'payment_dialog.dart';
import 'pos_controller.dart';

class PosPage extends ConsumerStatefulWidget {
  const PosPage({super.key});

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  final _barcodeController = TextEditingController();
  late final FocusNode _barcodeFocus;
  final _searchController = TextEditingController();
  final _discountController = TextEditingController();

  final _searchBarKey = GlobalKey();
  final _layerLink = LayerLink();
  final Object _searchTapGroupId = Object();
  OverlayEntry? _overlayEntry;
  List<AppProduct> _searchResults = [];
  int _highlightedIndex = -1;
  final _resultsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _barcodeFocus = FocusNode(onKeyEvent: _handleSearchKey);
    _barcodeFocus.addListener(_onBarcodeFocusChanged);
    _barcodeController.addListener(_onBarcodeChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    _barcodeFocus.removeListener(_onBarcodeFocusChanged);
    _barcodeFocus.dispose();
    _barcodeController.removeListener(_onBarcodeChanged);
    _barcodeController.dispose();
    _searchController.dispose();
    _discountController.dispose();
    _resultsScrollController.dispose();
    super.dispose();
  }

  void _onBarcodeChanged() {
    setState(() {});
    final query = _barcodeController.text.trim();
    if (query.isEmpty) {
      _removeOverlay();
      return;
    }
    _performSearch(query);
  }

  void _onBarcodeFocusChanged() {
    if (_barcodeFocus.hasFocus) {
      final query = _barcodeController.text.trim();
      if (query.isNotEmpty) {
        _performSearch(query);
      }
    }
  }

  KeyEventResult _handleSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_overlayEntry != null) {
        _removeOverlay();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_overlayEntry == null && _barcodeController.text.trim().isNotEmpty) {
        _performSearch(_barcodeController.text.trim());
        return KeyEventResult.handled;
      }
      if (_searchResults.isNotEmpty) {
        setState(() {
          _highlightedIndex = (_highlightedIndex + 1).clamp(0, _searchResults.length - 1);
        });
        _overlayEntry?.markNeedsBuild();
        _scrollToHighlighted();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_searchResults.isNotEmpty) {
        setState(() {
          _highlightedIndex = (_highlightedIndex - 1).clamp(-1, _searchResults.length - 1);
        });
        _overlayEntry?.markNeedsBuild();
        _scrollToHighlighted();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_highlightedIndex >= 0 && _highlightedIndex < _searchResults.length) {
        _selectProduct(_searchResults[_highlightedIndex]);
        return KeyEventResult.handled;
      } else if (_barcodeController.text.trim().isNotEmpty) {
        _handleSearchSubmitted(_barcodeController.text.trim());
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _scrollToHighlighted() {
    if (_highlightedIndex < 0 || !_resultsScrollController.hasClients) {
      return;
    }
    const itemHeight = 68.0;
    final targetOffset = _highlightedIndex * itemHeight;
    final currentOffset = _resultsScrollController.offset;
    final viewportHeight = _resultsScrollController.position.viewportDimension;

    if (targetOffset < currentOffset) {
      _resultsScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
      );
    } else if (targetOffset + itemHeight > currentOffset + viewportHeight) {
      _resultsScrollController.animateTo(
        targetOffset + itemHeight - viewportHeight,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
      );
    }
  }

  void _performSearch(String query) {
    final products = ref.read(productListProvider).valueOrNull ?? const <AppProduct>[];
    final q = query.toLowerCase();
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    final matched = <_ScoredProduct>[];

    for (final p in products) {
      final barcode = p.barcode?.toLowerCase() ?? '';
      final sku = p.sku.toLowerCase();
      final name = p.name.toLowerCase();
      final generic = p.description?.toLowerCase() ?? '';

      int score = 0;

      // 1. Exact matches (highest priority)
      if (barcode == q) {
        score += 1000;
      } else if (sku == q) {
        score += 900;
      }

      // 2. Starts with query
      if (name.startsWith(q)) {
        score += 800;
      } else if (sku.startsWith(q)) {
        score += 700;
      } else if (generic.isNotEmpty && generic.startsWith(q)) {
        score += 650;
      } else if (barcode.isNotEmpty && barcode.startsWith(q)) {
        score += 600;
      }

      // 3. Contains query
      if (name.contains(q)) {
        score += 500;
      }
      if (generic.isNotEmpty && generic.contains(q)) {
        score += 400;
      }
      if (sku.contains(q)) {
        score += 300;
      }
      if (barcode.isNotEmpty && barcode.contains(q)) {
        score += 200;
      }

      // 4. Multi-word search (if more than 1 word, all words must match somewhere)
      if (score == 0 && words.length > 1) {
        final combined = '$name $generic $sku $barcode';
        final allWordsMatch = words.every((word) => combined.contains(word));
        if (allWordsMatch) {
          score += 350;
        }
      }

      if (score > 0) {
        matched.add(_ScoredProduct(product: p, score: score));
      }
    }

    matched.sort((a, b) {
      final scoreComp = b.score.compareTo(a.score);
      if (scoreComp != 0) return scoreComp;
      return a.product.name.compareTo(b.product.name);
    });

    _searchResults = matched.map((m) => m.product).toList();
    _highlightedIndex = -1;

    _showOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
    _highlightedIndex = -1;
  }

  void _showOverlay() {
    if (!mounted) return;
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (overlayContext) {
        final renderBox = _searchBarKey.currentContext?.findRenderObject() as RenderBox?;
        final targetWidth = renderBox?.size.width ?? 520.0;
        final theme = Theme.of(context);
        final currency = ref.read(currencySymbolProvider).valueOrNull ?? 'ج.س';
        final l10n = AppLocalizations.of(context);
        final isArabic = l10n.localeName.startsWith('ar');

        return Align(
          alignment: Alignment.topLeft,
          child: TapRegion(
            groupId: _searchTapGroupId,
            onTapOutside: (_) => _removeOverlay(),
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 52),
              child: Material(
                elevation: 12,
                shadowColor: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surface,
                child: SizedBox(
                  width: targetWidth,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 380),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                          width: 1.5,
                        ),
                      ),
                      child: _searchResults.isEmpty
                          ? _buildEmptyResults(theme, l10n, isArabic)
                          : _buildResultsList(theme, l10n, currency, isArabic),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyResults(ThemeData theme, AppLocalizations l10n, bool isArabic) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 38,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.productNotFound,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isArabic
                ? 'لا توجد أدوية مطابقة للباركود، رمز الصنف، الاسم التجاري أو الاسم العلمي'
                : 'No medicines match barcode, SKU, brand name, or generic name',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(
    ThemeData theme,
    AppLocalizations l10n,
    String currency,
    bool isArabic,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isArabic
                      ? 'نتائج البحث (${_searchResults.length}) • اضغط Enter أو انقر للإضافة'
                      : 'Search Results (${_searchResults.length}) • Press Enter or click to add',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                isArabic ? '↑↓ للتنقل' : '↑↓ to navigate',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.separated(
            controller: _resultsScrollController,
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _searchResults.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
            ),
            itemBuilder: (context, index) {
              final product = _searchResults[index];
              final isHighlighted = index == _highlightedIndex;
              return _buildDroppedItem(
                product: product,
                isHighlighted: isHighlighted,
                theme: theme,
                l10n: l10n,
                currency: currency,
                isArabic: isArabic,
                onTap: () => _selectProduct(product),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDroppedItem({
    required AppProduct product,
    required bool isHighlighted,
    required ThemeData theme,
    required AppLocalizations l10n,
    required String currency,
    required bool isArabic,
    required VoidCallback onTap,
  }) {
    final disabled = product.stockQuantity <= 0 || product.isExpired;
    final low = !disabled && product.isLowStock;

    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (product.isExpired) {
      statusColor = theme.colorScheme.error;
      statusText = l10n.expired;
      statusIcon = Icons.event_busy_rounded;
    } else if (product.stockQuantity <= 0) {
      statusColor = theme.colorScheme.error;
      statusText = isArabic ? 'نفد المخزون' : 'Out of stock';
      statusIcon = Icons.remove_shopping_cart_outlined;
    } else if (low) {
      statusColor = Colors.amber.shade800;
      statusText = isArabic ? 'مخزون منخفض: ${product.stockQuantity}' : 'Low: ${product.stockQuantity}';
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = Colors.teal.shade700;
      statusText = isArabic ? '${product.stockQuantity} متوفر' : '${product.stockQuantity} in stock';
      statusIcon = Icons.inventory_2_outlined;
    }

    final hasGeneric = product.description != null && product.description!.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      hoverColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isHighlighted
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
              : Colors.transparent,
          border: isHighlighted
              ? Border(
                  left: BorderSide(
                    color: theme.colorScheme.primary,
                    width: isArabic ? 0 : 3.5,
                  ),
                  right: BorderSide(
                    color: theme.colorScheme.primary,
                    width: isArabic ? 3.5 : 0,
                  ),
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                disabled ? statusIcon : Icons.medication_outlined,
                size: 20,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  if (hasGeneric) ...[
                    const SizedBox(height: 1),
                    Text(
                      product.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SKU: ${product.sku}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (product.barcode != null && product.barcode!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.qr_code_2_rounded,
                                size: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                product.barcode!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatMoney(product.sellingPrice, symbol: currency),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: statusColor),
                      const SizedBox(width: 3),
                      Text(
                        statusText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.add_shopping_cart_rounded,
              size: 18,
              color: disabled
                  ? theme.colorScheme.outlineVariant
                  : theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _selectProduct(AppProduct product) {
    _removeOverlay();
    _barcodeController.clear();
    final l10n = AppLocalizations.of(context);

    if (product.isExpired) {
      _showMessage(l10n.productExpired);
    } else if (product.stockQuantity <= 0) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.outOfStock(product.name)),
            action: SnackBarAction(
              label: l10n.sendRestockFeedback,
              onPressed: () =>
                  StaffFeedbackDialog.show(context, product: product),
            ),
          ),
        );
    } else {
      ref.read(posControllerProvider.notifier).addProduct(product);
    }
    _focusBarcode();
  }

  Future<void> _handleSearchSubmitted(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;

    // 1. If an item is highlighted via keyboard, select it
    if (_highlightedIndex >= 0 && _highlightedIndex < _searchResults.length) {
      _selectProduct(_searchResults[_highlightedIndex]);
      return;
    }

    // 2. Check for exact barcode / SKU match across full catalog (hardware scanner support)
    final qLower = query.toLowerCase();
    final allProducts = ref.read(productListProvider).valueOrNull ?? const <AppProduct>[];
    final exactMatch = allProducts.where((p) =>
      (p.barcode != null && p.barcode!.toLowerCase() == qLower) ||
      p.sku.toLowerCase() == qLower
    ).firstOrNull;

    if (exactMatch != null) {
      _selectProduct(exactMatch);
      return;
    }

    // 3. If there are active search results, select the best ranked match
    if (_searchResults.isNotEmpty) {
      _selectProduct(_searchResults.first);
      return;
    }

    // 4. Fallback: repository lookup
    _removeOverlay();
    await _lookupAndAdd(query);
  }

  Future<void> _openBarcodeSimulationDialog() async {
    final products = ref.read(productListProvider).valueOrNull ?? const <AppProduct>[];
    final available = products.where((p) => p.stockQuantity > 0 && !p.isExpired).toList();
    final isArabic = AppLocalizations.of(context).localeName.startsWith('ar');

    AppProduct sampleProduct;
    if (available.isNotEmpty) {
      sampleProduct = available[DateTime.now().microsecond % available.length];
    } else if (products.isNotEmpty) {
      sampleProduct = products.first;
    } else {
      final now = DateTime.now();
      sampleProduct = AppProduct(
        id: 0,
        sku: 'PAN-PAR-500MG',
        name: 'Panadol Extra 500mg',
        costPrice: 80,
        sellingPrice: 100,
        stockQuantity: 50,
        lowStockThreshold: 10,
        barcode: '2004567891234',
        createdAt: now,
        updatedAt: now,
      );
    }

    final barcodeData = (sampleProduct.barcode != null && sampleProduct.barcode!.trim().isNotEmpty)
        ? sampleProduct.barcode!.trim()
        : sampleProduct.sku.trim();

    await showDialog(
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
                      isArabic ? 'محاكاة طباعة ومسح باركود الدواء' : 'Medicine Barcode Print & Scan Simulation',
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
                              sampleProduct.name,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'ج.س ${sampleProduct.sellingPrice}',
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
                            'SKU: ${sampleProduct.sku}',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 10),
                          ),
                          Text(
                            'EXP: 2028-12-31',
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
                      ? 'يمكنك محاكاة طباعة ملصق الباركود على عبوة الدواء افتراضياً، أو محاكاة مسحه وإرساله لشاشة البيع.'
                      : 'Simulate printing this medicine barcode label, or simulate scanning it into POS.',
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
            OutlinedButton.icon(
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
                                  ? 'تمت محاكاة إرسال ملصق باركود (${sampleProduct.name}) لطابعة الملصقات بنجاح!'
                                  : 'Simulated printing barcode label for ${sampleProduct.name} successfully!',
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
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _barcodeController.text = barcodeData;
                _handleSearchSubmitted(barcodeData);
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isArabic
                                  ? 'تمت محاكاة المسح وإضافة (${sampleProduct.name}) إلى الفاتورة!'
                                  : 'Simulated scan and added ${sampleProduct.name} to invoice!',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF1E293B),
                    ),
                  );
              },
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: Text(isArabic ? 'محاكاة مسح في الكاشير' : 'Simulate POS Scan'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _focusBarcode() {
    _barcodeFocus.requestFocus();
  }

  Future<void> _lookupAndAdd(String raw) async {
    final l10n = AppLocalizations.of(context);
    final value = raw.trim();
    _barcodeController.clear();
    if (value.isEmpty) {
      return;
    }
    final repo = ref.read(productRepositoryProvider);
    var product = await repo.findByBarcode(value);
    product ??= await repo.findBySku(value);
    if (!mounted) {
      return;
    }
    if (product == null) {
      _showMessage(l10n.productNotFound);
    } else {
      _selectProduct(product);
    }
  }

  Future<void> _openPayment() async {
    _removeOverlay();
    final l10n = AppLocalizations.of(context);
    final pos = ref.read(posControllerProvider);
    if (pos.isEmpty) {
      _showMessage(l10n.emptyCart);
      return;
    }
    if (pos.hasInsufficientStock) {
      _showMessage(l10n.insufficientStock);
      return;
    }
    final taxRate = ref.read(taxRateProvider).valueOrNull ?? 0;
    final currency = ref.read(currencySymbolProvider).valueOrNull ?? 'ج.س';

    // Balance and credit limit for the selected customer (0 for walk-in).
    var outstanding = 0;
    var creditLimit = 0;
    final customerId = pos.customerId;
    if (customerId != null) {
      final customerRepo = ref.read(customerRepositoryProvider);
      final customer = await customerRepo.findById(customerId);
      if (customer != null) {
        creditLimit = customer.creditLimit;
        outstanding = await customerRepo.getBalance(customerId);
      }
    }
    if (!mounted) {
      return;
    }

    final input = await showDialog<PaymentInput>(
      context: context,
      builder: (context) => PaymentDialog(
        subtotalCents: pos.subtotal,
        discountCents: pos.discountAmount,
        taxCents: pos.taxAmount(taxRate),
        totalCents: pos.total(taxRate),
        currencySymbol: currency,
        allowCredit: true,
        hasCustomer: pos.customerId != null,
        outstandingCents: outstanding,
        creditLimitCents: creditLimit,
      ),
    );
    if (input == null || !mounted) {
      return;
    }
    final user = ref.read(sessionProvider);
    if (user == null) {
      return;
    }
    await _completeSale(input, taxRate, user.id);
  }

  Future<void> _completeSale(
    PaymentInput input,
    double taxRate,
    int userId,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      final receipt = await ref.read(posControllerProvider.notifier).completeSale(
            method: input.method,
            receivedCents: input.receivedCents,
            taxRatePercent: taxRate,
            userId: userId,
            transactionReference: input.transactionReference,
          );
      if (mounted) {
        _showMessage(l10n.saleCompleted(receipt.invoiceNumber));
      }
      await _printReceipt(receipt);
    } on PosSaleException catch (e) {
      final message = switch (e.code) {
        PosError.emptyCart => l10n.emptyCart,
        PosError.insufficientReceived => l10n.insufficientReceived,
        PosError.customerRequired => l10n.creditNeedsCustomer,
        PosError.creditLimitExceeded => l10n.creditLimitExceeded,
        PosError.insufficientStock => l10n.insufficientStock,
        null => l10n.errorOccurred,
      };
      if (mounted) {
        _showMessage(message);
      }
    } on Exception {
      if (mounted) {
        _showMessage(l10n.errorOccurred);
      }
    }
  }

  Future<void> _printReceipt(SaleReceipt receipt) async {
    final l10n = AppLocalizations.of(context);
    final user = ref.read(sessionProvider);
    final store = await ref.read(settingsRepositoryProvider).getStoreSettings();
    if (!mounted) {
      return;
    }
    final data = ReceiptData(
      store: store,
      invoiceNumber: receipt.invoiceNumber,
      dateTime: DateFormat.yMd(l10n.localeName)
          .add_Hm()
          .format(receipt.createdAt),
      cashierName: user?.username ?? '',
      paymentMethod: _paymentMethodLabel(receipt.paymentMethod, l10n),
      transactionReference: receipt.transactionReference,
      lines: [
        for (final item in receipt.items)
          ReceiptLine(
            name: item.productName,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            totalPrice: item.totalPrice,
          ),
      ],
      subtotal: receipt.subtotal,
      discount: receipt.discount,
      taxAmount: receipt.taxAmount,
      totalAmount: receipt.totalAmount,
      paidAmount: receipt.paidAmount,
      changeAmount: receipt.changeAmount,
    );

    try {
      await ref.read(thermalPrinterServiceProvider).printReceipt(
        data,
        labels: ReceiptLabels(
          invoice: l10n.receiptInvoice,
          cashier: l10n.receiptCashier,
          customer: l10n.receiptCustomer,
          subtotal: l10n.subtotal,
          discount: l10n.discount,
          tax: l10n.tax,
          total: l10n.total,
          paid: l10n.amountReceived,
          change: l10n.changeDue,
          onAccount: l10n.receiptOnAccount,
          thanks: l10n.receiptThanks,
        ),
      );
    } catch (e) {
      debugPrint('Thermal printer dispatch error: $e');
      if (!mounted) {
        return;
      }
      final message =
          e is PrinterException ? e.message : l10n.printFailedMessage;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.printFailed),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.dismiss),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _printReceipt(receipt);
              },
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _holdSale() async {
    _removeOverlay();
    final l10n = AppLocalizations.of(context);
    final user = ref.read(sessionProvider);
    if (user == null) {
      return;
    }
    try {
      await ref.read(posControllerProvider.notifier).holdSale(userId: user.id);
      _showMessage(l10n.saleHeld);
    } on PosSaleException {
      _showMessage(l10n.emptyCart);
    } on Exception {
      _showMessage(l10n.errorOccurred);
    }
  }

  Future<void> _resumeHold() async {
    _removeOverlay();
    final l10n = AppLocalizations.of(context);
    final held = await showDialog<AppSalesHold>(
      context: context,
      builder: (context) => const HoldsDialog(),
    );
    if (held == null || !mounted) {
      return;
    }
    final items = <CartItem>[];
    final missing = <String>[];
    try {
      final raw = jsonDecode(held.itemsJson);
      if (raw is List) {
        final repo = ref.read(productRepositoryProvider);
        for (final entry in raw) {
          if (entry is! Map<String, dynamic>) {
            continue;
          }
          final productId = (entry['productId'] as num?)?.toInt();
          if (productId == null) {
            continue;
          }
          final product = await repo.findById(productId);
          if (product != null) {
            items.add(CartItem.fromJson(entry, product));
          } else {
            final name = entry['productName'] as String?;
            if (name != null && name.isNotEmpty) {
              missing.add(name);
            }
          }
        }
      }
    } on FormatException {
      items.clear();
      missing.clear();
    }
    if (!mounted) {
      return;
    }
    if (items.isEmpty) {
      _showMessage(l10n.productNotFound);
      return;
    }
    final discountType = held.discountType;
    final discountValue = discountFromStored(discountType, held.discount);
    _discountController.text =
        discountType == null ? '' : _formatDiscount(discountType, discountValue);
    ref.read(posControllerProvider.notifier).loadCart(
          items,
          discountType: discountType,
          discountValue: discountValue,
        );
    if (missing.isEmpty) {
      await ref.read(salesHoldRepositoryProvider).deleteHold(held.id);
    } else {
      // Some products were deleted since the sale was held; keep the hold so
      // the missing lines are not lost, and tell the user what was skipped.
      _showMessage(l10n.holdPartiallyRestored(missing.join(', ')));
    }
  }

  Future<void> _clearCart() async {
    _removeOverlay();
    final l10n = AppLocalizations.of(context);
    if (ref.read(posControllerProvider).isEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearCart),
        content: Text(l10n.confirmClearCartMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.clearCart),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _discountController.clear();
      ref.read(posControllerProvider.notifier).clear();
    }
  }

  String _formatDiscount(DiscountType type, double value) {
    return type == DiscountType.percentage
        ? value.toStringAsFixed(0)
        : formatCents(value.round());
  }

  String _paymentMethodLabel(String name, AppLocalizations l10n) {
    switch (name) {
      case 'cash':
        return l10n.paymentCash;
      case 'card':
        return l10n.paymentCard;
      case 'bankTransfer':
        return l10n.paymentBankTransfer;
      case 'mobileMoney':
        return l10n.paymentMobileMoney;
      case 'credit':
        return l10n.paymentCredit;
      default:
        return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pos = ref.watch(posControllerProvider);
    final currency = ref.watch(currencySymbolProvider).valueOrNull ?? 'ج.س';
    final productsAsync = ref.watch(productListProvider);
    final products = productsAsync.valueOrNull ?? const <AppProduct>[];

    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? products
        : products.where((p) {
            return p.name.toLowerCase().contains(query) ||
                p.sku.toLowerCase().contains(query) ||
                (p.barcode?.toLowerCase().contains(query) ?? false) ||
                (p.description?.toLowerCase().contains(query) ?? false);
          }).toList();
    final sellable = filtered.where((p) => !p.isExpired).toList();

    // If the customer selected for this sale is deleted, drop the selection
    // so a stale id never reaches the payment flow.
    ref.listen(customerListProvider, (previous, next) {
      final ids = {
        for (final entry in next.valueOrNull ?? const <CustomerWithBalance>[])
          entry.customer.id,
      };
      final current = ref.read(posControllerProvider);
      if (current.customerId != null &&
          !ids.contains(current.customerId)) {
        ref.read(posControllerProvider.notifier).setCustomer(null);
      }
    });

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f1): _focusBarcode,
        const SingleActivator(LogicalKeyboardKey.f2): _openPayment,
        const SingleActivator(LogicalKeyboardKey.f4): _holdSale,
        const SingleActivator(LogicalKeyboardKey.escape): _clearCart,
      },
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _toolbar(l10n, currency),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _productPanel(l10n, currency, sellable, productsAsync.hasError),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _cartPanel(l10n, currency, pos),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar(AppLocalizations l10n, String currency) {
    final isAdmin = ref.watch(sessionProvider)?.isAdmin ?? false;
    return Row(
      children: [
        Icon(
          Icons.qr_code_scanner,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TapRegion(
            groupId: _searchTapGroupId,
            child: CompositedTransformTarget(
              link: _layerLink,
              child: SizedBox(
                key: _searchBarKey,
                height: 48,
                child: TextField(
                  controller: _barcodeController,
                  focusNode: _barcodeFocus,
                  autofocus: true,
                  textInputAction: TextInputAction.go,
                  onSubmitted: _handleSearchSubmitted,
                  decoration: InputDecoration(
                    hintText: l10n.scanBarcode,
                    prefixIcon: const Icon(Icons.keyboard),
                    suffixIcon: _barcodeController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _barcodeController.clear();
                              _removeOverlay();
                              _focusBarcode();
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isAdmin) ...[
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _openBarcodeSimulationDialog,
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: Text(
              l10n.localeName.startsWith('ar')
                  ? 'محاكاة طباعة ومسح باركود'
                  : 'Simulate Barcode',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: _resumeHold,
          icon: const Icon(Icons.pause_circle_outline),
          label: Text(l10n.resumeHold),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _holdSale,
          icon: const Icon(Icons.pause_circle_filled_outlined),
          label: Text(l10n.holdSale),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _clearCart,
          icon: const Icon(Icons.delete_sweep_outlined),
          label: Text(l10n.clearCart),
        ),
      ],
    );
  }

  Widget _productPanel(
    AppLocalizations l10n,
    String currency,
    List<AppProduct> filtered,
    bool hasError,
  ) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
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
          Expanded(
            child: hasError
                ? Center(child: Text(l10n.errorOccurred))
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noProducts,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          mainAxisExtent: 148,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _ProductTile(
                            product: filtered[index],
                            currency: currency,
                            stockLabel: l10n.stock,
                            outOfStockLabel: l10n.stockOut,
                            onTap: () =>
                                ref.read(posControllerProvider.notifier).addProduct(filtered[index]),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _cartPanel(AppLocalizations l10n, String currency, PosState pos) {
    final theme = Theme.of(context);
    final taxRate = ref.read(taxRateProvider).valueOrNull ?? 0;
    final notifier = ref.read(posControllerProvider.notifier);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.shopping_cart_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '${l10n.cart} (${pos.itemCount})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: pos.isEmpty
                ? Center(
                    child: Text(
                      l10n.emptyCart,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: pos.items.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final item = pos.items[index];
                      return _CartItemTile(
                        item: item,
                        currency: currency,
                        onIncrement: () => notifier.increment(item.product.id),
                        onDecrement: () => notifier.decrement(item.product.id),
                        onRemove: () => notifier.removeItem(item.product.id),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final customers =
                        ref.watch(customerListProvider).valueOrNull ??
                            const <CustomerWithBalance>[];
                    final validIds = {
                      for (final entry in customers) entry.customer.id,
                    };
                    // The selected customer may have been deleted since the
                    // sale started; fall back to walk-in so the dropdown never
                    // shows a value that is not among its items.
                    final selected = validIds.contains(pos.customerId)
                        ? pos.customerId
                        : null;
                    return DropdownButtonFormField<int?>(
                      key: ValueKey('customer-$selected'),
                      initialValue: selected,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.customer,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(l10n.walkInCustomer),
                        ),
                        for (final entry in customers)
                          DropdownMenuItem<int?>(
                            value: entry.customer.id,
                            child: Text(
                              entry.customer.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (id) => notifier.setCustomer(id),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<DiscountType?>(
                        value: pos.discountType,
                        isExpanded: true,
                        hint: Text(l10n.discount),
                        items: [
                          DropdownMenuItem<DiscountType?>(
                            value: null,
                            child: Text(l10n.discountNone),
                          ),
                          DropdownMenuItem<DiscountType?>(
                            value: DiscountType.percentage,
                            child: Text(l10n.discountPercentage),
                          ),
                          DropdownMenuItem<DiscountType?>(
                            value: DiscountType.fixed,
                            child: Text(l10n.discountFixed),
                          ),
                        ],
                        onChanged: (type) {
                          _discountController.clear();
                          notifier.setDiscount(type, 0);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _discountController,
                        enabled: pos.discountType != null,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          notifier.setDiscount(
                            pos.discountType,
                            double.tryParse(value.trim()) ?? 0,
                          );
                        },
                        decoration: InputDecoration(
                          labelText: l10n.discount,
                          suffixText: pos.discountType == DiscountType.percentage
                              ? '%'
                              : currency,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _totalRow(l10n.subtotal, formatMoney(pos.subtotal, symbol: currency)),
                if (pos.discountAmount > 0)
                  _totalRow(
                    l10n.discount,
                    '-${formatMoney(pos.discountAmount, symbol: currency)}',
                    highlight: theme.colorScheme.error,
                  ),
                if (pos.taxAmount(taxRate) > 0)
                  _totalRow(
                    l10n.tax,
                    formatMoney(pos.taxAmount(taxRate), symbol: currency),
                  ),
                const Divider(height: 20),
                Row(
                  children: [
                    Text(
                      l10n.total,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatMoney(pos.total(taxRate), symbol: currency),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: pos.canPay ? _openPayment : null,
                  icon: const Icon(Icons.point_of_sale),
                  label: Text('${l10n.pay} (F2)'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${l10n.hintScan} | ${l10n.hintPay} | ${l10n.hintHold} | ${l10n.hintClear}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {Color? highlight}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: highlight,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.currency,
    required this.stockLabel,
    required this.outOfStockLabel,
    required this.onTap,
  });

  final AppProduct product;
  final String currency;
  final String stockLabel;
  final String outOfStockLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final low = product.isLowStock;
    final disabled = product.stockQuantity == 0;

    final Color stockBgColor = disabled
        ? theme.colorScheme.errorContainer
        : (low ? theme.colorScheme.tertiaryContainer : theme.colorScheme.surfaceContainerHighest);
    final Color stockTextColor = disabled
        ? theme.colorScheme.onErrorContainer
        : (low ? theme.colorScheme.onTertiaryContainer : theme.colorScheme.onSurfaceVariant);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: disabled
              ? theme.colorScheme.error.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: disabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.description != null && product.description!.trim().isNotEmpty
                        ? '${product.sku} • ${product.description}'
                        : product.sku,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    alignment: AlignmentDirectional.centerStart,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatMoney(product.sellingPrice, symbol: currency),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: stockBgColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          disabled
                              ? Icons.cancel_outlined
                              : (low ? Icons.warning_amber_rounded : Icons.inventory_2_outlined),
                          size: 12,
                          color: stockTextColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            disabled ? outOfStockLabel : '$stockLabel: ${product.stockQuantity}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: stockTextColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 10.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
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

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.currency,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartItem item;
  final String currency;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxed = item.quantity >= item.product.stockQuantity;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
            ],
          ),
          Row(
            children: [
              Text(
                formatMoney(item.unitPrice, symbol: currency),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  maxed
                      ? '${item.quantity}/${item.product.stockQuantity}'
                      : '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: onDecrement,
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${item.quantity}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: maxed ? null : onIncrement,
              ),
              SizedBox(
                width: 84,
                child: Text(
                  formatMoney(item.totalPrice, symbol: currency),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _ScoredProduct {
  const _ScoredProduct({
    required this.product,
    required this.score,
  });

  final AppProduct product;
  final int score;
}
