import 'stock_item.dart';

/// Field validators used by the stock entry form (Task 1).
/// Each returns an error message, or null when the value is valid.
class StockValidators {
  static final RegExp _skuPattern = RegExp(r'^STK-\d{3}$');
  static final RegExp _wholeNumber = RegExp(r'^\d+$');

  static String? sku(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'SKU is required';
    if (!_skuPattern.hasMatch(v)) {
      return 'SKU must be STK- followed by 3 digits, e.g. STK-101';
    }
    return null;
  }

  /// Rejects a SKU that already exists in Firestore. [except] is the SKU of
  /// the item being edited, so it can keep its own code.
  static String? uniqueSku(
    String? value,
    Set<String> existing, {
    String? except,
  }) {
    final v = value?.trim() ?? '';
    if (v != except && existing.contains(v)) {
      return 'SKU $v already exists in the inventory';
    }
    return null;
  }

  static String? itemName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Item name is required';
    if (v.length < 3) return 'Item name must be at least 3 characters';
    return null;
  }

  static String? category(String? value) {
    if (value == null || value.isEmpty) return 'Please select a category';
    if (!kCategories.contains(value)) return 'Invalid category';
    return null;
  }

  static String? _nonNegativeInt(String? value, String label) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label is required';
    if (v.startsWith('-')) return '$label cannot be negative';
    if (!_wholeNumber.hasMatch(v)) return '$label must be a whole number';
    return null;
  }

  static String? quantity(String? value) => _nonNegativeInt(value, 'Quantity');

  static String? reorderLevel(String? value) =>
      _nonNegativeInt(value, 'Reorder level');

  static String? unitPrice(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Unit price is required';
    final price = double.tryParse(v);
    if (price == null || !price.isFinite) {
      return 'Unit price must be a number, e.g. 19.90';
    }
    if (price <= 0) return 'Unit price must be greater than RM 0';
    return null;
  }
}
