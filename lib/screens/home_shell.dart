import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../logic/inventory_filter.dart';
import '../logic/inventory_repository.dart';
import '../logic/stock_item.dart';
import '../theme/app_theme.dart';
import 'inventory_screen.dart';
import 'stock_form_screen.dart';

/// Top-level layout. One Firestore stream feeds the summary, the list and
/// the form's duplicate-SKU check. Wide screens show the form and list side
/// by side; narrow screens switch between them with tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repository});

  final InventoryRepository repository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late Stream<List<StockItem>> _stream = widget.repository.watchAll();
  InventoryFilter _filter = const InventoryFilter();
  int _tab = 0; // narrow layout: 0 = inventory, 1 = new item

  void _retry() => setState(() => _stream = widget.repository.watchAll());

  void _toggleLowStock() => setState(() {
    _filter = _filter.copyWith(lowStockOnly: !_filter.lowStockOnly);
    _tab = 0;
  });

  void _onSaved(StockItem item, bool wide) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${item.sku} saved to Firestore'),
          action: wide
              ? null
              : SnackBarAction(
                  label: 'View',
                  onPressed: () => setState(() => _tab = 0),
                ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<StockItem>>(
        stream: _stream,
        builder: (context, snap) {
          final items = snap.hasError ? null : snap.data;
          return Column(
            children: [
              _TopBar(
                loading: !snap.hasData && !snap.hasError,
                error: snap.hasError,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 1100;
                    final pad = c.maxWidth < 600 ? 16.0 : 24.0;

                    final summary = _Summary(
                      stats: items == null ? null : InventoryStats.of(items),
                      lowStockActive: _filter.lowStockOnly,
                      onLowStockTap: _toggleLowStock,
                    );
                    final formBody = Padding(
                      padding: const EdgeInsets.all(24),
                      child: StockForm(
                        existingSkus: {...?items?.map((i) => i.sku)},
                        onSubmit: widget.repository.add,
                        onSaved: (item) => _onSaved(item, wide),
                      ),
                    );
                    InventoryPanel list({required bool scrollable}) =>
                        InventoryPanel(
                          repository: widget.repository,
                          items: items,
                          error: snap.error,
                          filter: _filter,
                          onFilterChanged: (f) => setState(() => _filter = f),
                          onRetry: _retry,
                          scrollable: scrollable,
                        );

                    Widget frame(Widget child) => Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1320),
                        child: child,
                      ),
                    );

                    if (wide) {
                      // Desktop: fixed form on the left, scrolling list.
                      return frame(
                        Padding(
                          padding: EdgeInsets.all(pad),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              summary,
                              SizedBox(height: pad),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 380,
                                      child: Panel(
                                        child: SingleChildScrollView(
                                          child: formBody,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(child: list(scrollable: true)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Phone / tablet: the whole page scrolls. Both tabs stay
                    // mounted so typed form values survive a tab switch.
                    return SingleChildScrollView(
                      child: frame(
                        Padding(
                          padding: EdgeInsets.all(pad),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              summary,
                              SizedBox(height: pad),
                              _Tabs(
                                index: _tab,
                                onChanged: (i) => setState(() => _tab = i),
                              ),
                              const SizedBox(height: 12),
                              Visibility(
                                visible: _tab == 0,
                                maintainState: true,
                                child: list(scrollable: false),
                              ),
                              Visibility(
                                visible: _tab == 1,
                                maintainState: true,
                                child: Panel(child: formBody),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.loading, required this.error});

  final bool loading;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final (dot, label) = error
        ? (AppColors.error, 'Disconnected')
        : loading
        ? (AppColors.faint, 'Connecting')
        : (AppColors.blue, 'Synced');
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'S',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Stock Inventory',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    // Project ID only where there is room for it.
                    MediaQuery.sizeOf(context).width < 480
                        ? ''
                        : DefaultFirebaseOptions.web.projectId,
                    overflow: TextOverflow.ellipsis,
                    style: monoStyle(
                      size: 12,
                      weight: FontWeight.w400,
                    ).copyWith(color: AppColors.muted),
                  ),
                ),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  key: const Key('connectionStatus'),
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Four key figures in one bordered strip.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.stats,
    required this.lowStockActive,
    required this.onLowStockTap,
  });

  final InventoryStats? stats;
  final bool lowStockActive;
  final VoidCallback onLowStockTap;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    String v(String Function(InventoryStats s) f) => s == null ? '–' : f(s);
    final cells = [
      _Metric(label: 'Products', value: v((s) => '${s.itemCount}')),
      _Metric(label: 'Units on hand', value: v((s) => '${s.totalUnits}')),
      _Metric(
        key: const Key('lowStockStat'),
        label: 'Low stock',
        value: v((s) => '${s.lowStockCount}'),
        note: s != null && s.outOfStockCount > 0
            ? '${s.outOfStockCount} out of stock'
            : null,
        action: lowStockActive ? 'Showing only these' : 'Show only these',
        active: lowStockActive,
        onTap: onLowStockTap,
      ),
      _Metric(
        label: 'Stock value',
        value: v((s) => 'RM ${s.totalValue.toStringAsFixed(2)}'),
      ),
    ];
    return Panel(
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 640) {
            // 2 x 2 grid on phones.
            return Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cells[0]),
                      const VerticalDivider(),
                      Expanded(child: cells[1]),
                    ],
                  ),
                ),
                const Divider(),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cells[2]),
                      const VerticalDivider(),
                      Expanded(child: cells[3]),
                    ],
                  ),
                ),
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < cells.length; i++) ...[
                  if (i > 0) const VerticalDivider(),
                  Expanded(child: cells[i]),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.action,
    this.active = false,
    this.onTap,
  });

  final String label;
  final String value;
  final String? note;
  final String? action;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      color: active ? AppColors.blueSoft : null,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          if (note != null || action != null) ...[
            const SizedBox(height: 4),
            Text(
              [?note, ?action].join(' · '),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: action != null ? AppColors.blue : AppColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(onTap: onTap, child: body);
  }
}

/// Underline tabs for the narrow layout.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Inventory', 'New item'];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            InkWell(
              key: Key('tab_$i'),
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: i == index ? AppColors.blue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: i == index ? AppColors.ink : AppColors.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
