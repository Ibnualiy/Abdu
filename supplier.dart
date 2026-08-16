/// Who a purchase order was bought from. Deliberately minimal (no
/// accounts-payable ledger like Customer has) — add one later the same
/// way Customer/LedgerEntry works, if you start buying on credit terms
/// from suppliers too.
class Supplier {
  final String id;
  final String name;
  final String? phone;
  final DateTime updatedAt;
  final int syncStatus;

  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    required this.updatedAt,
    this.syncStatus = 1,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'updated_at': updatedAt.toIso8601String(),
        'sync_status': syncStatus,
      };

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncStatus: map['sync_status'] as int? ?? 0,
      );
}
