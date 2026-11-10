import 'dart:async';
import 'dart:convert';

import '../../../domain/models/app_sale.dart';
import '../../../domain/models/app_return.dart';
import '../../../domain/models/sale_receipt.dart';
import '../../../domain/repositories/sale_repository.dart';
import '../../../core/services/api_client.dart';
import '../../db/enums.dart';

class ApiSaleRepository implements SaleRepository {
  ApiSaleRepository(this._client) {
    _initStream();
  }

  final ApiClient _client;
  final _salesController = StreamController<List<AppSale>>.broadcast();
  List<AppSale> _cachedSales = [];

  void _initStream() {
    _salesController.onListen = () {
      _refreshSales();
    };
  }

  Future<void> _refreshSales() async {
    try {
      final sales = await _fetchSales();
      _cachedSales = sales;
      _salesController.add(sales);
    } catch (_) {
      _salesController.add(_cachedSales);
    }
  }

  Future<List<AppSale>> _fetchSales() async {
    final response = await _client.get('/sales');
    final data = jsonDecode(response.body) as List;
    return data.map((item) => _mapSale(item as Map<String, dynamic>)).toList();
  }

  AppSale _mapSale(Map<String, dynamic> json) {
    return AppSale(
      id: json['id'] as int,
      invoiceNumber: json['invoice_number'] as String? ?? json['invoiceNumber'] as String? ?? '',
      userId: json['user_id'] as int? ?? json['userId'] as int? ?? 0,
      customerName: json['customer_name'] as String? ?? json['customerName'] as String?,
      subtotal: json['subtotal'] as int? ?? 0,
      discount: json['discount'] as int? ?? 0,
      discountType: json['discount_type'] != null
          ? DiscountType.values.firstWhere(
              (e) => e.name == (json['discount_type'] as String).toLowerCase(),
              orElse: () => DiscountType.percentage,
            )
          : null,
      taxAmount: json['tax_amount'] as int? ?? json['taxAmount'] as int? ?? 0,
      totalAmount: json['total_amount'] as int? ?? json['totalAmount'] as int? ?? 0,
      paidAmount: json['paid_amount'] as int? ?? json['paidAmount'] as int? ?? 0,
      changeAmount: json['change_amount'] as int? ?? json['changeAmount'] as int? ?? 0,
      paymentMethod: json['payment_method'] as String? ?? json['paymentMethod'] as String?,
      customerId: json['customer_id'] as int? ?? json['customerId'] as int?,
      status: SaleStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? '').toLowerCase(),
        orElse: () => SaleStatus.completed,
      ),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? json['createdAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    );
  }

  AppSaleItem _mapSaleItem(Map<String, dynamic> json) {
    return AppSaleItem(
      id: json['id'] as int,
      saleId: json['sale_id'] as int? ?? json['saleId'] as int? ?? 0,
      productId: json['product_id'] as int? ?? json['productId'] as int?,
      productName: json['product_name'] as String? ?? json['productName'] as String? ?? '',
      barcode: json['barcode'] as String? ?? json['barcode'] as String?,
      quantity: json['quantity'] as int? ?? 0,
      unitPrice: json['unit_price'] as int? ?? json['unitPrice'] as int? ?? 0,
      discount: json['discount'] as int? ?? 0,
      totalPrice: json['total_price'] as int? ?? json['totalPrice'] as int? ?? 0,
    );
  }

  @override
  Future<String> generateInvoiceNumber() async {
    try {
      final response = await _client.get('/sales/next-number');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['number'] as String;
    } catch (_) {
      final stamp = DateTime.now().toString().replaceAll('-', '').split(' ').first;
      final seq = _cachedSales.length + 1;
      return 'INV-$stamp-${seq.toString().padLeft(4, '0')}';
    }
  }

  @override
  Future<SaleReceipt> completeSale({
    required List<SaleLineItem> items,
    required int subtotal,
    required int discount,
    DiscountType? discountType,
    required int taxAmount,
    required int totalAmount,
    required int paidAmount,
    required int changeAmount,
    required String paymentMethod,
    required int userId,
    String? customerName,
    int? customerId,
  }) async {
    final bodyItems = items.map((i) => {
      'product_id': i.productId,
      'product_name': i.productName,
      'quantity': i.quantity,
      'unit_price': i.unitPrice,
      'total_price': i.totalPrice,
    }).toList();

    final response = await _client.post('/sales', body: {
      'items': bodyItems,
      'subtotal': subtotal,
      'discount': discount,
      'discount_type': discountType?.name,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'change_amount': changeAmount,
      'payment_method': paymentMethod,
      'user_id': userId,
      'customer_name': customerName,
      'customer_id': customerId,
    });

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final saleMap = data['sale'] is Map<String, dynamic>
        ? data['sale'] as Map<String, dynamic>
        : data;
    final sale = _mapSale(saleMap);

    _refreshSales();

    return SaleReceipt(
      id: sale.id,
      invoiceNumber: sale.invoiceNumber,
      createdAt: sale.createdAt,
      subtotal: sale.subtotal,
      discount: sale.discount,
      discountType: sale.discountType,
      taxAmount: sale.taxAmount,
      totalAmount: sale.totalAmount,
      paidAmount: sale.paidAmount,
      changeAmount: sale.changeAmount,
      paymentMethod: sale.paymentMethod ?? 'Cash',
      customerName: sale.customerName,
      customerId: sale.customerId,
      items: items,
    );
  }

  @override
  Stream<List<AppSale>> watchSales({
    DateTime? from,
    DateTime? to,
    String? paymentMethod,
    SaleStatus? status,
    String? search,
  }) {
    // Return filtered values mapped dynamically from our sales stream
    return _salesController.stream.map((list) {
      return list.where((sale) {
        if (from != null && sale.createdAt.isBefore(from)) {
          return false;
        }
        if (to != null && sale.createdAt.isAfter(to)) {
          return false;
        }
        if (paymentMethod != null &&
            (sale.paymentMethod == null ||
                !sale.paymentMethod!.toLowerCase().contains(paymentMethod.toLowerCase()))) {
          return false;
        }
        if (status != null && sale.status != status) {
          return false;
        }
        if (search != null &&
            !sale.invoiceNumber.toLowerCase().contains(search.toLowerCase()) &&
            !(sale.customerName ?? '').toLowerCase().contains(search.toLowerCase())) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  @override
  Future<SaleDetail> getSaleDetail(int id) async {
    final response = await _client.get('/sales/$id');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final saleMap = data['sale'] is Map<String, dynamic>
        ? data['sale'] as Map<String, dynamic>
        : data;
    final sale = _mapSale(saleMap);
    final itemsList = (data['items'] as List?) ?? [];
    final items = itemsList.map((i) => _mapSaleItem(i as Map<String, dynamic>)).toList();
    
    // Check if there are returns
    final returnsList = data['returns'] as List? ?? [];
    final returns = returnsList.map((r) => AppReturn(
      id: r['id'] as int,
      saleId: r['sale_id'] as int? ?? r['saleId'] as int? ?? 0,
      invoiceNumber: r['invoice_number'] as String? ?? r['invoiceNumber'] as String? ?? '',
      userId: r['user_id'] as int? ?? r['userId'] as int? ?? 0,
      totalRefund: r['total_refund'] as int? ?? r['totalRefund'] as int? ?? 0,
      reason: r['reason'] as String?,
      createdAt: DateTime.tryParse(r['created_at'] as String? ?? r['createdAt'] as String? ?? '') ?? DateTime.now(),
    )).toList();

    return SaleDetail(
      sale: sale,
      items: items,
      returns: returns,
    );
  }

  @override
  Future<void> refresh() async {
    await _refreshSales();
  }
}
