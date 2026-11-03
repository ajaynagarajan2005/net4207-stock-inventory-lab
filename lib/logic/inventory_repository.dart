import 'package:cloud_firestore/cloud_firestore.dart';

import 'stock_item.dart';

/// All Firestore access for the `stockItems` collection (Task 2).
class InventoryRepository {
  InventoryRepository([FirebaseFirestore? db])
    : _col = (db ?? FirebaseFirestore.instance).collection('stockItems');

  final CollectionReference<Map<String, dynamic>> _col;

  /// Adds a document with an auto-generated ID. The returned future only
  /// completes once the server acknowledges the write.
  Future<String> add(StockItem item) async {
    final ref = await _col.add(item.toFirestore());
    return ref.id;
  }

  /// Replaces the editable fields of an existing item.
  Future<void> update(String id, StockItem item) =>
      _col.doc(id).update(item.toUpdate());

  /// Quick restock / sell: atomically changes quantity by [delta].
  Future<void> adjustQuantity(String id, int delta) => _col.doc(id).update({
    'quantity': FieldValue.increment(delta),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Re-creates a deleted item under its old ID (used by Undo).
  Future<void> restore(StockItem item) =>
      _col.doc(item.id).set(item.toFirestore());

  /// Live stream of saved items, newest first. Reads straight from
  /// Firestore, so the list is restored after a page reload.
  Stream<List<StockItem>> watchAll() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(StockItem.fromFirestore).toList());
}
