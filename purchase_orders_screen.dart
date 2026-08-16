import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/purchase_order.dart';
import '../models/supplier.dart';
import '../services/database_service.dart';
import '../services/permissions.dart';
import '../services/team_service.dart';
import '../theme.dart';

const _uuid = Uuid();

class PurchaseOrdersScreen extends StatefulWidget {
  final String? branchId;
  final String? branchName;
  const PurchaseOrdersScreen({super.key, this.branchId, this.branchName});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final _etb = NumberFormat.currency(symbol: 'ETB ', decimalDigits: 0);
  bool _loading = true;
  List<PurchaseOrder> _orders = [];
  Map<String, List<PurchaseOrderLine>> _linesByOrder = {};
  List<Product> _products = [];
  Permissions _perms = const Permissions(TeamRole.owner);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseService.instance;
    final orders = await db.getPurchaseOrders();
    final linesByOrder = <String, List<PurchaseOrderLine>>{};
    for (final o in orders) {
      linesByOrder[o.id] = await db.getPurchaseOrderLines(o.id);
    }
    final products = await db.getProducts();
    final role = await TeamService.instance.getCachedRole();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _linesByOrder = linesByOrder;
      _products = products;
      _perms = Permissions(role);
      _loading = false;
    });
  }

  Future<void> _confirmReceive(PurchaseOrder o) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('እንደደረሰ ምልክት ማድረግ?'),
        content: Text(
            '${o.supplierName ?? "ይህ ግዢ"} ደርሷል ብለው ካረጋገጡ ስቶክ ራስ-ሰር ይጨምራል።'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ይቅር'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ደርሷል'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseService.instance.receivePurchaseOrder(o.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ግዢዎች (Purchase Orders)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'ገና ግዢ አልተመዘገበም — ከታች + ተጭነው ይጀምሩ።',
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _orders.length,
                    itemBuilder: (context, i) {
                      final o = _orders[i];
                      final lines = _linesByOrder[o.id] ?? [];
                      final total =
                          lines.fold(0.0, (sum, l) => sum + l.lineTotal);
                      final isPending =
                          o.status == PurchaseOrderStatus.pending;
                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          title: Text(o.supplierName ?? 'ያለ አቅራቢ'),
                          subtitle: Text(
                              '${lines.length} ዓይነት ምርት • ${o.receivedAt.year}-${o.receivedAt.month.toString().padLeft(2, '0')}-${o.receivedAt.day.toString().padLeft(2, '0')}'),
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isPending
                                      ? AppColors.warning
                                      : AppColors.success)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isPending ? 'በመጠባበቅ' : 'ደርሷል',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isPending
                                    ? AppColors.warning
                                    : AppColors.success,
                              ),
                            ),
                          ),
                          trailing: Text(
                            _etb.format(total),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                          onTap: isPending && _perms.canManagePurchaseOrders
                              ? () => _confirmReceive(o)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: _perms.canManagePurchaseOrders
          ? FloatingActionButton.extended(
              onPressed: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecordPurchaseScreen(
                      products: _products,
                      branchId: widget.branchId,
                      branchName: widget.branchName,
                    ),
                  ),
                );
                if (saved == true) _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('ግዢ መዝግብ'),
            )
          : null,
    );
  }
}

class _PurchaseLine {
  Product? product;
  final qtyCtrl = TextEditingController(text: '1');
  final costCtrl = TextEditingController();
}

class RecordPurchaseScreen extends StatefulWidget {
  final List<Product> products;
  final String? branchId;
  final String? branchName;
  const RecordPurchaseScreen({
    super.key,
    required this.products,
    this.branchId,
    this.branchName,
  });

  @override
  State<RecordPurchaseScreen> createState() => _RecordPurchaseScreenState();
}

class _RecordPurchaseScreenState extends State<RecordPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;
  final List<_PurchaseLine> _lines = [_PurchaseLine()];
  PurchaseOrderStatus _status = PurchaseOrderStatus.received;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.products.isNotEmpty) _lines.first.product = widget.products.first;
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    final suppliers = await DatabaseService.instance.getSuppliers();
    if (!mounted) return;
    setState(() => _suppliers = suppliers);
  }

  Future<void> _addNewSupplier() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('አዲስ አቅራቢ'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'የአቅራቢ ስም'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ይቅር'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameCtrl.text.trim()),
            child: const Text('ጨምር'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final supplier =
        Supplier(id: _uuid.v4(), name: name, updatedAt: DateTime.now());
    await DatabaseService.instance.upsertSupplier(supplier);
    setState(() {
      _suppliers = [..._suppliers, supplier];
      _selectedSupplier = supplier;
    });
  }

  double get _total {
    var sum = 0.0;
    for (final line in _lines) {
      final qty = int.tryParse(line.qtyCtrl.text) ?? 0;
      final cost = double.tryParse(line.costCtrl.text) ?? 0;
      sum += qty * cost;
    }
    return sum;
  }

  Future<void> _save() async {
    if (widget.products.isEmpty) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final po = PurchaseOrder(
      id: _uuid.v4(),
      supplierId: _selectedSupplier?.id,
      supplierName: _selectedSupplier?.name,
      receivedAt: DateTime.now(),
      branchId: widget.branchId,
      branchName: widget.branchName,
      status: _status,
    );
    final poLines = _lines
        .where((l) => l.product != null)
        .map((l) => PurchaseOrderLine(
              id: _uuid.v4(),
              purchaseOrderId: po.id,
              productId: l.product!.id,
              productName: l.product!.name,
              quantity: int.parse(l.qtyCtrl.text),
              unitCost: double.parse(l.costCtrl.text),
            ))
        .toList();

    await DatabaseService.instance.insertPurchaseOrder(po, poLines);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('ግዢ መዝግብ')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text('መጀመሪያ ቢያንስ አንድ ምርት ይመዝግቡ።',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('ግዢ መዝግብ')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            DropdownButtonFormField<Supplier?>(
              initialValue: _selectedSupplier,
              decoration: const InputDecoration(labelText: 'አቅራቢ (optional)'),
              items: [
                const DropdownMenuItem<Supplier?>(
                    value: null, child: Text('ያለ አቅራቢ')),
                ..._suppliers
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name))),
              ],
              onChanged: (s) => setState(() => _selectedSupplier = s),
            ),
            TextButton.icon(
              onPressed: _addNewSupplier,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('አዲስ አቅራቢ ጨምር'),
            ),
            const Divider(height: AppSpacing.lg),
            ...List.generate(_lines.length, (i) => _buildLine(i)),
            TextButton.icon(
              onPressed: () => setState(() => _lines.add(_PurchaseLine()
                ..product =
                    widget.products.isNotEmpty ? widget.products.first : null)),
              icon: const Icon(Icons.add),
              label: const Text('ሌላ ምርት ጨምር'),
            ),
            const Divider(height: AppSpacing.lg),
            SegmentedButton<PurchaseOrderStatus>(
              segments: const [
                ButtonSegment(
                  value: PurchaseOrderStatus.received,
                  label: Text('አሁን ደርሷል'),
                  icon: Icon(Icons.inventory_2_outlined),
                ),
                ButtonSegment(
                  value: PurchaseOrderStatus.pending,
                  label: Text('በመንገድ ላይ'),
                  icon: Icon(Icons.local_shipping_outlined),
                ),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.first),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _status == PurchaseOrderStatus.received
                  ? 'ስቶክ አሁኑኑ ይጨምራል'
                  : 'ስቶክ አይጨምርም — ደረሰ ብለው እስከሚያረጋግጡ ድረስ',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ጠቅላላ ድምር',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  NumberFormat.currency(symbol: 'ETB ', decimalDigits: 0)
                      .format(_total),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _saving ? null : _save,
              style:
                  FilledButton.styleFrom(padding: const EdgeInsets.all(14)),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('ግዢ አስቀምጥ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLine(int index) {
    final line = _lines[index];
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<Product>(
                initialValue: line.product,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'ምርት'),
                items: widget.products
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: (p) => setState(() => line.product = p),
                validator: (v) => v == null ? 'ይምረጡ' : null,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: line.qtyCtrl,
                decoration: const InputDecoration(labelText: 'ብዛት'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    (int.tryParse(v ?? '') ?? 0) <= 0 ? 'ቁጥር' : null,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: line.costCtrl,
                decoration: const InputDecoration(labelText: 'ዋጋ/ፍሬ'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    double.tryParse(v ?? '') == null ? 'ቁጥር' : null,
              ),
            ),
            if (_lines.length > 1)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _lines.removeAt(index)),
              ),
          ],
        ),
      ),
    );
  }
}
