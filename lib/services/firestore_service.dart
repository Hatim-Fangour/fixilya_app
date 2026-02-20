/// Services - Firestore Service
/// Complete Cloud Firestore wrapper with all operations
///
/// Features:
/// - CRUD operations
/// - Advanced queries
/// - Real-time streams
/// - Batch operations
/// - Transactions
/// - Pagination
/// - Field operations
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== Create Operations ====================

  /// Create document with auto-generated ID
  Future<String> create({
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Add timestamps
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      final docRef = await _firestore.collection(collection).add(data);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create document: ${e.toString()}');
    }
  }

  /// Set document with specific ID
  Future<void> set({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    bool merge = false,
  }) async {
    try {
      // Add timestamps if not merging or timestamps don't exist
      if (!merge || !data.containsKey('createdAt')) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(collection)
          .doc(documentId)
          .set(data, SetOptions(merge: merge));
    } catch (e) {
      throw Exception('Failed to set document: ${e.toString()}');
    }
  }

  // ==================== Read Operations ====================

  /// Get single document by ID
  Future<Map<String, dynamic>?> get({
    required String collection,
    required String documentId,
  }) async {
    try {
      final doc = await _firestore.collection(collection).doc(documentId).get();

      if (!doc.exists) {
        return null;
      }

      return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    } catch (e) {
      throw Exception('Failed to get document: ${e.toString()}');
    }
  }

  /// Get all documents in collection
  Future<List<Map<String, dynamic>>> getAll({
    required String collection,
    int? limit,
    String? orderBy,
    bool descending = false,
  }) async {
    try {
      Query query = _firestore.collection(collection);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();
    } catch (e) {
      throw Exception('Failed to get documents: ${e.toString()}');
    }
  }

  // ==================== Update Operations ====================

  /// Update document
  Future<void> update({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection(collection).doc(documentId).update(data);
    } catch (e) {
      throw Exception('Failed to update document: ${e.toString()}');
    }
  }

  // ==================== Delete Operations ====================

  /// Delete document
  Future<void> delete({
    required String collection,
    required String documentId,
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).delete();
    } catch (e) {
      throw Exception('Failed to delete document: ${e.toString()}');
    }
  }

  /// Delete collection (in batches)
  Future<void> deleteCollection({
    required String collection,
    int batchSize = 500,
  }) async {
    final collectionRef = _firestore.collection(collection);
    final query = collectionRef.limit(batchSize);

    await _deleteQueryBatch(query, batchSize);
  }

  Future<void> _deleteQueryBatch(Query query, int batchSize) async {
    final snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();

    if (snapshot.docs.length >= batchSize) {
      await _deleteQueryBatch(query, batchSize);
    }
  }

  // ==================== Query Operations ====================

  /// Query documents with filters
  Future<List<Map<String, dynamic>>> query({
    required String collection,
    List<QueryFilter>? filters,
    List<QueryOrder>? orderBy,
    int? limit,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore.collection(collection);

      // Apply filters
      if (filters != null) {
        for (final filter in filters) {
          query = _applyFilter(query, filter);
        }
      }

      // Apply ordering
      if (orderBy != null) {
        for (final order in orderBy) {
          query = query.orderBy(order.field, descending: order.descending);
        }
      }

      // Apply pagination
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();
    } catch (e) {
      throw Exception('Failed to query documents: ${e.toString()}');
    }
  }

  Query _applyFilter(Query query, QueryFilter filter) {
    switch (filter.operator) {
      case QueryOperator.isEqualTo:
        return query.where(filter.field, isEqualTo: filter.value);
      case QueryOperator.isNotEqualTo:
        return query.where(filter.field, isNotEqualTo: filter.value);
      case QueryOperator.isLessThan:
        return query.where(filter.field, isLessThan: filter.value);
      case QueryOperator.isLessThanOrEqualTo:
        return query.where(filter.field, isLessThanOrEqualTo: filter.value);
      case QueryOperator.isGreaterThan:
        return query.where(filter.field, isGreaterThan: filter.value);
      case QueryOperator.isGreaterThanOrEqualTo:
        return query.where(filter.field, isGreaterThanOrEqualTo: filter.value);
      case QueryOperator.arrayContains:
        return query.where(filter.field, arrayContains: filter.value);
      case QueryOperator.arrayContainsAny:
        return query.where(filter.field, arrayContainsAny: filter.value);
      case QueryOperator.whereIn:
        return query.where(filter.field, whereIn: filter.value);
      case QueryOperator.whereNotIn:
        return query.where(filter.field, whereNotIn: filter.value);
      case QueryOperator.isNull:
        return query.where(filter.field, isNull: true);
    }
  }

  // ==================== Stream Operations ====================

  /// Stream single document
  Stream<Map<String, dynamic>?> streamDocument({
    required String collection,
    required String documentId,
  }) {
    return _firestore.collection(collection).doc(documentId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) {
        return null;
      }

      return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    });
  }

  /// Stream collection
  Stream<List<Map<String, dynamic>>> streamCollection({
    required String collection,
    List<QueryFilter>? filters,
    List<QueryOrder>? orderBy,
    int? limit,
  }) {
    Query query = _firestore.collection(collection);

    // Apply filters
    if (filters != null) {
      for (final filter in filters) {
        query = _applyFilter(query, filter);
      }
    }

    // Apply ordering
    if (orderBy != null) {
      for (final order in orderBy) {
        query = query.orderBy(order.field, descending: order.descending);
      }
    }

    // Apply limit
    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();
    });
  }

  // ==================== Batch Operations ====================

  /// Execute batch write
  Future<void> batchWrite(List<BatchOperation> operations) async {
    try {
      final batch = _firestore.batch();

      for (final operation in operations) {
        final docRef = _firestore
            .collection(operation.collection)
            .doc(operation.documentId);

        switch (operation.type) {
          case BatchOperationType.set:
            batch.set(docRef, operation.data!);
            break;
          case BatchOperationType.update:
            batch.update(docRef, operation.data!);
            break;
          case BatchOperationType.delete:
            batch.delete(docRef);
            break;
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to execute batch: ${e.toString()}');
    }
  }

  // ==================== Transaction Operations ====================

  /// Run transaction
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) updateFunction,
  ) async {
    try {
      return await _firestore.runTransaction(updateFunction);
    } catch (e) {
      throw Exception('Transaction failed: ${e.toString()}');
    }
  }

  // ==================== Field Operations ====================

  /// Increment numeric field
  Future<void> increment({
    required String collection,
    required String documentId,
    required String field,
    num value = 1,
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).update({
        field: FieldValue.increment(value),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to increment field: ${e.toString()}');
    }
  }

  /// Decrement numeric field
  Future<void> decrement({
    required String collection,
    required String documentId,
    required String field,
    num value = 1,
  }) async {
    await increment(
      collection: collection,
      documentId: documentId,
      field: field,
      value: -value,
    );
  }

  /// Add item to array field
  Future<void> arrayAdd({
    required String collection,
    required String documentId,
    required String field,
    required dynamic value,
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).update({
        field: FieldValue.arrayUnion([value]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add to array: ${e.toString()}');
    }
  }

  /// Remove item from array field
  Future<void> arrayRemove({
    required String collection,
    required String documentId,
    required String field,
    required dynamic value,
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).update({
        field: FieldValue.arrayRemove([value]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to remove from array: ${e.toString()}');
    }
  }

  // ==================== Aggregation ====================

  /// Count documents in collection
  Future<int> count({
    required String collection,
    List<QueryFilter>? filters,
  }) async {
    try {
      Query query = _firestore.collection(collection);

      if (filters != null) {
        for (final filter in filters) {
          query = _applyFilter(query, filter);
        }
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Failed to count documents: ${e.toString()}');
    }
  }

  // ==================== Subcollections ====================

  /// Get subcollection reference
  CollectionReference getSubcollection({
    required String collection,
    required String documentId,
    required String subcollection,
  }) {
    return _firestore
        .collection(collection)
        .doc(documentId)
        .collection(subcollection);
  }

  // ==================== Existence Check ====================

  /// Check if document exists
  Future<bool> exists({
    required String collection,
    required String documentId,
  }) async {
    try {
      final doc = await _firestore.collection(collection).doc(documentId).get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }
}

// ==================== Helper Classes ====================

/// Query filter for advanced queries
class QueryFilter {
  final String field;
  final QueryOperator operator;
  final dynamic value;

  QueryFilter({
    required this.field,
    required this.operator,
    required this.value,
  });

  factory QueryFilter.isEqualTo(String field, dynamic value) {
    return QueryFilter(
      field: field,
      operator: QueryOperator.isEqualTo,
      value: value,
    );
  }

  factory QueryFilter.isGreaterThan(String field, dynamic value) {
    return QueryFilter(
      field: field,
      operator: QueryOperator.isGreaterThan,
      value: value,
    );
  }

  factory QueryFilter.isLessThan(String field, dynamic value) {
    return QueryFilter(
      field: field,
      operator: QueryOperator.isLessThan,
      value: value,
    );
  }

  factory QueryFilter.arrayContains(String field, dynamic value) {
    return QueryFilter(
      field: field,
      operator: QueryOperator.arrayContains,
      value: value,
    );
  }
}

/// Query order for sorting
class QueryOrder {
  final String field;
  final bool descending;

  QueryOrder({required this.field, this.descending = false});
}

/// Batch operation
class BatchOperation {
  final BatchOperationType type;
  final String collection;
  final String documentId;
  final Map<String, dynamic>? data;

  BatchOperation({
    required this.type,
    required this.collection,
    required this.documentId,
    this.data,
  });
}

/// Query operators
enum QueryOperator {
  isEqualTo,
  isNotEqualTo,
  isLessThan,
  isLessThanOrEqualTo,
  isGreaterThan,
  isGreaterThanOrEqualTo,
  arrayContains,
  arrayContainsAny,
  whereIn,
  whereNotIn,
  isNull,
}

/// Batch operation types
enum BatchOperationType { set, update, delete }
