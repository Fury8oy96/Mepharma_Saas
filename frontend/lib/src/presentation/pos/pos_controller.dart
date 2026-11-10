import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/db/enums.dart';
import '../../domain/models/app_product.dart';
import '../../domain/models/app_sales_hold.dart';
import '../../domain/models/cart_item.dart';
import '../../domain/models/payment_method.dart';
import '../../domain/models/sale_receipt.dart';

/// Distinct failure reasons so the UI can show a specific message.
enum PosError {
  emptyCart,
  insufficientStock,
  insufficientReceived,
  customerRequired,
  creditLimitExceeded,
}

/// Thrown when a sale cannot be completed from the current cart.
class PosSaleException implements Exception {
  const PosSaleException(this.message, {this.code});

  final String message;
  final PosError? code;

  @override
  String toString() => message;
}

/// Computed totals for a cart.
class PosTotals {
  const PosTotals({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
  });

  /// Minor units (cents).
  final int subtotal;

  /// Minor units (cents).
  final int discount;

  /// Minor units (cents).
  final int tax;

  /// Minor units (cents), final payable.
  final int total;
}

class PosState {
  const PosState({
    this.items = const [],
    this.discountType,
    this.discountValue = 0,
    this.customerId,
    this.processing = false,
  });

  final List<CartItem> items;

  /// Percentage when [discountType] is `percentage`, cents when `fixed`.
  final DiscountType? discountType;
  final double discountValue;

  /// Selected customer for the current sale (null = walk-in).
  final int? customerId;
  final bool processing;

  /// Minor units (cents).
  int get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);

  /// Minor units (cents).
  int get discountAmount {
    if (discountType == null) {
      return 0;
    }
    if (discountType == DiscountType.fixed) {
      return discountValue.round();
    }
    return ((subtotal * discountValue) / 100).round();
  }

  /// Minor units (cents).
  int taxAmount(double taxRatePercent) {
    final taxable = subtotal - discountAmount;
    return ((taxable * taxRatePercent) / 100).round();
  }

  /// Minor units (cents), final payable.
  int total(double taxRatePercent) {
    return subtotal - discountAmount + taxAmount(taxRatePercent);
  }

  bool get isEmpty => items.isEmpty;

  bool get hasInsufficientStock =>
      items.any((item) => item.quantity > item.product.stockQuantity);

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  int quantityOf(int productId) {
    for (final item in items) {
      if (item.product.id == productId) {
        return item.quantity;
      }
    }
    return 0;
  }

  bool get canPay => !isEmpty && !hasInsufficientStock && !processing;
}

class PosController extends Notifier<PosState> {
  @override
  PosState build() => const PosState();

  void addProduct(AppProduct product) {
    if (product.stockQuantity <= 0) {
      return;
    }
    final items = [...state.items];
    final index = items.indexWhere((item) => item.product.id == product.id);
    if (index == -1) {
      items.add(CartItem(product: product, quantity: 1));
    } else {
      final current = items[index].quantity;
      if (current >= product.stockQuantity) {
        return;
      }
      items[index] = items[index].copyWith(quantity: current + 1);
    }
    _emit(items);
  }

  void increment(int productId) {
    final items = [...state.items];
    final index = items.indexWhere((item) => item.product.id == productId);
    if (index == -1) {
      return;
    }
    final item = items[index];
    if (item.quantity >= item.product.stockQuantity) {
      return;
    }
    items[index] = item.copyWith(quantity: item.quantity + 1);
    _emit(items);
  }

  void decrement(int productId) {
    final items = [...state.items];
    final index = items.indexWhere((item) => item.product.id == productId);
    if (index == -1) {
      return;
    }
    final item = items[index];
    if (item.quantity <= 1) {
      items.removeAt(index);
    } else {
      items[index] = item.copyWith(quantity: item.quantity - 1);
    }
    _emit(items);
  }

  void removeItem(int productId) {
    _emit([...state.items]..removeWhere((item) => item.product.id == productId));
  }

  void clear() {
    state = const PosState();
  }

  void setDiscount(DiscountType? type, double value) {
    if (type == null) {
      state = PosState(
        items: state.items,
        discountType: null,
        discountValue: 0,
        customerId: state.customerId,
      );
      return;
    }
    final clamped = type == DiscountType.percentage
        ? value.clamp(0, 100).toDouble()
        : value.clamp(0, double.infinity).toDouble();
    state = PosState(
      items: state.items,
      discountType: type,
      discountValue: clamped,
      customerId: state.customerId,
    );
  }

  void setCustomer(int? customerId) {
    state = PosState(
      items: state.items,
      discountType: state.discountType,
      discountValue: state.discountValue,
      customerId: customerId,
    );
  }

  void loadCart(
    List<CartItem> items, {
    DiscountType? discountType,
    double discountValue = 0,
    int? customerId,
  }) {
    state = PosState(
      items: List.unmodifiable(items),
      discountType: discountType,
      discountValue: discountValue,
      customerId: customerId,
    );
  }

  /// Records a completed sale in a transaction and clears the cart.
  Future<SaleReceipt> completeSale({
    required PaymentMethod method,
    required int receivedCents,
    required double taxRatePercent,
    required int userId,
  }) async {
    final current = state;
    if (current.items.isEmpty) {
      throw const PosSaleException(
        'Cart is empty.',
        code: PosError.emptyCart,
      );
    }
    if (current.hasInsufficientStock) {
      throw const PosSaleException(
        'Cart contains insufficient stock.',
        code: PosError.insufficientStock,
      );
    }
    if (method == PaymentMethod.credit && current.customerId == null) {
      throw const PosSaleException(
        'A customer must be selected for credit sales.',
        code: PosError.customerRequired,
      );
    }
    state = PosState(
      items: current.items,
      discountType: current.discountType,
      discountValue: current.discountValue,
      customerId: current.customerId,
      processing: true,
    );
    try {
      final items = [
        for (final item in current.items)
          SaleLineItem(
            productId: item.product.id,
            productName: item.product.name,
            barcode: item.product.barcode,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            totalPrice: item.totalPrice,
          ),
      ];
      final total = current.total(taxRatePercent);
      if (method == PaymentMethod.cash && receivedCents < total) {
        throw const PosSaleException(
          'Amount received is less than the total.',
          code: PosError.insufficientReceived,
        );
      }
      // Credit sales defer the full amount to the customer's account.
      final paid = method == PaymentMethod.credit ? 0 : receivedCents;
      final change = paid > total ? paid - total : 0;

      final customer =
          current.customerId == null
              ? null
              : await ref.read(customerRepositoryProvider).findById(
                    current.customerId!,
                  );

      // Enforce the credit limit (a limit of 0 means no limit).
      if (method == PaymentMethod.credit && customer != null) {
        final limit = customer.creditLimit;
        if (limit > 0) {
          final outstanding = await ref
              .read(customerRepositoryProvider)
              .getBalance(customer.id);
          if (outstanding + total > limit) {
            throw PosSaleException(
              'Credit limit exceeded for ${customer.name}.',
              code: PosError.creditLimitExceeded,
            );
          }
        }
      }

      final receipt = await ref.read(saleRepositoryProvider).completeSale(
            items: items,
            subtotal: current.subtotal,
            discount: current.discountAmount,
            discountType: current.discountType,
            taxAmount: current.taxAmount(taxRatePercent),
            totalAmount: total,
            paidAmount: paid,
            changeAmount: change,
            paymentMethod: method.name,
            userId: userId,
            customerName: customer?.name,
            customerId: customer?.id,
          );
      state = const PosState();
      // Dashboards and reports read from the database; refresh the cached
      // summaries so the numbers update immediately after the sale.
      ref.invalidate(todaySalesProvider);
      ref.invalidate(monthlyReportProvider);
      ref.invalidate(stockValuationProvider);
      ref.invalidate(reportSummaryProvider);
      return receipt;
    } catch (e) {
      state = PosState(
        items: current.items,
        discountType: current.discountType,
        discountValue: current.discountValue,
        customerId: current.customerId,
      );
      rethrow;
    }
  }

  /// Saves the current cart as a held sale and clears it.
  Future<AppSalesHold> holdSale({required int userId}) async {
    final current = state;
    if (current.isEmpty) {
      throw const PosSaleException('Cart is empty.');
    }
    final itemsJson = jsonEncode([
      for (final item in current.items) item.toJson(),
    ]);
    final held = await ref
        .read(salesHoldRepositoryProvider)
        .createHold(
          userId: userId,
          itemsJson: itemsJson,
          subtotal: current.subtotal,
          discount: _discountToStored(
            current.discountType,
            current.discountValue,
          ),
          discountType: current.discountType,
          totalAmount: current.subtotal - current.discountAmount,
        );
    clear();
    return held;
  }

  void _emit(List<CartItem> items) {
    state = PosState(
      items: List.unmodifiable(items),
      discountType: state.discountType,
      discountValue: state.discountValue,
      customerId: state.customerId,
    );
  }

  /// Stores percentage * 100 (e.g. 5% -> 500) or fixed cents as-is.
  static int _discountToStored(DiscountType? type, double value) {
    if (type == DiscountType.percentage) {
      return (value * 100).round();
    }
    return value.round();
  }
}

/// Restores a held cart: percentage stored * 100 back to percent, fixed as-is.
double discountFromStored(DiscountType? type, int stored) {
  if (type == DiscountType.percentage) {
    return stored / 100;
  }
  return stored.toDouble();
}
