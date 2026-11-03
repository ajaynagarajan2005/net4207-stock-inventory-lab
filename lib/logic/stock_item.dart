import 'package:cloud_firestore/cloud_firestore.dart';

/// The four permitted categories (Task 1 / data model).
const List<String> kCategories = [
  'Electronics',
  'Stationery',
  'Hardware',
  'Grocery',
];

/// One document in the `stockItems` Firestore collection.
class StockItem {
  final String? id;
  final String sku;
  final String itemName;
  final String category;
  final int quantity;
  final double unitPrice;
  final int reorderLevel;
  final DateTime? createdAt;

  const StockItem({
    this.id,
    required this.sku,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    required this.reorderLevel,
    this.createdAt,
  });

  /// Low stock means quantity is less than or equal to reorderLevel.
  bool get isLowStock => quantity <= reorderLevel;

  bool get isOutOfStock => quantity == 0;

  /// Value of the units on hand, in RM.
  double get stockValue => quantity * unitPrice;

  /// Fields sent on an edit. createdAt is left untouched.
  Map<String, dynamic> toUpdate() => {
    'sku': sku,
    'itemName': itemName,
    'category': category,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'reorderLevel': reorderLevel,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Map written to Firestore. createdAt uses the server timestamp.
  Map<String, dynamic> toFirestore() => {
    'sku': sku,
    'itemName': itemName,
    'category': category,
    'quantity': quantity, // int
    'unitPrice': unitPrice, // number (double)
    'reorderLevel': reorderLevel, // int
    'createdAt': FieldValue.serverTimestamp(),
  };

  factory StockItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final ts = d['createdAt'];
    return StockItem(
      id: doc.id,
      sku: (d['sku'] ?? '').toString(),
      itemName: (d['itemName'] ?? '').toString(),
      category: (d['category'] ?? '').toString(),
      quantity: (d['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (d['unitPrice'] as num?)?.toDouble() ?? 0,
      reorderLevel: (d['reorderLevel'] as num?)?.toInt() ?? 0,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

/// Summary figures for the dashboard cards.
class InventoryStats {
  final int itemCount;
  final int totalUnits;
  final int lowStockCount;
  final int outOfStockCount;
  final double totalValue;

  const InventoryStats({
    required this.itemCount,
    required this.totalUnits,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.totalValue,
  });

  factory InventoryStats.of(List<StockItem> items) => InventoryStats(
    itemCount: items.length,
    totalUnits: items.fold(0, (s, i) => s + i.quantity),
    lowStockCount: items.where((i) => i.isLowStock).length,
    outOfStockCount: items.where((i) => i.isOutOfStock).length,
    totalValue: items.fold(0.0, (s, i) => s + i.stockValue),
  );
}
