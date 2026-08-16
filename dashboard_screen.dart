import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/branch.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/subscription.dart';
import '../services/auth_service.dart';
import '../services/branch_prefs.dart';
import '../services/database_service.dart';
import '../services/permissions.dart';
import '../services/supabase_service.dart';
import '../services/team_service.dart';
import '../theme.dart';
import '../widgets/premium_gate.dart';
import '../widgets/quick_actions.dart';
import '../widgets/stat_card.dart';
import '../widgets/weekly_sales_bars.dart';
import 'customers_screen.dart';
import 'purchase_orders_screen.dart';
import 'team_screen.dart';

const _uuid = Uuid();

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _etb = NumberFormat.currency(symbol: 'ETB ', decimalDigits: 0);
  int _selectedTab = 0; // 0 = Sales Trend, 1 = Profit Analysis, 2 = Inventory

  bool _loading = true;
  List<Sale> _todaySales = [];
  List<Sale> _weekSales = [];
  List<Product> _products = [];
  List<Customer> _customers = [];
  List<Branch> _branches = [];
  String? _currentBranchId;
  String? _currentBranchName;
  SubscriptionStatus _subStatus = SubscriptionStatus.freeDefault();
  Permissions _perms = const Permissions(TeamRole.owner);
  Map<String, int> _branchStock = {}; // productId -> qty at current branch, empty if "All branches"

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseService.instance;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final (currentBranchId, currentBranchName) = await BranchPrefs.getCurrent();
    final role = await TeamService.instance.getCachedRole();

    final today = await db.getSalesBetween(startOfToday, now,
        branchId: currentBranchId);
    final week = await db.getSalesBetween(startOfWeek, now,
        branchId: currentBranchId);
    final products = await db.getProducts();
    final customers = await db.getCustomers();
    final branches = await db.getBranches();
    final subStatus = await SupabaseService.instance.getCachedStatus();
    final branchStock = currentBranchId == null
        ? <String, int>{}
        : await db.getBranchStockMap(currentBranchId);

    if (!mounted) return;
    setState(() {
      _todaySales = today;
      _weekSales = week;
      _products = products;
      _customers = customers;
      _branches = branches;
      _currentBranchId = currentBranchId;
      _currentBranchName = currentBranchName;
      _subStatus = subStatus;
      _perms = Permissions(role);
      _branchStock = branchStock;
      _loading = false;
    });
  }

  /// Stock for a product as it should currently be displayed: the
  /// branch-specific count if a branch is selected AND that product has
  /// been sold/received there before, otherwise the running total
  /// across all branches (Product.stockQty — see _adjustStock).
  int _stockFor(Product p) => _currentBranchId != null && _branchStock.containsKey(p.id)
      ? _branchStock[p.id]!
      : p.stockQty;

  double get _todayRevenue =>
      _todaySales.fold(0.0, (sum, s) => sum + s.revenue);
  double get _todayProfit =>
      _todaySales.fold(0.0, (sum, s) => sum + s.profit);
  int get _todayItemsSold =>
      _todaySales.fold(0, (sum, s) => sum + s.quantity);
  List<Product> get _lowStock =>
      _products.where((p) => _stockFor(p) <= p.lowStockThreshold).toList();

  List<DayValue> get _weeklyBars {
    final byDay = <int, double>{};
    for (final s in _weekSales) {
      byDay[s.soldAt.weekday] = (byDay[s.soldAt.weekday] ?? 0.0) + s.revenue;
    }
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List.generate(
      7,
      (i) => DayValue(labels[i], byDay[i + 1] ?? 0),
    );
  }

  /// Best sellers this week, revenue and profit rolled up by product.
  List<MapEntry<String, ({int sold, double profit})>> get _topSelling {
    final rollup = <String, ({int sold, double profit})>{};
    for (final s in _weekSales) {
      final prev = rollup[s.productName] ?? (sold: 0, profit: 0.0);
      rollup[s.productName] =
          (sold: prev.sold + s.quantity, profit: prev.profit + s.profit);
    }
    final sorted = rollup.entries.toList()
      ..sort((a, b) => b.value.sold.compareTo(a.value.sold));
    return sorted.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _buildBranchSwitcher(),
            const SizedBox(height: AppSpacing.sm),
            _buildPlanBadge(),
            const SizedBox(height: AppSpacing.sm),
            _buildStatGrid(),
            const SizedBox(height: AppSpacing.md),
            _buildTabBar(),
            const SizedBox(height: AppSpacing.md),
            _buildTabContent(),
            const SizedBox(height: 80), // room for the FAB
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildBranchSwitcher() {
    return InkWell(
      onTap: _pickBranch,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              _currentBranchName ?? 'ሁሉም ቅርንጫፎች (All branches)',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const Icon(Icons.expand_more, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBranch() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.all_inclusive),
            title: const Text('ሁሉም ቅርንጫፎች (All branches)'),
            selected: _currentBranchId == null,
            onTap: () => Navigator.pop(context, '__all__'),
          ),
          ..._branches.map((b) => ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(b.name),
                selected: _currentBranchId == b.id,
                onTap: () => Navigator.pop(context, b.id),
              )),
          if (_perms.canManageBranches) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('አዲስ ቅርንጫፍ ጨምር'),
              onTap: () => Navigator.pop(context, '__new__'),
            ),
          ],
        ]),
      ),
    );
    if (choice == null) return;

    if (choice == '__all__') {
      await BranchPrefs.setCurrent(null, null);
      _load();
      return;
    }
    if (choice == '__new__') {
      await _addBranch();
      return;
    }
    final branch = _branches.firstWhere((b) => b.id == choice);
    await BranchPrefs.setCurrent(branch.id, branch.name);
    _load();
  }

  Future<void> _addBranch() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('አዲስ ቅርንጫፍ'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'የቅርንጫፍ ስም'),
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
    final branch =
        Branch(id: _uuid.v4(), name: name, updatedAt: DateTime.now());
    await DatabaseService.instance.upsertBranch(branch);
    await BranchPrefs.setCurrent(branch.id, branch.name);
    _load();
  }

  Future<void> _showUpgradeInfo() async {
    final profile = await AuthService.instance.getProfile();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium ማድረግ'),
        content: Text(
          'Telebirr ወይም ባንክ በኩል ይክፈሉ፣ ከዚያ ስልክ ቁጥርዎን (${profile?.phone ?? ''}) '
          'ለአስተዳዳሪው ይላኩ። ደረሰኝ ከተረጋገጠ በኋላ Premium በራስ-ሰር ይነቃል '
          '(ቀጣይ ጊዜ ኢንተርኔት ሲኖር)።',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ገባኝ'),
          ),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: () async {
        final action = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => SafeArea(
            child: Wrap(children: [
              if (_perms.canManageProducts)
                ListTile(
                  leading: const Icon(Icons.add_box_outlined),
                  title: const Text('Add Product'),
                  onTap: () => Navigator.pop(context, 'product'),
                ),
              if (_perms.canRecordSales)
                ListTile(
                  leading: const Icon(Icons.point_of_sale_outlined),
                  title: const Text('Record Sale'),
                  onTap: () => Navigator.pop(context, 'sale'),
                ),
              if (_perms.canManageCustomers)
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('Customers (ደንበኞች)'),
                  onTap: () => Navigator.pop(context, 'customers'),
                ),
              if (_perms.canViewPurchaseOrders)
                ListTile(
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: const Text('Purchase Orders (ግዢዎች)'),
                  onTap: () => Navigator.pop(context, 'purchases'),
                ),
              if (_perms.canManageTeam)
                ListTile(
                  leading: const Icon(Icons.people_alt_outlined),
                  title: const Text('Team (ቡድን)'),
                  onTap: () => Navigator.pop(context, 'team'),
                ),
            ]),
          ),
        );
        if (!mounted || action == null) return;
        if (action == 'team') {
          await Navigator.push(context,
              MaterialPageRoute(builder: (context) => const TeamScreen()));
          return;
        }
        if (action == 'customers') {
          await Navigator.push(context,
              MaterialPageRoute(builder: (context) => const CustomersScreen()));
          _load();
          return;
        }
        if (action == 'purchases') {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => PurchaseOrdersScreen(
                        branchId: _currentBranchId,
                        branchName: _currentBranchName,
                      )));
          _load();
          return;
        }
        final changed = action == 'product'
            ? await showAddProductDialog(
                context,
                currentProductCount: _products.length,
                subStatus: _subStatus,
              )
            : await showRecordSaleDialog(
                context,
                _products,
                customers: _customers,
                branchId: _currentBranchId,
                branchName: _currentBranchName,
              );
        if (changed == true) _load();
      },
      icon: const Icon(Icons.add),
      label: const Text('Add'),
    );
  }

  Widget _buildPlanBadge() {
    final isPremium = _subStatus.isPremiumActive;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _perms.roleLabel(),
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isPremium
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.textSecondary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isPremium ? '⭐ Premium' : 'Free Plan',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isPremium ? AppColors.success : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.5,
      children: [
        StatCard(
          label: "Today's Sales",
          value: _etb.format(_todayRevenue),
          accentColor: AppColors.success,
          changeText: '${_todaySales.length} transactions today',
        ),
        StatCard(
          label: 'Net Profit',
          value: _etb.format(_todayProfit),
          accentColor: AppColors.info,
          changeText: _todayRevenue > 0
              ? '${(_todayProfit / _todayRevenue * 100).toStringAsFixed(0)}% margin'
              : '—',
        ),
        StatCard(
          label: 'Items Sold',
          value: '$_todayItemsSold',
          accentColor: AppColors.warning,
          changeText: 'today',
        ),
        StatCard(
          label: 'Low Stock',
          value: '${_lowStock.length} Items',
          accentColor: AppColors.danger,
          warningIcon: Icons.warning_amber_rounded,
          changeText: _lowStock.isEmpty ? 'All good' : 'Restock needed',
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    final tabs = ['Sales Trend', 'Profit Analysis', 'Inventory'];
    return Row(
      children: List.generate(tabs.length, (i) {
        final selected = _selectedTab == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedTab = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.tabActiveBg : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                tabs[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _card(
          title: '📈 Weekly Sales (ETB)',
          child: WeeklySalesBars(data: _weeklyBars),
        );
      case 1:
        return _card(
          title: '🏆 Top Selling Items',
          child: !_perms.canViewProfitAnalysis
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'ይህ ለእርስዎ ሚና አይታይም (Owner/Accountant ብቻ)',
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                )
              : PremiumGate(
                  status: _subStatus,
                  featureName: 'Profit Analysis',
                  onUpgradeTap: _showUpgradeInfo,
                  child: _topSelling.isEmpty
                      ? const Text('No sales yet this week.',
                          style: TextStyle(color: AppColors.textSecondary))
                      : _buildItemTable(),
                ),
        );
      case 2:
      default:
        return _card(
          title: '📦 Inventory',
          child: _buildInventoryList(),
        );
    }
  }

  Widget _buildItemTable() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1.5),
      },
      children: [
        const TableRow(children: [
          _TableHeader('Item'),
          _TableHeader('Sold'),
          _TableHeader('Profit'),
        ]),
        ..._topSelling.map((e) => TableRow(children: [
              _TableCell(e.key),
              _TableCell('${e.value.sold}'),
              _TableCell(_etb.format(e.value.profit)),
            ])),
      ],
    );
  }

  Widget _buildInventoryList() {
    if (_products.isEmpty) {
      return const Text('No products yet — add your first item to get started.',
          style: TextStyle(color: AppColors.textSecondary));
    }
    return Column(
      children: [
        if (_currentBranchId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              '$_currentBranchName ላይ ያለ ስቶክ ("0 items here" ማለት እዚህ '
              'ገና ስቶክ አልመዘገቡም ማለት ሊሆን ይችላል)',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ..._products.map((p) {
          final qty = _stockFor(p);
          final low = qty <= p.lowStockThreshold;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(p.name,
                      style: const TextStyle(color: AppColors.textPrimary)),
                ),
                Text(
                  '$qty in stock',
                  style: TextStyle(
                    color: low ? AppColors.danger : AppColors.textSecondary,
                    fontWeight: low ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
      );
}

class _TableCell extends StatelessWidget {
  final String text;
  const _TableCell(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: const TextStyle(color: AppColors.textPrimary)),
      );
}
