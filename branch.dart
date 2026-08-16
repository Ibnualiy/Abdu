/// A physical shop/warehouse location. Deliberately layered on top of
/// the existing single product catalog rather than splitting stock per
/// branch (see database_service.dart comment on insertSale) — this
/// tags WHERE a sale or delivery happened for reporting, without the
/// bigger surgery of giving every product a separate stock count per
/// location. Add that later (a `branch_stock` join table keyed on
/// product_id + branch_id) if you outgrow a shared stock pool.
class Branch {
  final String id;
  final String name;
  final String? location;
  final DateTime updatedAt;
  final int syncStatus;

  const Branch({
    required this.id,
    required this.name,
    this.location,
    required this.updatedAt,
    this.syncStatus = 1,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'location': location,
        'updated_at': updatedAt.toIso8601String(),
        'sync_status': syncStatus,
      };

  factory Branch.fromMap(Map<String, dynamic> map) => Branch(
        id: map['id'] as String,
        name: map['name'] as String,
        location: map['location'] as String?,
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncStatus: map['sync_status'] as int? ?? 0,
      );
}
