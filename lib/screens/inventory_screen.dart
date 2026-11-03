import 'package:flutter/material.dart';

import '../logic/inventory_filter.dart';
import '../logic/inventory_repository.dart';
import '../logic/stock_item.dart';
import '../theme/app_theme.dart';
import 'stock_form_screen.dart';

/// Task 2 retrieval + Task 3 advanced search over Firestore data.
/// [items] is null while the first snapshot is loading.
class InventoryPanel extends StatefulWidget {
  const InventoryPanel({
    super.key,
    required this.repository,
    required this.items,
    required this.error,
    required this.filter,
    required this.onFilterChanged,
    required this.onRetry,
    this.scrollable = true,
  });

  final InventoryRepository repository;
  final List<StockItem>? items;
  final Object? error;
  final InventoryFilter filter;
  final ValueChanged<InventoryFilter> onFilterChanged;
  final VoidCallback onRetry;

  /// When false the list takes its natural height so the whole page can
  /// scroll (phone and tablet layout).
  final bool scrollable;

  @override
  State<InventoryPanel> createState() => _InventoryPanelState();
}

class _InventoryPanelState extends State<InventoryPanel> {
  // Seeded from the filter so the text survives a wide/narrow layout switch.
  late final _search = TextEditingController(text: widget.filter.keyword);
  final Set<String> _busyIds = {};
  // Bumped on Clear Filters so the dropdowns rebuild with default values.
  int _resetCount = 0;

  InventoryFilter get _filter => widget.filter;

  @override
  void didUpdateWidget(covariant InventoryPanel old) {
    super.didUpdateWidget(old);
    // Keep the text box in sync when filters change from elsewhere.
    if (_search.text != _filter.keyword) _search.text = _filter.keyword;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(InventoryFilter f) => widget.onFilterChanged(f);

  void _clear() {
    _search.clear();
    setState(() => _resetCount++);
    _set(const InventoryFilter());
  }

  void _snack(String msg, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), action: action));
  }

  /// Runs a Firestore write for one row, showing a spinner on that row.
  /// Returns false (after showing the error) if the write failed.
  Future<bool> _run(StockItem item, Future<void> Function() op) async {
    setState(() => _busyIds.add(item.id!));
    try {
      await op();
      return true;
    } catch (e) {
      if (mounted) _snack('Firestore error: $e');
      return false;
    } finally {
      if (mounted) setState(() => _busyIds.remove(item.id));
    }
  }

  Future<void> _edit(StockItem item) async {
    final skus = {...?widget.items?.map((i) => i.sku)};
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: StockForm(
              initial: item,
              existingSkus: skus,
              onSubmit: (updated) =>
                  widget.repository.update(item.id!, updated),
              onCancel: () => Navigator.of(ctx).pop(),
              onSaved: (updated) {
                Navigator.of(ctx).pop();
                _snack('${updated.sku} updated');
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(StockItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete ${item.sku}?',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          '${item.itemName} will be removed from the inventory. You can undo this right after.',
          style: const TextStyle(color: AppColors.muted),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final deleted = await _run(item, () => widget.repository.delete(item.id!));
    if (!deleted || !mounted) return;
    _snack(
      '${item.sku} deleted',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => widget.repository.restore(item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: _buildControls(),
          ),
          const Divider(),
          widget.scrollable ? Expanded(child: _buildBody()) : _buildBody(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final count = widget.items == null
        ? ''
        : '${_filter.apply(widget.items!).length} of ${widget.items!.length}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Inventory',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 10),
            Text(
              count,
              key: const Key('resultCount'),
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const Spacer(),
            if (_filter.isActive)
              TextButton(
                key: const Key('clearFilters'),
                onPressed: _clear,
                child: const Text('Clear filters'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final search = TextField(
              key: const Key('searchField'),
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search name or SKU',
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.muted,
                ),
                suffixIcon: _filter.keyword.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _search.clear();
                          _set(_filter.copyWith(keyword: ''));
                        },
                      ),
              ),
              onChanged: (v) => _set(_filter.copyWith(keyword: v)),
            );
            final category = DropdownButtonFormField<String>(
              key: ValueKey('categoryFilter$_resetCount'),
              initialValue: _filter.category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in ['All', ...kCategories])
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => _set(_filter.copyWith(category: v ?? 'All')),
            );
            final sort = DropdownButtonFormField<SortOption>(
              key: ValueKey('sortField$_resetCount'),
              initialValue: _filter.sort,
              decoration: const InputDecoration(labelText: 'Sort by'),
              items: [
                for (final s in SortOption.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) =>
                  _set(_filter.copyWith(sort: v ?? SortOption.newest)),
            );
            final lowStock = FilterChip(
              key: const Key('lowStockChip'),
              label: const Text('Low stock only'),
              selected: _filter.lowStockOnly,
              onSelected: (v) => _set(_filter.copyWith(lowStockOnly: v)),
            );
            if (c.maxWidth < 560) {
              // Phone: full-width search, dropdowns side by side.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  search,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: category),
                      const SizedBox(width: 10),
                      Expanded(child: sort),
                    ],
                  ),
                  const SizedBox(height: 10),
                  lowStock,
                ],
              );
            }
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(width: 260, child: search),
                SizedBox(width: 170, child: category),
                SizedBox(width: 210, child: sort),
                lowStock,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (widget.error != null) {
      return _message(
        'Could not load inventory',
        '${widget.error}',
        action: OutlinedButton(
          onPressed: widget.onRetry,
          child: const Text('Try again'),
        ),
      );
    }
    final all = widget.items;
    if (all == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(height: 12),
              Text(
                'Loading from Firestore...',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }
    if (all.isEmpty) {
      return _message(
        'No items yet',
        'Items you save with the form will appear here.',
      );
    }
    final visible = _filter.apply(all);
    if (visible.isEmpty) {
      return _message(
        'No matching items',
        'No saved item matches the current search and filters.',
        action: OutlinedButton(
          onPressed: _clear,
          child: const Text('Clear filters'),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final table = c.maxWidth >= 760;
        final list = ListView.separated(
          shrinkWrap: !widget.scrollable,
          physics: widget.scrollable
              ? null
              : const NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (_, i) {
            final item = visible[i];
            return _ItemRow(
              key: ValueKey(item.id),
              item: item,
              table: table,
              busy: _busyIds.contains(item.id),
              onIncrement: () => _run(
                item,
                () => widget.repository.adjustQuantity(item.id!, 1),
              ),
              onDecrement: item.quantity == 0
                  ? null
                  : () => _run(
                      item,
                      () => widget.repository.adjustQuantity(item.id!, -1),
                    ),
              onEdit: () => _edit(item),
              onDelete: () => _delete(item),
            );
          },
        );
        return Column(
          mainAxisSize: widget.scrollable ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (table) const _TableHeader(),
            widget.scrollable ? Expanded(child: list) : list,
          ],
        );
      },
    );
  }

  Widget _message(String title, String detail, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }
}

// Column widths shared by the header and rows.
const _wSku = 96.0;
const _wCategory = 110.0;
const _wPrice = 90.0;
const _wReorder = 70.0;
const _wQty = 128.0;
const _wStatus = 104.0;
const _wActions = 44.0;

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppColors.muted,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    );
    Widget cell(String t, double? w, {TextAlign align = TextAlign.left}) {
      final text = Text(t, style: style, textAlign: align);
      return w == null
          ? Expanded(child: text)
          : SizedBox(width: w, child: text);
    }

    return Container(
      color: AppColors.hover,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          cell('SKU', _wSku),
          cell('ITEM', null),
          cell('CATEGORY', _wCategory),
          cell('PRICE', _wPrice, align: TextAlign.right),
          cell('REORDER', _wReorder, align: TextAlign.right),
          cell('QUANTITY', _wQty, align: TextAlign.center),
          cell('STATUS', _wStatus),
          const SizedBox(width: _wActions),
        ],
      ),
    );
  }
}

class _ItemRow extends StatefulWidget {
  const _ItemRow({
    super.key,
    required this.item,
    required this.table,
    required this.busy,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
    required this.onDelete,
  });

  final StockItem item;
  final bool table;
  final bool busy;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final price = 'RM ${item.unitPrice.toStringAsFixed(2)}';
    final stepper = _Stepper(
      quantity: item.quantity,
      busy: widget.busy,
      onIncrement: widget.onIncrement,
      onDecrement: widget.onDecrement,
    );
    final menu = PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_horiz, color: AppColors.muted, size: 20),
      onSelected: (v) => v == 'edit' ? widget.onEdit() : widget.onDelete(),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
    final badge = StockBadge(
      quantity: item.quantity,
      reorder: item.reorderLevel,
    );

    final content = widget.table
        ? Row(
            children: [
              SizedBox(
                width: _wSku,
                child: Text(item.sku, style: monoStyle()),
              ),
              Expanded(
                child: Text(
                  item.itemName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              SizedBox(
                width: _wCategory,
                child: Text(
                  item.category,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
              SizedBox(
                width: _wPrice,
                child: Text(price, textAlign: TextAlign.right),
              ),
              SizedBox(
                width: _wReorder,
                child: Text(
                  '${item.reorderLevel}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
              SizedBox(
                width: _wQty,
                child: Center(child: stepper),
              ),
              SizedBox(
                width: _wStatus,
                child: Align(alignment: Alignment.centerLeft, child: badge),
              ),
              SizedBox(width: _wActions, child: menu),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(item.sku, style: monoStyle(size: 12.5)),
                        const SizedBox(width: 8),
                        badge,
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.itemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.category} · $price · reorder at ${item.reorderLevel}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    stepper,
                  ],
                ),
              ),
              menu,
            ],
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onEdit,
        child: Container(
          color: _hover ? AppColors.hover : AppColors.white,
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: widget.table ? 10 : 14,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Inline -/+ control that writes the new quantity straight to Firestore.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.quantity,
    required this.busy,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final bool busy;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tip, VoidCallback? onTap) => SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        tooltip: tip,
        padding: EdgeInsets.zero,
        iconSize: 16,
        color: AppColors.ink,
        disabledColor: AppColors.faint,
        icon: Icon(icon),
        onPressed: busy ? null : onTap,
      ),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove, 'Remove one', onDecrement),
          SizedBox(
            width: 40,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '$quantity',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          button(Icons.add, 'Add one', onIncrement),
        ],
      ),
    );
  }
}
