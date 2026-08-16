/// One line in a customer's running account. Positive [amount] = they now
/// owe more (a credit sale); negative = they paid some down. Never
/// updated or deleted once written — a customer's balance is always the
/// sum of their entries (see DatabaseService.getCustomerBalance), which
/// is what makes this safe under offline-first sync: two devices can add
/// entries independently and the total still comes out right, unlike a
/// single mutable "balance" column that two offline writers could stomp
/// on each other's changes to.
class LedgerEntry {
  final String id;
  final String customerId;
  final double amount;
  final String note;
  final DateTime occurredAt;
  final int syncStatus;

  const LedgerEntry({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.note,
    required this.occurredAt,
    this.syncStatus = 1,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'customer_id': customerId,
        'amount': amount,
        'note': note,
        'occurred_at': occurredAt.toIso8601String(),
        'sync_status': syncStatus,
      };

  factory LedgerEntry.fromMap(Map<String, dynamic> map) => LedgerEntry(
        id: map['id'] as String,
        customerId: map['customer_id'] as String,
        amount: (map['amount'] as num).toDouble(),
        note: map['note'] as String,
        occurredAt: DateTime.parse(map['occurred_at'] as String),
        syncStatus: map['sync_status'] as int? ?? 0,
      );
}
