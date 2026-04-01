import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/income_model.dart';
import '../../services/auth_service.dart';
import 'income_local_store.dart';
import 'income_serialization.dart';

class IncomeSyncService {
  IncomeSyncService._();
  static final IncomeSyncService instance = IncomeSyncService._();

  Future<void> syncNow() async {
    final userId = AuthService.instance.user.value?.id;
    if (userId == null) return;
    try {
      await syncNowForUser(userId);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('IncomeSyncService syncNow failed: $e');
      }
    }
  }

  Future<void> syncNowForUser(String userId) async {
    await _syncPendingQueueToFirestore(userId);
    await _pullRemoteToLocal(userId);
  }

  Future<void> _syncPendingQueueToFirestore(String userId) async {
    final pending = await IncomeLocalStore.instance.getPendingOperations(
      userId: userId,
    );
    if (pending.isEmpty) return;

    for (final op in pending) {
      try {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('incomes')
            .doc(op.incomeId);

        final remoteSnap = await docRef.get();
        final remoteData = remoteSnap.data();

        final remoteUpdatedAtMs = _readRemoteLastUpdatedMs(remoteData);
        final localUpdatedAtMs = op.updatedAtMs;

        // Last-write-wins
        if (remoteUpdatedAtMs != null && localUpdatedAtMs < remoteUpdatedAtMs) {
          // Restore local from remote to avoid losing newer data.
          if (remoteSnap.exists && remoteData != null) {
            final remoteIncome = IncomeSerialization.fromFirestoreDoc(
              incomeId: op.incomeId,
              data: remoteData,
              userId: userId,
            );
            await IncomeLocalStore.instance.putIncome(
              userId: userId,
              income: remoteIncome,
              synced: true,
            );
          }

          await IncomeLocalStore.instance.removeOperation(
            userId: userId,
            opId: op.opId,
          );
          continue;
        }

        switch (op.type) {
          case IncomeOpType.create:
          case IncomeOpType.update: {
            final income = IncomeSerialization.fromLocalMap(op.payload);
            if (income.incomeId != op.incomeId) continue;
            await docRef.set(
              IncomeSerialization.toFirestoreMap(income),
              SetOptions(merge: true),
            );
            await IncomeLocalStore.instance.setIncomeSynced(
              userId: userId,
              incomeId: op.incomeId,
              synced: true,
            );
            break;
          }
          case IncomeOpType.delete:
            await docRef.delete();
            await IncomeLocalStore.instance.deleteIncome(
              userId: userId,
              incomeId: op.incomeId,
            );
            break;
        }

        await IncomeLocalStore.instance.removeOperation(
          userId: userId,
          opId: op.opId,
        );
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('IncomeSyncService op failed: $e');
        }
        // keep queue for retry later
      }
    }
  }

  Future<void> _pullRemoteToLocal(String userId) async {
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('incomes')
        .orderBy('next_payment_date', descending: true)
        .limit(200);

    final snap = await query.get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final remoteUpdatedAtMs = _readRemoteLastUpdatedMs(data) ??
          (data['last_updated'] as Timestamp?)
              ?.toDate()
              .millisecondsSinceEpoch;

      final local = await IncomeLocalStore.instance.getIncome(
        userId: userId,
        incomeId: doc.id,
      );

      if (local == null ||
          (remoteUpdatedAtMs != null &&
              remoteUpdatedAtMs > local.lastUpdated.millisecondsSinceEpoch)) {
        final remoteIncome = IncomeSerialization.fromFirestoreDoc(
          incomeId: doc.id,
          data: data,
          userId: userId,
        );
        await IncomeLocalStore.instance.putIncome(
          userId: userId,
          income: remoteIncome,
          synced: true,
        );
      }
    }
  }

  int? _readRemoteLastUpdatedMs(Map<String, dynamic>? data) {
    if (data == null) return null;
    final v = data['last_updated_ms'];
    if (v is num) return v.toInt();
    final lastVal = data['last_updated'];
    if (lastVal is Timestamp) return lastVal.toDate().millisecondsSinceEpoch;
    return null;
  }

  Future<List<Income>> getLatestLocalIncomes({int limit = 5}) async {
    final userId = AuthService.instance.user.value?.id;
    if (userId == null) return const [];
    return IncomeLocalStore.instance.getLatestIncomes(userId: userId, limit: limit);
  }
}

