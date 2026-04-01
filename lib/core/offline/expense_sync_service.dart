import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../services/auth_service.dart';
import '../../models/expense_model.dart';
import 'expense_local_store.dart';
import 'expense_serialization.dart';

class ExpenseSyncService {
  ExpenseSyncService._();
  static final ExpenseSyncService instance = ExpenseSyncService._();

  Future<void> syncNowForUser(String userId) async {
    // 1) Push local queue to Firestore (best effort)
    await _syncPendingQueueToFirestore(userId);

    // 2) Pull remote data into local cache (best effort)
    await _pullRemoteToLocal(userId);
  }

  Future<void> syncNow() async {
    final userId = AuthService.instance.user.value?.id;
    if (userId == null) return;
    try {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[ExpenseSync] uid=$userId');
      }
      await syncNowForUser(userId);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('ExpenseSyncService syncNow failed: $e');
      }
    }
  }

  Future<void> _syncPendingQueueToFirestore(String userId) async {
    final pending = await ExpenseLocalStore.instance.getPendingOperations(userId: userId);
    if (pending.isEmpty) return;

    for (final op in pending) {
      try {
        // Last-write-wins uses updated_at_ms (numeric millis).
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('expenses')
            .doc(op.expenseId);

        final remoteSnap = await docRef.get();
        final remoteData = remoteSnap.data();

        final remoteUpdatedAtMs = _readRemoteUpdatedAtMs(remoteData);
        final localUpdatedAtMs = op.updatedAtMs;

        // Last-write-wins: uniquement si le local est plus récent.
        if (remoteUpdatedAtMs != null && localUpdatedAtMs < remoteUpdatedAtMs) {
          // Discard op; remote has newer state -> restore local to remote.
          if (remoteSnap.exists && remoteData != null) {
            final remoteExpense = ExpenseSerialization.fromFirestoreDoc(
              op.expenseId,
              remoteData,
              userId: userId,
            );
            await ExpenseLocalStore.instance.putExpense(
              userId: userId,
              expense: remoteExpense,
              synced: true,
            );
          }
          await ExpenseLocalStore.instance.removeOperation(
            userId: userId,
            opId: op.opId,
          );
          continue;
        }

        switch (op.type) {
          case ExpenseOpType.create:
          case ExpenseOpType.update:
            final expense = ExpenseSerialization.fromLocalMap(op.payload);
            if (expense.expenseId != op.expenseId) {
              // Sanity.
              continue;
            }
            await docRef.set(
              ExpenseSerialization.toFirestoreMap(expense),
              SetOptions(merge: true),
            );
            break;
          case ExpenseOpType.delete:
            await docRef.delete();
            break;
        }

        if (op.type == ExpenseOpType.delete) {
          await ExpenseLocalStore.instance.deleteExpense(
            userId: userId,
            expenseId: op.expenseId,
          );
        } else {
          await ExpenseLocalStore.instance.setExpenseSynced(
            userId: userId,
            expenseId: op.expenseId,
            synced: true,
          );
        }

        await ExpenseLocalStore.instance.removeOperation(userId: userId, opId: op.opId);
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('ExpenseSyncService op failed: $e');
        }
        // On laisse la queue intacte. (Pas de retry immédiat dans cette version)
      }
    }
  }

  Future<void> _pullRemoteToLocal(String userId) async {
    // Nota: on utilise `date DESC` car c'est indexé dans workflow.json.
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .limit(200);

    final snap = await query.get();
    for (final doc in snap.docs) {
      final data = doc.data();

      final expense = ExpenseSerialization.fromFirestoreDoc(
        doc.id,
        data,
        userId: userId,
      );

      // Compare updated_at_ms pour last-write-wins.
      final remoteUpdatedAtMs = _readRemoteUpdatedAtMs(data) ?? expense.updatedAt.millisecondsSinceEpoch;
      final local = await ExpenseLocalStore.instance.getExpense(
        userId: userId,
        expenseId: doc.id,
      );

      if (local == null || remoteUpdatedAtMs > local.updatedAt.millisecondsSinceEpoch) {
        await ExpenseLocalStore.instance.putExpense(
          userId: userId,
          expense: expense,
          synced: true,
        );
      }
    }
  }

  int? _readRemoteUpdatedAtMs(Map<String, dynamic>? data) {
    if (data == null) return null;
    final v = data['updated_at_ms'];
    if (v is num) return v.toInt();
    final updatedAt = data['updated_at'];
    if (updatedAt is Timestamp) {
      return updatedAt.toDate().millisecondsSinceEpoch;
    }
    return null;
  }

  Future<List<Expense>> getLatestLocalExpenses({int limit = 5}) async {
    final userId = AuthService.instance.user.value?.id;
    if (userId == null) return const [];
    try {
      return await ExpenseLocalStore.instance.getLatestExpenses(
        userId: userId,
        limit: limit,
      );
    } catch (_) {
      return const [];
    }
  }
}

