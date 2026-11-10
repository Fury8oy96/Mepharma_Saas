class StaffProductFeedback {
  final int id;
  final int? productId;
  final String productName;
  final String? productSku;
  final int? supplierId;
  final String? supplierName;
  final int currentStock;
  final int? staffUserId;
  final String staffUsername;
  final int branchId;
  final String urgency; // 'urgent', 'normal', 'high_demand'
  final int suggestedQuantity;
  final String? notes;
  final String status; // 'pending', 'ordered', 'dismissed'
  final DateTime createdAt;

  const StaffProductFeedback({
    required this.id,
    this.productId,
    required this.productName,
    this.productSku,
    this.supplierId,
    this.supplierName,
    this.currentStock = 0,
    this.staffUserId,
    this.staffUsername = 'Staff',
    this.branchId = 1,
    this.urgency = 'normal',
    this.suggestedQuantity = 10,
    this.notes,
    this.status = 'pending',
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isOrdered => status == 'ordered';
  bool get isDismissed => status == 'dismissed';

  bool get isUrgent => urgency == 'urgent';
  bool get isHighDemand => urgency == 'high_demand';

  factory StaffProductFeedback.fromJson(Map<String, dynamic> json) {
    return StaffProductFeedback(
      id: json['id'] as int? ?? 0,
      productId: json['product_id'] as int? ?? json['productId'] as int?,
      productName: json['product_name'] as String? ??
          json['productName'] as String? ??
          'Unknown Drug',
      productSku: json['product_sku'] as String? ?? json['productSku'] as String?,
      supplierId: json['supplier_id'] as int? ?? json['supplierId'] as int?,
      supplierName: json['supplier_name'] as String? ?? json['supplierName'] as String?,
      currentStock: json['current_stock'] as int? ??
          json['currentStock'] as int? ??
          0,
      staffUserId: json['staff_user_id'] as int? ?? json['staffUserId'] as int?,
      staffUsername: json['staff_username'] as String? ??
          json['staffUsername'] as String? ??
          'Staff',
      branchId: json['branch_id'] as int? ?? json['branchId'] as int? ?? 1,
      urgency: json['urgency'] as String? ?? 'normal',
      suggestedQuantity: json['suggested_quantity'] as int? ??
          json['suggestedQuantity'] as int? ??
          10,
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'product_sku': productSku,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'current_stock': currentStock,
      'staff_user_id': staffUserId,
      'staff_username': staffUsername,
      'branch_id': branchId,
      'urgency': urgency,
      'suggested_quantity': suggestedQuantity,
      'notes': notes,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  StaffProductFeedback copyWith({
    int? id,
    int? productId,
    String? productName,
    String? productSku,
    int? supplierId,
    String? supplierName,
    int? currentStock,
    int? staffUserId,
    String? staffUsername,
    int? branchId,
    String? urgency,
    int? suggestedQuantity,
    String? notes,
    String? status,
    DateTime? createdAt,
  }) {
    return StaffProductFeedback(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productSku: productSku ?? this.productSku,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      currentStock: currentStock ?? this.currentStock,
      staffUserId: staffUserId ?? this.staffUserId,
      staffUsername: staffUsername ?? this.staffUsername,
      branchId: branchId ?? this.branchId,
      urgency: urgency ?? this.urgency,
      suggestedQuantity: suggestedQuantity ?? this.suggestedQuantity,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
