import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../services/auth_service.dart';
import '../../models/budget_model.dart';
import 'budget_local_store.dart';
import 'budget_serialization.dart';

class BudgetSyncService {
  BudgetSyncService._();
  static final BudgetSyncService instance = BudgetSyncService._();

  Future<void> syncNow() async {
    final userId = AuthService.instance.user.value?.id;
    if (userId == null) return;
    try {
      await _syncPendingQueueToFirestore(userId);
      await _pullRemoteToLocal(userId);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('BudgetSyncService syncNow failed: $e');
      }
    }
  }

  Future<void> _syncPendingQueueToFirestore(String userId) async {
    final pending =
        await BudgetLocalStore.instance.getPendingOperations(userId: userId);
    if (pending.isEmpty) return;

    for (final op in pending) {
      try {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('budgets')
            .doc(op.budgetId);

        switch (op.type) {
          case BudgetOpType.create:
          case BudgetOpType.update:
            final budget = BudgetSerialization.fromLocalMap(op.payload);
            await docRef.set(
              BudgetSerialization.toFirestoreMap(budget),
              SetOptions(merge: true),
            );
            break;
          case BudgetOpType.delete:
            await docRef.delete();
            break;
        }

        if (op.type == BudgetOpType.delete) {
          await BudgetLocalStore.instance.deleteBudget(
            userId: userId,
            budgetId: op.budgetId,
          );
        } else {
          await BudgetLocalStore.instance.setBudgetSynced(
            userId: userId,
            budgetId: op.budgetId,
            synced: true,
          );
        }

        await BudgetLocalStore.instance.removeOperation(
          userId: userId,
          opId: op.opId,
        );
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('BudgetSyncService op failed: $e');
        }
      }
    }
  }

  Future<void> _pullRemoteToLocal(String userId) async {
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('budgets')
        .orderBy('created_at', descending: true)
        .limit(100);

    final snap = await query.get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final budget = BudgetSerialization.fromFirestoreDoc(
        doc.id,
        data,
        userId: userId,
      );

      final local = await BudgetLocalStore.instance.getBudget(
        userId: userId,
        budgetId: doc.id,
      );

      if (local == null ||
          budget.createdAt.millisecondsSinceEpoch >
              local.createdAt.millisecondsSinceEpoch) {
        await BudgetLocalStore.instance.putBudget(
          userId: userId,
          budget: budget,
          synced: true,
        );
      }
    }
  }

  Future<List<Budget>> getActiveBudgets() async {
    final userId = AuthService.instance.user.value?.id;
    if (userId == null) return const [];
    try {
      return await BudgetLocalStore.instance.queryBudgets(
        userId: userId,
        status: null,
      );
    } catch (_) {
      return const [];
    }
  }
}
