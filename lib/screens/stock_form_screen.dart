import 'package:flutter/material.dart';

import '../logic/stock_item.dart';
import '../logic/validators.dart';
import '../theme/app_theme.dart';

/// Task 1 + Task 2: stock entry form. Used for adding a new item and, with
/// [initial] set, for editing an existing one.
class StockForm extends StatefulWidget {
  const StockForm({
    super.key,
    this.initial,
    required this.existingSkus,
    required this.onSubmit,
    this.onSaved,
    this.onCancel,
  });

  final StockItem? initial;

  /// SKUs already saved in Firestore, for the duplicate check.
  final Set<String> existingSkus;

  /// Performs the Firestore write. Must complete only once it is acknowledged.
  final Future<void> Function(StockItem item) onSubmit;

  /// Called after a successful write.
  final void Function(StockItem item)? onSaved;

  /// Shown as a Cancel button when set (edit dialog).
  final VoidCallback? onCancel;

  @override
  State<StockForm> createState() => _StockFormState();
}

class _StockFormState extends State<StockForm> {
  final _formKey = GlobalKey<FormState>();
  final _categoryKey = GlobalKey<FormFieldState<String>>();
  late final _sku = TextEditingController(text: widget.initial?.sku);
  late final _name = TextEditingController(text: widget.initial?.itemName);
  late final _qty = TextEditingController(
    text: widget.initial?.quantity.toString(),
  );
  late final _price = TextEditingController(
    text: widget.initial?.unitPrice.toStringAsFixed(2),
  );
  late final _reorder = TextEditingController(
    text: widget.initial?.reorderLevel.toString(),
  );
  bool _saving = false;
  String? _error;

  bool get _editing => widget.initial != null;

  List<TextEditingController> get _controllers => [
    _sku,
    _name,
    _qty,
    _price,
    _reorder,
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _reset() {
    _formKey.currentState!.reset();
    for (final c in _controllers) {
      c.clear();
    }
    setState(() => _error = null);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    // Validation gate: nothing is written to Firestore unless every field
    // passes.
    if (!_formKey.currentState!.validate()) {
      setState(() => _error = 'Fix the highlighted fields to continue.');
      return;
    }
    final item = StockItem(
      id: widget.initial?.id,
      sku: _sku.text.trim(),
      itemName: _name.text.trim(),
      category: _categoryKey.currentState!.value!,
      quantity: int.parse(_qty.text.trim()),
      unitPrice: double.parse(_price.text.trim()),
      reorderLevel: int.parse(_reorder.text.trim()),
    );

    setState(() => _saving = true);
    try {
      await widget.onSubmit(item);
      if (!mounted) return;
      // Clear the form only after the acknowledged write.
      if (!_editing) _reset();
      widget.onSaved?.call(item);
    } catch (e) {
      // Keep the entered values so the user can retry.
      if (mounted) setState(() => _error = 'Could not save to Firestore. $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    final theme = Theme.of(context).textTheme;
    return FocusTraversalGroup(
      // Tab follows the order the fields are declared in.
      policy: WidgetOrderTraversalPolicy(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editing ? 'Edit item' : 'New item',
              style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              _editing
                  ? 'Update the details and save.'
                  : 'All fields are required.',
              style: theme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const Key('skuField'),
              controller: _sku,
              style: monoStyle(size: 14),
              decoration: const InputDecoration(
                labelText: 'SKU',
                hintText: 'STK-101',
              ),
              validator: (v) =>
                  StockValidators.sku(v) ??
                  StockValidators.uniqueSku(
                    v,
                    widget.existingSkus,
                    except: widget.initial?.sku,
                  ),
            ),
            gap,
            TextFormField(
              key: const Key('nameField'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Item name'),
              validator: StockValidators.itemName,
            ),
            gap,
            DropdownButtonFormField<String>(
              key: _categoryKey,
              initialValue: widget.initial?.category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in kCategories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (_) {},
              validator: StockValidators.category,
            ),
            gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('qtyField'),
                    controller: _qty,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
                    validator: StockValidators.quantity,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('reorderField'),
                    controller: _reorder,
                    decoration: const InputDecoration(
                      labelText: 'Reorder level',
                    ),
                    keyboardType: TextInputType.number,
                    validator: StockValidators.reorderLevel,
                  ),
                ),
              ],
            ),
            gap,
            TextFormField(
              key: const Key('priceField'),
              controller: _price,
              decoration: const InputDecoration(
                labelText: 'Unit price',
                prefixText: 'RM ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: StockValidators.unitPrice,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            _ValuePreview(qty: _qty, price: _price, reorder: _reorder),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('formError'),
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (widget.onCancel != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : widget.onCancel,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    key: const Key('saveButton'),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text('Saving...'),
                            ],
                          )
                        : Text(_editing ? 'Save changes' : 'Save Item'),
                  ),
                ),
              ],
            ),
            if (!_editing) ...[
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _reset,
                  style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                  child: const Text('Reset form'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows stock value, and whether the item will count as low stock, while
/// the user types.
class _ValuePreview extends StatelessWidget {
  const _ValuePreview({
    required this.qty,
    required this.price,
    required this.reorder,
  });

  final TextEditingController qty, price, reorder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([qty, price, reorder]),
      builder: (context, _) {
        final q = int.tryParse(qty.text.trim());
        final p = double.tryParse(price.text.trim());
        final r = int.tryParse(reorder.text.trim());
        if (q == null || p == null || q < 0 || p <= 0) {
          return const SizedBox.shrink();
        }
        final low = r != null && r >= 0 && q <= r;
        return Text(
          'Stock value RM ${(q * p).toStringAsFixed(2)}'
          '${low ? ' · will be marked low stock' : ''}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
        );
      },
    );
  }
}
