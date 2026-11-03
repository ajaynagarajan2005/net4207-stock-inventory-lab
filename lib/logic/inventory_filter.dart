import 'stock_item.dart';

enum SortOption {
  newest('Newest first'),
  quantityAsc('Quantity: low to high'),
  quantityDesc('Quantity: high to low'),
  nameAsc('Name: A to Z'),
  priceDesc('Price: high to low');

  const SortOption(this.label);
  final String label;
}

/// Search criteria for the inventory screen (Task 3).
/// Active controls are combined with AND.
class InventoryFilter {
  final String keyword;
  final String category; // 'All' or one of kCategories
  final bool lowStockOnly;
  final SortOption sort;

  const InventoryFilter({
    this.keyword = '',
    this.category = 'All',
    this.lowStockOnly = false,
    this.sort = SortOption.newest,
  });

  bool get isActive =>
      keyword.trim().isNotEmpty ||
      category != 'All' ||
      lowStockOnly ||
      sort != SortOption.newest;

  InventoryFilter copyWith({
    String? keyword,
    String? category,
    bool? lowStockOnly,
    SortOption? sort,
  }) => InventoryFilter(
    keyword: keyword ?? this.keyword,
    category: category ?? this.category,
    lowStockOnly: lowStockOnly ?? this.lowStockOnly,
    sort: sort ?? this.sort,
  );

  bool matches(StockItem item) {
    final k = keyword.trim().toLowerCase();
    // Keyword: partial, case-insensitive match on itemName OR sku.
    final keywordOk =
        k.isEmpty ||
        item.itemName.toLowerCase().contains(k) ||
        item.sku.toLowerCase().contains(k);
    final categoryOk = category == 'All' || item.category == category;
    final lowStockOk = !lowStockOnly || item.isLowStock;
    return keywordOk && categoryOk && lowStockOk;
  }

  /// Filters then sorts a freshly retrieved Firestore snapshot. The input is
  /// assumed to be newest-first, as returned by the repository.
  List<StockItem> apply(List<StockItem> items) {
    final result = items.where(matches).toList();
    switch (sort) {
      case SortOption.quantityAsc:
        result.sort((a, b) => a.quantity.compareTo(b.quantity));
      case SortOption.quantityDesc:
        result.sort((a, b) => b.quantity.compareTo(a.quantity));
      case SortOption.nameAsc:
        result.sort(
          (a, b) =>
              a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()),
        );
      case SortOption.priceDesc:
        result.sort((a, b) => b.unitPrice.compareTo(a.unitPrice));
      case SortOption.newest:
        break;
    }
    return result;
  }
}
