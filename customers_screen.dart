import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../models/ledger_entry.dart';
import '../services/database_service.dart';
import '../theme.dart';

const _uuid = Uuid();

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _etb = NumberFormat.currency(symbol: 'ETB ', decimalDigits: 0);
  bool _loading = true;
  List<Customer> _customers = [];
  Map<String, double> _balances = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseService.instance;
    final customers = await db.getCustomers();
    final balances = <String, double>{};
    for (final c in customers) {
      balances[c.id] = await db.getCustomerBalance(c.id);
    }
    if (!mounted) return;
    setState(() {
      _customers = customers;
      _balances = balances;
      _loading = false;
    });
  }

  double get _totalReceivable =>
      _balances.values.fold(0.0, (sum, b) => sum + (b > 0 ? b : 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ደንበኞች (Customers)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ጠቅላላ የሚያስከፍል (Receivable)',
                              style: TextStyle(color: AppColors.textSecondary)),
                          Text(
                            _etb.format(_totalReceivable),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.danger),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_customers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.lg),
                      child: Text(
                        'ገና ደንበኛ የለም — ከታች + ተጭነው ይጀምሩ።',
                        style: TextStyle(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ..._customers.map((c) => _CustomerTile(
                          customer: c,
                          balance: _balances[c.id] ?? 0,
                          etb: _etb,
                          onTap: () => _openLedger(c),
                        )),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCustomer,
        child: const Icon(Icons.person_add_alt),
      ),
    );
  }

  Future<void> _addCustomer() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '0');
    var tier = PriceTier.wholesale;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('ደንበኛ ጨምር'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'ስም'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'ያስፈልጋል' : null,
                  ),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'ስልክ (optional)'),
                    keyboardType: TextInputType.phone,
                  ),
                  DropdownButtonFormField<PriceTier>(
                    initialValue: tier,
                    decoration: const InputDecoration(labelText: 'የዋጋ አይነት'),
                    items: const [
                      DropdownMenuItem(
                          value: PriceTier.wholesale, child: Text('ጅምላ (Wholesale)')),
                      DropdownMenuItem(
                          value: PriceTier.retail, child: Text('ችርቻሮ (Retail)')),
                    ],
                    onChanged: (v) => setState(() => tier = v!),
                  ),
                  TextFormField(
                    controller: limitCtrl,
                    decoration:
                        const InputDecoration(labelText: 'የዱቤ ገደብ (ETB, 0 = ዱቤ የለም)'),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        double.tryParse(v ?? '') == null ? 'ቁጥር ያስገቡ' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ይቅር'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                await DatabaseService.instance.upsertCustomer(Customer(
                  id: _uuid.v4(),
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  priceTier: tier,
                  creditLimit: double.parse(limitCtrl.text),
                  updatedAt: DateTime.now(),
                ));
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('አስቀምጥ'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _openLedger(Customer c) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => CustomerLedgerScreen(customer: c)),
    );
    if (changed == true) _load();
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final double balance;
  final NumberFormat etb;
  final VoidCallback onTap;

  const _CustomerTile({
    required this.customer,
    required this.balance,
    required this.etb,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final owesMoney = balance > 0;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: onTap,
        title: Text(customer.name),
        subtitle: Text(customer.priceTier == PriceTier.wholesale
            ? 'ጅምላ ደንበኛ'
            : 'ችርቻሮ ደንበኛ'),
        trailing: Text(
          owesMoney ? etb.format(balance) : 'ተከፍሏል',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: owesMoney ? AppColors.danger : AppColors.success,
          ),
        ),
      ),
    );
  }
}

class CustomerLedgerScreen extends StatefulWidget {
  final Customer customer;
  const CustomerLedgerScreen({super.key, required this.customer});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  final _etb = NumberFormat.currency(symbol: 'ETB ', decimalDigits: 0);
  bool _loading = true;
  List<LedgerEntry> _entries = [];
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseService.instance;
    final entries = await db.getLedgerFor(widget.customer.id);
    final balance = await db.getCustomerBalance(widget.customer.id);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _balance = balance;
      _loading = false;
    });
  }

  Future<void> _recordPayment() async {
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ክፍያ መዝግብ'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: amountCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'የተከፈለ መጠን (ETB)'),
            keyboardType: TextInputType.number,
            validator: (v) {
              final n = double.tryParse(v ?? '');
              if (n == null || n <= 0) return 'ትክክለኛ መጠን ያስገቡ';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ይቅር'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await DatabaseService.instance.recordPayment(
                customerId: widget.customer.id,
                amount: double.parse(amountCtrl.text),
              );
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('አስቀምጥ'),
          ),
        ],
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.customer.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  color: AppColors.surface,
                  child: Column(
                    children: [
                      const Text('የአሁኑ ዕዳ',
                          style: TextStyle(color: AppColors.textSecondary)),
                      Text(
                        _etb.format(_balance),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color:
                              _balance > 0 ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _entries.isEmpty
                      ? const Center(
                          child: Text('ገና ግብይት የለም',
                              style: TextStyle(color: AppColors.textSecondary)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: _entries.length,
                          itemBuilder: (context, i) {
                            final e = _entries[i];
                            final isCredit = e.amount > 0;
                            return ListTile(
                              leading: Icon(
                                isCredit
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                color: isCredit
                                    ? AppColors.danger
                                    : AppColors.success,
                              ),
                              title: Text(e.note),
                              subtitle: Text(
                                  '${e.occurredAt.year}-${e.occurredAt.month.toString().padLeft(2, '0')}-${e.occurredAt.day.toString().padLeft(2, '0')}'),
                              trailing: Text(
                                _etb.format(e.amount.abs()),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isCredit
                                      ? AppColors.danger
                                      : AppColors.success,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _recordPayment,
        icon: const Icon(Icons.payments_outlined),
        label: const Text('ክፍያ መዝግብ'),
      ),
    );
  }
}
