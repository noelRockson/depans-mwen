import 'dart:convert';

import '../../models/budget_model.dart';
import '../../models/enums.dart';
import 'budget_serialization.dart';
import '../local/local_db.dart';

enum BudgetOpType { create, update, delete }

class BudgetQueueOperation {
  BudgetQueueOperation({
    required this.opId,
    required this.type,
    required this.budgetId,
    required this.userId,
    required this.createdAtMs,
    required this.payload,
    this.attempts = 0,
    this.lastError,
  });

  final String opId;
  final BudgetOpType type;
  final String budgetId;
  final String userId;
  final int createdAtMs;
  final Map<String, dynamic> payload;
  final int attempts;
  final String? lastError;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'op_id': opId,
        'type': type.name,
        'budget_id': budgetId,
        'user_id': userId,
        'created_at_ms': createdAtMs,
        'payload': payload,
        'attempts': attempts,
        'last_error': lastError,
      };

  static BudgetOpType _typeFromString(String value) {
    switch (value) {
      case 'create':
        return BudgetOpType.create;
      case 'update':
        return BudgetOpType.update;
      case 'delete':
        return BudgetOpType.delete;
      default:
        return BudgetOpType.create;
    }
  }

  static BudgetQueueOperation fromMap(Map<String, dynamic> map) {
    return BudgetQueueOperation(
      opId: map['op_id'] as String,
      type: _typeFromString(map['type'] as String),
      budgetId: map['budget_id'] as String,
      userId: map['user_id'] as String,
      createdAtMs: (map['created_at_ms'] as num).toInt(),
      payload: (map['payload'] as Map).cast<String, dynamic>(),
      attempts: map['attempts'] == null ? 0 : (map['attempts'] as num).toInt(),
      lastError: map['last_error'] as String?,
    );
  }
}

class BudgetLocalStore {
  BudgetLocalStore._();
  static final BudgetLocalStore instance = BudgetLocalStore._();

  Future<void> putBudget({
    required String userId,
    required Budget budget,
    required bool synced,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.budgetsBox(userId);

    final toSave = Budget(
      budgetId: budget.budgetId,
      userId: budget.userId,
      name: budget.name,
      description: budget.description,
      amount: budget.amount,
      currency: budget.currency,
      periodType: budget.periodType,
      startDate: budget.startDate,
      endDate: budget.endDate,
      categoryIds: budget.categoryIds,
      alertThresholdPercentage: budget.alertThresholdPercentage,
      rolloverUnused: budget.rolloverUnused,
      status: budget.status,
      createdAt: budget.createdAt,
      synced: synced,
    );

    await box.put(
      toSave.budgetId,
      jsonEncode(BudgetSerialization.toLocalMap(toSave)),
    );
  }

  Future<Budget?> getBudget({
    required String userId,
    required String budgetId,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.budgetsBox(userId);
    final raw = box.get(budgetId);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return BudgetSerialization.fromLocalMap(map);
  }

  Future<void> deleteBudget({
    required String userId,
    required String budgetId,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.budgetsBox(userId);
    await box.delete(budgetId);
  }

  Future<void> setBudgetSynced({
    required String userId,
    required String budgetId,
    required bool synced,
  }) async {
    final existing = await getBudget(userId: userId, budgetId: budgetId);
    if (existing == null) return;
    await putBudget(userId: userId, budget: existing, synced: synced);
  }

  Future<List<Budget>> queryBudgets({
    required String userId,
    BudgetStatus? status,
    Currency? currency,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.budgetsBox(userId);

    final budgets = <Budget>[];
    for (final raw in box.values) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final budget = BudgetSerialization.fromLocalMap(map);

      if (status != null && budget.status != status) continue;
      if (currency != null && budget.currency != currency) continue;

      budgets.add(budget);
    }
    budgets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return budgets;
  }

  Future<void> enqueueOperation({
    required String userId,
    required BudgetQueueOperation op,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.budgetQueueBox(userId);
    await box.put(op.opId, jsonEncode(op.toMap()));
  }

  Future<List<BudgetQueueOperation>> getPendingOperations({
    required String userId,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.budgetQueueBox(userId);
    final ops = <BudgetQueueOperation>[];
    for (final raw in box.values) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      ops.add(BudgetQueueOperation.fromMap(map));
    }
    ops.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    return ops;
  }

  Future<void> removeOperation({
    required String userId,
    required String opId,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.budgetQueueBox(userId);
    await box.delete(opId);
  }

  Future<void> enqueueCreate({
    required String userId,
    required Budget budget,
    required int opCreatedAtMs,
  }) async {
    final op = BudgetQueueOperation(
      opId: 'create_${budget.budgetId}_$opCreatedAtMs',
      type: BudgetOpType.create,
      budgetId: budget.budgetId,
      userId: userId,
      createdAtMs: opCreatedAtMs,
      payload: BudgetSerialization.toLocalMap(budget),
    );
    await enqueueOperation(userId: userId, op: op);
  }

  Future<void> enqueueUpdate({
    required String userId,
    required Budget budget,
    required int opCreatedAtMs,
  }) async {
    final op = BudgetQueueOperation(
      opId: 'update_${budget.budgetId}_$opCreatedAtMs',
      type: BudgetOpType.update,
      budgetId: budget.budgetId,
      userId: userId,
      createdAtMs: opCreatedAtMs,
      payload: BudgetSerialization.toLocalMap(budget),
    );
    await enqueueOperation(userId: userId, op: op);
  }

  Future<void> enqueueDelete({
    required String userId,
    required String budgetId,
    required int opCreatedAtMs,
  }) async {
    final op = BudgetQueueOperation(
      opId: 'delete_${budgetId}_$opCreatedAtMs',
      type: BudgetOpType.delete,
      budgetId: budgetId,
      userId: userId,
      createdAtMs: opCreatedAtMs,
      payload: const <String, dynamic>{},
    );
    await enqueueOperation(userId: userId, op: op);
  }
}
