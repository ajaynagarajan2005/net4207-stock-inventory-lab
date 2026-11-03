// Acceptance tests from the NET4207 lab sheet, run against the same
// validation and search logic the app applies to Firestore snapshots.
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/logic/inventory_filter.dart';
import 'package:stock_inventory/logic/stock_item.dart';
import 'package:stock_inventory/logic/validators.dart';

const _items = [
  StockItem(
    sku: 'STK-101',
    itemName: 'USB C Cable',
    category: 'Electronics',
    quantity: 4,
    unitPrice: 19.90,
    reorderLevel: 5,
  ),
  StockItem(
    sku: 'STK-102',
    itemName: 'Notebook',
    category: 'Stationery',
    quantity: 25,
    unitPrice: 4.50,
    reorderLevel: 10,
  ),
  StockItem(
    sku: 'STK-103',
    itemName: 'Wireless Mouse',
    category: 'Electronics',
    quantity: 1,
    unitPrice: 35.00,
    reorderLevel: 3,
  ),
];

List<String> _skus(InventoryFilter f) =>
    f.apply(_items).map((i) => i.sku).toList();

void main() {
  group('Task 1 validation', () {
    test('blank input is rejected for every field', () {
      expect(StockValidators.sku(''), isNotNull);
      expect(StockValidators.itemName(''), isNotNull);
      expect(StockValidators.category(null), isNotNull);
      expect(StockValidators.quantity(''), isNotNull);
      expect(StockValidators.unitPrice(''), isNotNull);
      expect(StockValidators.reorderLevel(''), isNotNull);
    });

    test('SKU format', () {
      expect(StockValidators.sku('STK-101'), isNull);
      expect(StockValidators.sku('STK-1'), isNotNull);
      expect(StockValidators.sku('stk-101'), isNotNull);
      expect(StockValidators.sku('ABC-123'), isNotNull);
      expect(StockValidators.sku('STK-1012'), isNotNull);
    });

    test('item name is trimmed and at least 3 characters', () {
      expect(StockValidators.itemName('  ab  '), isNotNull);
      expect(StockValidators.itemName(' Pen '), isNull);
    });

    test('category must be one of the four', () {
      expect(StockValidators.category('Grocery'), isNull);
      expect(StockValidators.category('Toys'), isNotNull);
    });

    test('quantity and reorder level are non-negative whole numbers', () {
      expect(StockValidators.quantity('0'), isNull);
      expect(StockValidators.quantity('-1'), 'Quantity cannot be negative');
      expect(
        StockValidators.quantity('2.5'),
        'Quantity must be a whole number',
      );
      expect(
        StockValidators.reorderLevel('-3'),
        'Reorder level cannot be negative',
      );
      expect(
        StockValidators.reorderLevel('abc'),
        'Reorder level must be a whole number',
      );
    });

    test('duplicate SKU is rejected, except the item being edited', () {
      final existing = {'STK-101', 'STK-102'};
      expect(StockValidators.uniqueSku('STK-101', existing), isNotNull);
      expect(StockValidators.uniqueSku('STK-104', existing), isNull);
      expect(
        StockValidators.uniqueSku('STK-101', existing, except: 'STK-101'),
        isNull,
      );
    });

    test('unit price must be greater than 0', () {
      expect(StockValidators.unitPrice('19.90'), isNull);
      expect(StockValidators.unitPrice('0'), isNotNull);
      expect(StockValidators.unitPrice('-5'), isNotNull);
      expect(StockValidators.unitPrice('abc'), isNotNull);
    });
  });

  group('Task 3 search (lab acceptance table)', () {
    test('"mouse" + Electronics + Low stock -> only STK-103', () {
      expect(
        _skus(
          const InventoryFilter(
            keyword: 'mouse',
            category: 'Electronics',
            lowStockOnly: true,
          ),
        ),
        ['STK-103'],
      );
    });

    test('"STK-102" with All / all-stock -> Notebook', () {
      expect(_skus(const InventoryFilter(keyword: 'STK-102')), ['STK-102']);
      // Case-insensitive partial SKU.
      expect(_skus(const InventoryFilter(keyword: 'stk-10')).length, 3);
      expect(_skus(const InventoryFilter(keyword: 'k-102')), ['STK-102']);
    });

    test('sort by quantity ascending -> 103, 101, 102', () {
      expect(_skus(const InventoryFilter(sort: SortOption.quantityAsc)), [
        'STK-103',
        'STK-101',
        'STK-102',
      ]);
      expect(_skus(const InventoryFilter(sort: SortOption.quantityDesc)), [
        'STK-102',
        'STK-101',
        'STK-103',
      ]);
    });

    test('low stock uses quantity <= reorderLevel', () {
      expect(_skus(const InventoryFilter(lowStockOnly: true)), [
        'STK-101',
        'STK-103',
      ]);
    });

    test('clearing filters returns the full list', () {
      const cleared = InventoryFilter();
      expect(cleared.isActive, isFalse);
      expect(cleared.apply(_items).length, 3);
    });

    test('extra sorts: name A-Z and price high-low', () {
      expect(_skus(const InventoryFilter(sort: SortOption.nameAsc)), [
        'STK-102',
        'STK-101',
        'STK-103',
      ]);
      expect(_skus(const InventoryFilter(sort: SortOption.priceDesc)), [
        'STK-103',
        'STK-101',
        'STK-102',
      ]);
    });

    test('dashboard stats', () {
      final s = InventoryStats.of(_items);
      expect(s.itemCount, 3);
      expect(s.totalUnits, 30);
      expect(s.lowStockCount, 2);
      expect(s.totalValue, closeTo(4 * 19.90 + 25 * 4.50 + 35.00, 0.001));
    });

    test('no match returns empty list', () {
      expect(
        _skus(const InventoryFilter(keyword: 'mouse', category: 'Stationery')),
        isEmpty,
      );
    });
  });
}
