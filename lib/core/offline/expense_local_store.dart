import 'dart:convert';

import '../../models/expense_model.dart';
import '../../models/enums.dart';
import 'expense_serialization.dart';
import '../local/local_db.dart';

enum ExpenseOpType {
  create,
  update,
  delete,
}

class ExpenseQueueOperation {
  ExpenseQueueOperation({
    required this.opId,
    required this.type,
    required this.expenseId,
    required this.userId,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.payload,
    this.attempts = 0,
    this.lastError,
  });

  final String opId;
  final ExpenseOpType type;
  final String expenseId;
  final String userId;
  final int createdAtMs;
  final int updatedAtMs;
  final Map<String, dynamic> payload;
  final int attempts;
  final String? lastError;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'op_id': opId,
        'type': type.name,
        'expense_id': expenseId,
        'user_id': userId,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'payload': payload,
        'attempts': attempts,
        'last_error': lastError,
      };

  static ExpenseOpType _typeFromString(String value) {
    switch (value) {
      case 'create':
        return ExpenseOpType.create;
      case 'update':
        return ExpenseOpType.update;
      case 'delete':
        return ExpenseOpType.delete;
      default:
        return ExpenseOpType.create;
    }
  }

  static ExpenseQueueOperation fromMap(Map<String, dynamic> map) {
    return ExpenseQueueOperation(
      opId: map['op_id'] as String,
      type: _typeFromString(map['type'] as String),
      expenseId: map['expense_id'] as String,
      userId: map['user_id'] as String,
      createdAtMs: (map['created_at_ms'] as num).toInt(),
      updatedAtMs: (map['updated_at_ms'] as num).toInt(),
      payload: (map['payload'] as Map).cast<String, dynamic>(),
      attempts: map['attempts'] == null ? 0 : (map['attempts'] as num).toInt(),
      lastError: map['last_error'] as String?,
    );
  }
}

class ExpenseLocalStore {
  ExpenseLocalStore._();
  static final ExpenseLocalStore instance = ExpenseLocalStore._();

  Future<void> putExpense({
    required String userId,
    required Expense expense,
    required bool synced,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.expensesBox(userId);

    final expenseToSave = Expense(
      expenseId: expense.expenseId,
      userId: expense.userId,
      amount: expense.amount,
      currencyAtEntry: expense.currencyAtEntry,
      exchangeRateAtEntry: expense.exchangeRateAtEntry,
      categoryId: expense.categoryId,
      description: expense.description,
      isFixed: expense.isFixed,
      recurrenceFrequency: expense.recurrenceFrequency,
      recurrenceDay: expense.recurrenceDay,
      autoAddNextOccurrence: expense.autoAddNextOccurrence,
      date: expense.date,
      paymentMethod: expense.paymentMethod,
      receiptUrls: expense.receiptUrls,
      aiCategorized: expense.aiCategorized,
      aiConfidence: expense.aiConfidence,
      createdAt: expense.createdAt,
      updatedAt: expense.updatedAt,
      synced: synced,
    );

    await box.put(
      expenseToSave.expenseId,
      jsonEncode(ExpenseSerialization.toLocalMap(expenseToSave)),
    );
  }

  Future<Expense?> getExpense({
    required String userId,
    required String expenseId,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.expensesBox(userId);
    final raw = box.get(expenseId);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return ExpenseSerialization.fromLocalMap(map);
  }

  Future<void> setExpenseSynced({
    required String userId,
    required String expenseId,
    required bool synced,
  }) async {
    final existing = await getExpense(userId: userId, expenseId: expenseId);
    if (existing == null) return;
    await putExpense(userId: userId, expense: existing, synced: synced);
  }

  Future<List<Expense>> getLatestExpenses({
    required String userId,
    int limit = 30,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.expensesBox(userId);

    final items = box.values.toList();
    final expenses = <Expense>[];
    for (final raw in items) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      expenses.add(ExpenseSerialization.fromLocalMap(map));
    }
    expenses.sort((a, b) => b.date.compareTo(a.date));
    return expenses.take(limit).toList();
  }

  Future<void> enqueueOperation({
    required String userId,
    required ExpenseQueueOperation op,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.expenseQueueBox(userId);
    await box.put(op.opId, jsonEncode(op.toMap()));
  }

  Future<List<ExpenseQueueOperation>> getPendingOperations({
    required String userId,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.expenseQueueBox(userId);
    final ops = <ExpenseQueueOperation>[];
    for (final raw in box.values) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      ops.add(ExpenseQueueOperation.fromMap(map));
    }
    ops.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    return ops;
  }

  Future<void> removeOperation({
    required String userId,
    required String opId,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.expenseQueueBox(userId);
    await box.delete(opId);
  }

  Future<void> deleteExpense({
    required String userId,
    required String expenseId,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.expensesBox(userId);
    await box.delete(expenseId);
  }

  Future<List<Expense>> queryExpenses({
    required String userId,
    DateTime? startInclusive,
    DateTime? endInclusive,
    Currency? currency,
    List<String>? categoryIds,
    String? searchQuery,
  }) async {
    await LocalDb.instance.openForUser(userId);
    final box = LocalDb.instance.expensesBox(userId);
    final q = searchQuery?.trim().toLowerCase();

    final expenses = <Expense>[];
    for (final raw in box.values) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final expense = ExpenseSerialization.fromLocalMap(map);

      if (startInclusive != null && expense.date.isBefore(startInclusive)) {
        continue;
      }
      if (endInclusive != null && expense.date.isAfter(endInclusive)) {
        continue;
      }

      if (currency != null && expense.currencyAtEntry != currency) continue;
      if (categoryIds != null &&
          categoryIds.isNotEmpty &&
          !categoryIds.contains(expense.categoryId)) {
        continue;
      }

      if (q != null && q.isNotEmpty) {
        final desc = (expense.description ?? '').toLowerCase();
        final cat = expense.categoryId.toLowerCase();
        if (!desc.contains(q) && !cat.contains(q)) continue;
      }

      expenses.add(expense);
    }

    expenses.sort((a, b) => b.date.compareTo(a.date));
    return expenses;
  }

  Future<void> enqueueCreate({
    required String userId,
    required Expense expense,
    required int opCreatedAtMs,
  }) async {
    final payload = ExpenseSerialization.toLocalMap(expense);
    final op = ExpenseQueueOperation(
      opId: 'create_${expense.expenseId}_$opCreatedAtMs',
      type: ExpenseOpType.create,
      expenseId: expense.expenseId,
      userId: userId,
      createdAtMs: opCreatedAtMs,
      updatedAtMs: expense.updatedAt.millisecondsSinceEpoch,
      payload: payload,
    );
    await enqueueOperation(userId: userId, op: op);
  }

  Future<void> enqueueUpdate({
    required String userId,
    required Expense expense,
    required int opCreatedAtMs,
  }) async {
    final payload = ExpenseSerialization.toLocalMap(expense);
    final op = ExpenseQueueOperation(
      opId: 'update_${expense.expenseId}_$opCreatedAtMs',
      type: ExpenseOpType.update,
      expenseId: expense.expenseId,
      userId: userId,
      createdAtMs: opCreatedAtMs,
      updatedAtMs: expense.updatedAt.millisecondsSinceEpoch,
      payload: payload,
    );
    await enqueueOperation(userId: userId, op: op);
  }

  Future<void> enqueueDelete({
    required String userId,
    required String expenseId,
    required int opCreatedAtMs,
    required int updatedAtMs,
  }) async {
    final op = ExpenseQueueOperation(
      opId: 'delete_${expenseId}_$opCreatedAtMs',
      type: ExpenseOpType.delete,
      expenseId: expenseId,
      userId: userId,
      createdAtMs: opCreatedAtMs,
      updatedAtMs: updatedAtMs,
      payload: const <String, dynamic>{},
    );
    await enqueueOperation(userId: userId, op: op);
  }
}

