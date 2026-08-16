import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/subscription.dart';
import '../services/database_service.dart';
import '../theme.dart';

const _uuid = Uuid();

/// Small form dialog to register a new stock item. Free tier is capped at
/// [freeTierProductLimit] — pass the merchant's current count and plan
/// status so we can nudge toward upgrading instead of silently blocking.
Future<bool?> showAddProductDialog(
  BuildContext context, {
  required int currentProductCount,
  required SubscriptionStatus subStatus,
}) {
  if (!subStatus.isPremiumActive && currentProductCount >= freeTierProductLimit) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('የFree Plan ገደብ ላይ ደርሰዋል'),
        content: Text(
          'Free Plan እስከ $freeTierProductLimit ምርት ብቻ ይፈቅዳል። ተጨማሪ ምርት '
          'ለመመዝገብ Premium ማድረግ ያስፈልጋል።',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ዝጋ'),
          ),
        ],
      ),
    );
  }

  final nameCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  final sellCtrl = TextEditingController();
  final wholesaleCtrl = TextEditingController();
  final stockCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add Product'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Product name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: costCtrl,
                decoration: const InputDecoration(labelText: 'Cost price (ETB)'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    double.tryParse(v ?? '') == null ? 'Enter a number' : null,
              ),
              TextFormField(
                controller: sellCtrl,
                decoration: const InputDecoration(labelText: 'Retail price (ETB)'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    double.tryParse(v ?? '') == null ? 'Enter a number' : null,
              ),
              TextFormField(
                controller: wholesaleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Wholesale price (ETB, optional)'),
                keyboardType: TextInputType.number,
                validator: (v) => (v != null && v.isNotEmpty && double.tryParse(v) == null)
                    ? 'Enter a number'
                    : null,
              ),
              TextFormField(
                controller: stockCtrl,
                decoration: const InputDecoration(labelText: 'Starting stock qty'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    int.tryParse(v ?? '') == null ? 'Enter a whole number' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            final product = Product(
              id: _uuid.v4(),
              name: nameCtrl.text.trim(),
              costPrice: double.parse(costCtrl.text),
              sellPrice: double.parse(sellCtrl.text),
              wholesalePrice: wholesaleCtrl.text.trim().isEmpty
                  ? null
                  : double.parse(wholesaleCtrl.text),
              stockQty: int.parse(stockCtrl.text),
              updatedAt: DateTime.now(),
            );
            await DatabaseService.instance.upsertProduct(product);
            if (context.mounted) Navigator.pop(context, true);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// Small form dialog to record a sale against an existing product.
/// Picking a wholesale customer auto-switches the unit price to that
/// product's wholesale price; unchecking "paid in full" queues a
/// LedgerEntry via DatabaseService.insertSale.
Future<bool?> showRecordSaleDialog(
  BuildContext context,
  List<Product> products, {
  List<Customer> customers = const [],
  String? branchId,
  String? branchName,
}) {
  if (products.isEmpty) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No products yet'),
        content: const Text('Add a product first, then record sales against it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Product selectedProduct = products.first;
  Customer? selectedCustomer; // null = walk-in / retail
  bool paidInFull = true;
  final qtyCtrl = TextEditingController(text: '1');
  final formKey = GlobalKey<FormState>();

  double unitPrice() => selectedCustomer?.priceTier == PriceTier.wholesale
      ? selectedProduct.effectiveWholesalePrice
      : selectedProduct.sellPrice;

  return showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Record Sale'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Product>(
                  initialValue: selectedProduct,
                  items: products
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                      .toList(),
                  onChanged: (p) => setState(() => selectedProduct = p!),
                  decoration: const InputDecoration(labelText: 'Product'),
                ),
                TextFormField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(labelText: 'Quantity sold'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Enter a valid quantity';
                    if (n > selectedProduct.stockQty) {
                      return 'Only ${selectedProduct.stockQty} in stock';
                    }
                    return null;
                  },
                ),
                if (customers.isNotEmpty) ...[
                  DropdownButtonFormField<Customer?>(
                    initialValue: selectedCustomer,
                    decoration:
                        const InputDecoration(labelText: 'Customer (optional)'),
                    items: [
                      const DropdownMenuItem<Customer?>(
                          value: null, child: Text('Walk-in / Retail')),
                      ...customers.map((c) =>
                          DropdownMenuItem(value: c, child: Text(c.name))),
                    ],
                    onChanged: (c) => setState(() => selectedCustomer = c),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Unit price: ${unitPrice().toStringAsFixed(0)} ETB'
                      '${selectedCustomer?.priceTier == PriceTier.wholesale ? ' (wholesale)' : ''}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  if (selectedCustomer != null)
                    CheckboxListTile(
                      value: paidInFull,
                      onChanged: (v) => setState(() => paidInFull = v!),
                      title: const Text('Paid in full now'),
                      subtitle: paidInFull
                          ? null
                          : const Text('Adds this sale to their credit balance'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final sale = Sale(
                id: _uuid.v4(),
                productId: selectedProduct.id,
                productName: selectedProduct.name,
                quantity: int.parse(qtyCtrl.text),
                unitSellPrice: unitPrice(),
                unitCostPrice: selectedProduct.costPrice,
                soldAt: DateTime.now(),
                customerId: selectedCustomer?.id,
                customerName: selectedCustomer?.name,
                isPaidInFull: selectedCustomer == null ? true : paidInFull,
                branchId: branchId,
                branchName: branchName,
              );
              await DatabaseService.instance.insertSale(sale);
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
