/// A delivery of stock recorded as received. Simplified on purpose: no
/// draft/approved/partially-received workflow like a full ERP purchase
/// order — you record it once, when the goods are actually in hand, and
/// stock updates immediately. That matches how a small merchant or
/// distributor actually logs a delivery; add a status workflow later if
/// you start placing orders well ahead of receiving them.
enum PurchaseOrderStatus { pending, received }

/// A delivery of stock, either already in hand (`received` — stock
/// updates immediately) or on order and not yet arrived (`pending` —
/// recorded so you can track what's coming, but stock only updates
/// once you mark it received via DatabaseService.receivePurchaseOrder).
/// No partial-receiving here: a PO is fully pending or fully received,
/// not line-by-line — simple on purpose, add that granularity later if
/// you actually need to receive an order in multiple batches.
class PurchaseOrder {
  final String id;
  final String? supplierId;
  final String? supplierName;
  final DateTime receivedAt;
  final String? branchId;
  final String? branchName;
  final PurchaseOrderStatus status;
  final int syncStatus;

  const PurchaseOrder({
    required this.id,
    this.supplierId,
    this.supplierName,
    required this.receivedAt,
    this.branchId,
    this.branchName,
    this.status = PurchaseOrderStatus.received,
    this.syncStatus = 1,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'received_at': receivedAt.toIso8601String(),
        'branch_id': branchId,
        'branch_name': branchName,
        'status': status.name,
        'sync_status': syncStatus,
      };

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) => PurchaseOrder(
        id: map['id'] as String,
        supplierId: map['supplier_id'] as String?,
        supplierName: map['supplier_name'] as String?,
        receivedAt: DateTime.parse(map['received_at'] as String),
        branchId: map['branch_id'] as String?,
        branchName: map['branch_name'] as String?,
        status: PurchaseOrderStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => PurchaseOrderStatus.received,
        ),
        syncStatus: map['sync_status'] as int? ?? 0,
      );
}

/// One product/quantity/cost line within a PurchaseOrder. Recording this
/// (see DatabaseService.insertPurchaseOrder) both increases the
/// product's stock_qty and overwrites its cost_price with [unitCost] —
/// "last cost in" rather than a weighted average, which is the simple
/// approximation most small merchants actually want.
class PurchaseOrderLine {
  final String id;
  final String purchaseOrderId;
  final String productId;
  final String productName;
  final int quantity;
  final double unitCost;
  final int syncStatus;

  const PurchaseOrderLine({
    required this.id,
    required this.purchaseOrderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    this.syncStatus = 1,
  });

  double get lineTotal => quantity * unitCost;

  Map<String, dynamic> toMap() => {
        'id': id,
        'purchase_order_id': purchaseOrderId,
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'unit_cost': unitCost,
        'sync_status': syncStatus,
      };

  factory PurchaseOrderLine.fromMap(Map<String, dynamic> map) =>
      PurchaseOrderLine(
        id: map['id'] as String,
        purchaseOrderId: map['purchase_order_id'] as String,
        productId: map['product_id'] as String,
        productName: map['product_name'] as String,
        quantity: map['quantity'] as int,
        unitCost: (map['unit_cost'] as num).toDouble(),
        syncStatus: map['sync_status'] as int? ?? 0,
      );
}
