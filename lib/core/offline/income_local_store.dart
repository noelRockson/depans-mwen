import 'dart:convert';

import '../../models/enums.dart';
import '../../models/income_model.dart';
import 'income_serialization.dart';
import '../local/local_db.dart';

enum IncomeOpType {
  create,
  update,
  delete,
}

class IncomeQueueOperation {
  IncomeQueueOperation({
    required this.opId,
    required this.type,
    required this.incomeId,
    required this.userId,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.payload,
    this.attempts = 0,
    this.lastError,
  });

  final String opId;
  final IncomeOpType type;
  final String incomeId;
  final String userId;
  final int createdAtMs;
  final int updatedAtMs;
  final Map<String, dynamic> payload;
  final int attempts;
  final String? lastError;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'op_id': opId,
        'type': type.name,
        'income_id': incomeId,
        'user_id': userId,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'payload': payload,
        'attempts': attempts,
        'last_error': lastError,
      };

  static IncomeOpType _typeFromString(String value) {
    switch (value) {
      case 'create':
        return IncomeOpType.create;
      case 'update':
        return IncomeOpType.update;
      case 'delete':
        return IncomeOpType.delete;
      default:
        return IncomeOpType.create;
    }
  }

  static IncomeQueueOperation fromMap(Map<String, dynamic> map) {
    return IncomeQueueOperation(
      opId: map['op_id'] as String,
      type: _typeFromString(map['type'] as String),
      incomeId: map['income_id'] as String,
      userId: map['user_id'] as String,
      createdAtMs: (map['created_at_ms'] as num).toInt(),
      updatedAtMs: (map['updated_at_ms'] as num).toInt(),
      payload: (map['payload'] as Map).cast<String, dynamic>(),
      attempts: map['attempts'] == null ? 0 : (map['attempts'] as num).toInt(),
      lastError: map['last_error'] as String?,
    );
  }
}

/// Local Hive cache + offline queue for `incomes`.
class IncomeLocalStore {
  IncomeLocalStore._();
  static final IncomeLocalStore instance = IncomeLocalStore._();

  Future<void> putIncome({
    required String userId,
    required Income income,
    required bool synced,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.incomesBox(userId);

    final toSave = Income(
      incomeId: income.incomeId,
      userId: income.userId,
      sourceLabel: income.sourceLabel,
      amount: income.amount,
      currency: income.currency,
      frequency: income.frequency,
      nextPaymentDate: income.nextPaymentDate,
      isActive: income.isActive,
      createdAt: income.createdAt,
      lastUpdated: income.lastUpdated,
      synced: synced,
    );

    await box.put(
      toSave.incomeId,
      jsonEncode(IncomeSerialization.toLocalMap(toSave)),
    );
  }

  Future<Income?> getIncome({
    required String userId,
    required String incomeId,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.incomesBox(userId);
    final raw = box.get(incomeId);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return IncomeSerialization.fromLocalMap(map);
  }

  Future<List<Income>> queryIncomes({
    required String userId,
    DateTime? startInclusive,
    DateTime? endInclusive,
    Currency? currency,
    String? searchQuery,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.incomesBox(userId);
    final q = searchQuery?.trim().toLowerCase();

    final incomes = <Income>[];
    for (final raw in box.values) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final income = IncomeSerialization.fromLocalMap(map);

      if (startInclusive != null &&
          income.nextPaymentDate.isBefore(startInclusive)) {
        continue;
      }
      if (endInclusive != null &&
          income.nextPaymentDate.isAfter(endInclusive)) {
        continue;
      }
      if (currency != null && income.currency != currency) continue;
      if (q != null && q.isNotEmpty) {
        final src = income.sourceLabel.toLowerCase();
        if (!src.contains(q)) continue;
      }

      incomes.add(income);
    }

    incomes.sort((a, b) => b.nextPaymentDate.compareTo(a.nextPaymentDate));
    return incomes;
  }

  Future<void> deleteIncome({
    required String userId,
    required String incomeId,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.incomesBox(userId);
    await box.delete(incomeId);
  }

  Future<List<IncomeQueueOperation>> getPendingOperations({
    required String userId,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.incomeQueueBox(userId);
    final ops = <IncomeQueueOperation>[];
    for (final raw in box.values) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      ops.add(IncomeQueueOperation.fromMap(map));
    }
    ops.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    return ops;
  }

  Future<void> enqueueOperation({
    required String userId,
    required IncomeQueueOperation op,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.incomeQueueBox(userId);
    await box.put(op.opId, jsonEncode(op.toMap()));
  }

  Future<void> removeOperation({
    required String userId,
    required String opId,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.incomeQueueBox(userId);
    await box.delete(opId);
  }

  Future<void> setIncomeSynced({
    required String userId,
    required String incomeId,
    required bool synced,
  }) async {
    final existing = await getIncome(userId: userId, incomeId: incomeId);
    if (existing == null) return;
    await putIncome(userId: userId, income: existing, synced: synced);
  }

  Future<List<Income>> getLatestIncomes({
    required String userId,
    int limit = 5,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.incomesBox(userId);
    final incomes = <Income>[];
    for (final raw in box.values) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      incomes.add(IncomeSerialization.fromLocalMap(map));
    }
    incomes.sort((a, b) => b.nextPaymentDate.compareTo(a.nextPaymentDate));
    return incomes.take(limit).toList();
  }

  Future<void> enqueueCreate({
    required String userId,
    required Income income,
    required int opCreatedAtMs,
  }) async {
    final op = IncomeQueueOperation(
      opId: 'create_${income.incomeId}_$opCreatedAtMs',
      type: IncomeOpType.create,
      incomeId: income.incomeId,
      userId: userId,
      createdAtMs: opCreatedAtMs,
      updatedAtMs: income.lastUpdated.millisecondsSinceEpoch,
      payload: IncomeSerialization.toLocalMap(income),
    );
    await enqueueOperation(userId: userId, op: op);
  }

  Future<void> enqueueUpdate({
    required String userId,
    required Income income,
    required int opCreatedAtMs,
  }) async {
    final op = IncomeQueueOperation(
      opId: 'update_${income.incomeId}_$opCreatedAtMs',
      type: IncomeOpType.update,
      incomeId: income.incomeId,
      userId: userId,
      createdAtMs: opCreatedAtMs,
      updatedAtMs: income.lastUpdated.millisecondsSinceEpoch,
      payload: IncomeSerialization.toLocalMap(income),
    );
    await enqueueOperation(userId: userId, op: op);
  }

  Future<void> enqueueDelete({
    required String userId,
    required String incomeId,
    required int opCreatedAtMs,
    required int updatedAtMs,
  }) async {
    final op = IncomeQueueOperation(
      opId: 'delete_${incomeId}_$opCreatedAtMs',
      type: IncomeOpType.delete,
      incomeId: incomeId,
      userId: userId,
      createdAtMs: opCreatedAtMs,
      updatedAtMs: updatedAtMs,
      payload: const <String, dynamic>{},
    );
    await enqueueOperation(userId: userId, op: op);
  }
}

