import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/branch.dart';
import '../models/branch_stock.dart';
import '../models/customer.dart';
import '../models/ledger_entry.dart';
import '../models/product.dart';
import '../models/purchase_order.dart';
import '../models/sale.dart';
import '../models/supplier.dart';

/// Everything in this app reads and writes here first — the phone's SQLite
/// file is the source of truth. `sync_status` on each row (0 = synced,
/// 1 = pending upload) is how SyncService later knows what to push to
/// Supabase once a connection is available. No screen should ever block
/// on the network to show data.
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  static const _dbVersion = 6;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'merchandising_app.db');
    return openDatabase(
      path,
      version: _dbVersion,
      // A brand-new install just runs every step from 0, same as an
      // upgrade would — one migration path, no separate "fresh install"
      // logic to keep in sync with it.
      onCreate: (db, version) => _migrate(db, 0, version),
      onUpgrade: (db, oldVersion, newVersion) =>
          _migrate(db, oldVersion, newVersion),
    );
  }

  Future<void> _migrate(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 1) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS products (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          category TEXT,
          cost_price REAL NOT NULL,
          sell_price REAL NOT NULL,
          stock_qty INTEGER NOT NULL,
          low_stock_threshold INTEGER NOT NULL DEFAULT 5,
          updated_at TEXT NOT NULL,
          sync_status INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sales (
          id TEXT PRIMARY KEY,
          product_id TEXT NOT NULL,
          product_name TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unit_sell_price REAL NOT NULL,
          unit_cost_price REAL NOT NULL,
          sold_at TEXT NOT NULL,
          sync_status INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expenses (
          id TEXT PRIMARY KEY,
          label TEXT NOT NULL,
          amount REAL NOT NULL,
          spent_at TEXT NOT NULL,
          sync_status INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sales_sold_at ON sales (sold_at)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_products_stock ON products (stock_qty)');
    }

    if (oldVersion < 2) {
      await db
          .execute('ALTER TABLE products ADD COLUMN wholesale_price REAL');
      await db.execute('ALTER TABLE sales ADD COLUMN customer_id TEXT');
      await db.execute('ALTER TABLE sales ADD COLUMN customer_name TEXT');
      await db.execute(
          'ALTER TABLE sales ADD COLUMN is_paid_in_full INTEGER NOT NULL DEFAULT 1');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT,
          price_tier TEXT NOT NULL DEFAULT 'wholesale',
          credit_limit REAL NOT NULL DEFAULT 0,
          updated_at TEXT NOT NULL,
          sync_status INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ledger_entries (
          id TEXT PRIMARY KEY,
          customer_id TEXT NOT NULL,
          amount REAL NOT NULL,
          note TEXT NOT NULL,
          occurred_at TEXT NOT NULL,
          sync_status INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_ledger_customer ON ledger_entries (customer_id)');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS suppliers (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT,
          updated_at TEXT NOT NULL,
          sync_status INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchase_orders (
          id TEXT PRIMARY KEY,
          supplier_id TEXT,
          supplier_name TEXT,
          received_at TEXT NOT NULL,
          sync_status INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchase_order_lines (
          id TEXT PRIMARY KEY,
          purchase_order_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          product_name TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unit_cost REAL NOT NULL,
          sync_status INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_po_lines_order ON purchase_order_lines (purchase_order_id)');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS branches (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          location TEXT,
          updated_at TEXT NOT NULL,
          sync_status INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('ALTER TABLE sales ADD COLUMN branch_id TEXT');
      await db.execute('ALTER TABLE sales ADD COLUMN branch_name TEXT');
      await db
          .execute('ALTER TABLE purchase_orders ADD COLUMN branch_id TEXT');
      await db.execute(
          'ALTER TABLE purchase_orders ADD COLUMN branch_name TEXT');
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS branch_stock (
          id TEXT PRIMARY KEY,
          product_id TEXT NOT NULL,
          branch_id TEXT NOT NULL,
          stock_qty INTEGER NOT NULL DEFAULT 0,
          sync_status INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_branch_stock_unique ON branch_stock (product_id, branch_id)');
    }

    if (oldVersion < 6) {
      // Existing rows all went through the old immediate-stock-increase
      // path, so they're correctly backfilled as already 'received'.
      await db.execute(
          "ALTER TABLE purchase_orders ADD COLUMN status TEXT NOT NULL DEFAULT 'received'");
    }
  }

  // ---- Products ----

  Future<void> upsertProduct(Product p) async {
    final db = await database;
    await db.insert('products', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    final rows = await db.query('products', orderBy: 'name ASC');
    return rows.map(Product.fromMap).toList();
  }

  Future<List<Product>> getLowStockProducts() async {
    final db = await database;
    final rows = await db.query('products');
    return rows.map(Product.fromMap).where((p) => p.isLowStock).toList();
  }

  Future<void> deleteProduct(String id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  /// Changes a product's stock by [delta] (negative for a sale,
  /// positive for a delivery). Always updates products.stock_qty —
  /// that stays the running total across every branch, so every
  /// existing screen that reads it keeps working unchanged. If
  /// [branchId] is given, ALSO upserts the matching branch_stock row,
  /// which is what makes per-branch numbers (see getBranchStockMap)
  /// possible for merchants who've set up branches. A sale/purchase
  /// with no branch selected just skips that second part — solo,
  /// single-location use is completely unaffected by this table
  /// existing at all.
  Future<void> _adjustStock(
    Transaction txn, {
    required String productId,
    required int delta,
    String? branchId,
  }) async {
    await txn.rawUpdate(
      'UPDATE products SET stock_qty = stock_qty + ?, sync_status = 1 '
      'WHERE id = ?',
      [delta, productId],
    );
    if (branchId == null) return;

    final id = '${productId}_$branchId';
    final existing = await txn.query('branch_stock',
        where: 'id = ?', whereArgs: [id], limit: 1);
    final currentQty =
        existing.isEmpty ? 0 : existing.first['stock_qty'] as int;
    await txn.insert(
      'branch_stock',
      {
        'id': id,
        'product_id': productId,
        'branch_id': branchId,
        'stock_qty': currentQty + delta,
        'sync_status': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// product_id → stock_qty at this specific branch. Products with no
  /// branch_stock row yet (never sold/received there) are omitted —
  /// treat a missing entry as 0, not as "use the global total".
  Future<Map<String, int>> getBranchStockMap(String branchId) async {
    final db = await database;
    final rows = await db.query('branch_stock',
        where: 'branch_id = ?', whereArgs: [branchId]);
    return {
      for (final r in rows) r['product_id'] as String: r['stock_qty'] as int
    };
  }

  // ---- Sales ----

  /// If [s] is linked to a customer and not paid in full, this also
  /// writes a LedgerEntry for the unpaid amount — all writes (sale,
  /// stock decrement, ledger) share one transaction, so a crash
  /// partway through can't leave stock or a customer's balance wrong.
  Future<void> insertSale(Sale s) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('sales', s.toMap());
      await _adjustStock(txn,
          productId: s.productId, delta: -s.quantity, branchId: s.branchId);
      if (s.customerId != null && !s.isPaidInFull) {
        await txn.insert('ledger_entries', {
          'id': '${s.id}_ledger',
          'customer_id': s.customerId,
          'amount': s.revenue,
          'note': 'Sale: ${s.quantity}x ${s.productName}',
          'occurred_at': s.soldAt.toIso8601String(),
          'sync_status': 1,
        });
      }
    });
  }

  Future<List<Sale>> getSalesBetween(
    DateTime start,
    DateTime end, {
    String? branchId,
  }) async {
    final db = await database;
    final where = StringBuffer('sold_at >= ? AND sold_at <= ?');
    final args = <Object?>[start.toIso8601String(), end.toIso8601String()];
    if (branchId != null) {
      where.write(' AND branch_id = ?');
      args.add(branchId);
    }
    final rows = await db.query(
      'sales',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'sold_at DESC',
    );
    return rows.map(Sale.fromMap).toList();
  }

  // ---- Customers & credit ----

  Future<void> upsertCustomer(Customer c) async {
    final db = await database;
    await db.insert('customers', c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Customer>> getCustomers() async {
    final db = await database;
    final rows = await db.query('customers', orderBy: 'name ASC');
    return rows.map(Customer.fromMap).toList();
  }

  /// Sum of all ledger entries for this customer — never a stored
  /// column, so it can't drift out of sync with the entries themselves.
  /// Positive = they owe this much.
  Future<double> getCustomerBalance(String customerId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM ledger_entries WHERE customer_id = ?',
      [customerId],
    );
    return (result.first['total'] as num).toDouble();
  }

  /// Records a payment against a customer's balance (a negative ledger
  /// entry). Use a positive [amount] for the amount they're paying down.
  Future<void> recordPayment({
    required String customerId,
    required double amount,
    String note = 'Payment received',
  }) async {
    final db = await database;
    await db.insert('ledger_entries', {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'customer_id': customerId,
      'amount': -amount,
      'note': note,
      'occurred_at': DateTime.now().toIso8601String(),
      'sync_status': 1,
    });
  }

  Future<List<LedgerEntry>> getLedgerFor(String customerId) async {
    final db = await database;
    final rows = await db.query(
      'ledger_entries',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'occurred_at DESC',
    );
    return rows.map(LedgerEntry.fromMap).toList();
  }

  // ---- Suppliers & purchase orders ----

  Future<void> upsertSupplier(Supplier s) async {
    final db = await database;
    await db.insert('suppliers', s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Supplier>> getSuppliers() async {
    final db = await database;
    final rows = await db.query('suppliers', orderBy: 'name ASC');
    return rows.map(Supplier.fromMap).toList();
  }

  /// Records a delivery: the PO header and every line always get saved.
  /// Stock only updates (branch-aware — see _adjustStock) if [po].status
  /// is `received` — a `pending` order is just tracked, not yet in
  /// hand. Call receivePurchaseOrder later to flip a pending one over.
  Future<void> insertPurchaseOrder(
    PurchaseOrder po,
    List<PurchaseOrderLine> lines,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('purchase_orders', po.toMap());
      for (final line in lines) {
        await txn.insert('purchase_order_lines', line.toMap());
        if (po.status == PurchaseOrderStatus.received) {
          await _adjustStock(txn,
              productId: line.productId,
              delta: line.quantity,
              branchId: po.branchId);
          await txn.rawUpdate(
            'UPDATE products SET cost_price = ?, sync_status = 1 WHERE id = ?',
            [line.unitCost, line.productId],
          );
        }
      }
    });
  }

  /// Flips a pending PO to received: applies the same stock/cost
  /// updates insertPurchaseOrder would have done at creation time, now
  /// that the goods have actually arrived.
  Future<void> receivePurchaseOrder(String purchaseOrderId) async {
    final db = await database;
    await db.transaction((txn) async {
      final poRows = await txn.query('purchase_orders',
          where: 'id = ?', whereArgs: [purchaseOrderId], limit: 1);
      if (poRows.isEmpty) return;
      final po = PurchaseOrder.fromMap(poRows.first);
      if (po.status == PurchaseOrderStatus.received) return; // already done

      final lineRows = await txn.query('purchase_order_lines',
          where: 'purchase_order_id = ?', whereArgs: [purchaseOrderId]);
      for (final row in lineRows) {
        final line = PurchaseOrderLine.fromMap(row);
        await _adjustStock(txn,
            productId: line.productId,
            delta: line.quantity,
            branchId: po.branchId);
        await txn.rawUpdate(
          'UPDATE products SET cost_price = ?, sync_status = 1 WHERE id = ?',
          [line.unitCost, line.productId],
        );
      }
      await txn.update(
        'purchase_orders',
        {'status': PurchaseOrderStatus.received.name, 'sync_status': 1},
        where: 'id = ?',
        whereArgs: [purchaseOrderId],
      );
    });
  }

  Future<List<PurchaseOrder>> getPurchaseOrders() async {
    final db = await database;
    final rows =
        await db.query('purchase_orders', orderBy: 'received_at DESC');
    return rows.map(PurchaseOrder.fromMap).toList();
  }

  Future<List<PurchaseOrderLine>> getPurchaseOrderLines(
      String purchaseOrderId) async {
    final db = await database;
    final rows = await db.query(
      'purchase_order_lines',
      where: 'purchase_order_id = ?',
      whereArgs: [purchaseOrderId],
    );
    return rows.map(PurchaseOrderLine.fromMap).toList();
  }

  // ---- Branches ----

  Future<void> upsertBranch(Branch b) async {
    final db = await database;
    await db.insert('branches', b.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Branch>> getBranches() async {
    final db = await database;
    final rows = await db.query('branches', orderBy: 'name ASC');
    return rows.map(Branch.fromMap).toList();
  }

  /// Rows any table still has queued for upload — used by SyncService.
  Future<List<Map<String, dynamic>>> getPendingSync(String table) async {
    final db = await database;
    return db.query(table, where: 'sync_status != 0');
  }

  Future<void> markSynced(String table, String id) async {
    final db = await database;
    await db.update(table, {'sync_status': 0},
        where: 'id = ?', whereArgs: [id]);
  }
}
