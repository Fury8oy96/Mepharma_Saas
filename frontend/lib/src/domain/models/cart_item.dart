import 'app_product.dart';

/// A product line in the POS cart.
class CartItem {
  const CartItem({required this.product, required this.quantity});

  final AppProduct product;
  final int quantity;

  /// Minor units (cents).
  int get unitPrice => product.sellingPrice;

  /// Minor units (cents).
  int get totalPrice => unitPrice * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(product: product, quantity: quantity ?? this.quantity);
  }

  /// Serializes a snapshot for held sales. Product fields are captured so a
  /// hold can be resumed even if the product is later edited.
  Map<String, dynamic> toJson() {
    return {
      'productId': product.id,
      'name': product.name,
      'barcode': product.barcode,
      'unitPrice': product.sellingPrice,
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json, AppProduct product) {
    return CartItem(
      product: product,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}
