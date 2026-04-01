import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/enums.dart';
import '../../models/expense_model.dart';

class ExpenseSerialization {
  static Map<String, dynamic> toLocalMap(Expense expense) {
    return <String, dynamic>{
      'expense_id': expense.expenseId,
      'user_id': expense.userId,
      'amount': expense.amount,
      'currency_at_entry': expense.currencyAtEntry.code,
      'exchange_rate_at_entry': expense.exchangeRateAtEntry,
      'category_id': expense.categoryId,
      'description': expense.description,
      'is_fixed': expense.isFixed,
      'recurrence_frequency': expense.recurrenceFrequency?.code,
      'recurrence_day': expense.recurrenceDay,
      'auto_add_next_occurrence': expense.autoAddNextOccurrence,
      'date_ms': expense.date.millisecondsSinceEpoch,
      'payment_method': expense.paymentMethod?.code,
      'receipt_urls': expense.receiptUrls,
      'ai_categorized': expense.aiCategorized,
      'ai_confidence': expense.aiConfidence,
      'created_at_ms': expense.createdAt.millisecondsSinceEpoch,
      'updated_at_ms': expense.updatedAt.millisecondsSinceEpoch,
      // local-only flag
      'synced': expense.synced,
    };
  }

  static Expense fromLocalMap(Map<String, dynamic> map) {
    return Expense(
      expenseId: (map['expense_id'] ?? map['expenseId']) as String,
      userId: (map['user_id'] ?? map['userId']) as String,
      amount: (map['amount'] as num).toDouble(),
      currencyAtEntry: CurrencyCode.fromCode(
        (map['currency_at_entry'] ?? map['currencyAtEntry']) as String,
      ),
      exchangeRateAtEntry: map['exchange_rate_at_entry'] == null
          ? null
          : (map['exchange_rate_at_entry'] as num).toDouble(),
      categoryId: (map['category_id'] ?? map['categoryId']) as String,
      description: map['description'] as String?,
      isFixed: (map['is_fixed'] ?? map['isFixed']) as bool,
      recurrenceFrequency:
          ExpenseRecurrenceFrequencyCode.fromCode(
        map['recurrence_frequency'],
      ),
      recurrenceDay: map['recurrence_day'] == null
          ? null
          : (map['recurrence_day'] as num).toInt(),
      autoAddNextOccurrence:
          (map['auto_add_next_occurrence'] ?? map['autoAddNextOccurrence'])
              as bool,
      date: DateTime.fromMillisecondsSinceEpoch(map['date_ms'] as int),
      paymentMethod: PaymentMethodCode.fromCode(
        map['payment_method'],
      ),
      receiptUrls: (map['receipt_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      aiCategorized: (map['ai_categorized'] ?? map['aiCategorized']) as bool,
      aiConfidence: map['ai_confidence'] == null
          ? null
          : (map['ai_confidence'] as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at_ms'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at_ms'] as int),
      synced: (map['synced'] as bool?) ?? false,
    );
  }

  static Map<String, dynamic> toFirestoreMap(Expense expense) {
    return <String, dynamic>{
      'expense_id': expense.expenseId,
      'user_id': expense.userId,
      'amount': expense.amount,
      'currency_at_entry': expense.currencyAtEntry.code,
      'exchange_rate_at_entry': expense.exchangeRateAtEntry,
      'category_id': expense.categoryId,
      'description': expense.description,
      'is_fixed': expense.isFixed,
      'recurrence_frequency': expense.recurrenceFrequency?.code,
      'recurrence_day': expense.recurrenceDay,
      'auto_add_next_occurrence': expense.autoAddNextOccurrence,
      'date': Timestamp.fromDate(expense.date),
      'payment_method': expense.paymentMethod?.code,
      'receipt_urls': expense.receiptUrls,
      'ai_categorized': expense.aiCategorized,
      'ai_confidence': expense.aiConfidence,
      'created_at': Timestamp.fromDate(expense.createdAt),
      'updated_at': Timestamp.fromDate(expense.updatedAt),
      // conflict resolution helper (numeric millis)
      'updated_at_ms': expense.updatedAt.millisecondsSinceEpoch,
    };
  }

  static Expense fromFirestoreDoc(
    String expenseId,
    Map<String, dynamic> data, {
    required String userId,
  }) {
    final dynamic dateVal = data['date'];
    final DateTime date;
    if (dateVal is Timestamp) {
      date = dateVal.toDate();
    } else if (dateVal is DateTime) {
      date = dateVal;
    } else {
      date = DateTime.now();
    }

    final dynamic createdAtVal = data['created_at'];
    final DateTime createdAt;
    if (createdAtVal is Timestamp) {
      createdAt = createdAtVal.toDate();
    } else {
      createdAt = DateTime.now();
    }

    final dynamic updatedAtVal = data['updated_at'];
    final DateTime updatedAt;
    if (updatedAtVal is Timestamp) {
      updatedAt = updatedAtVal.toDate();
    } else {
      final ms = (data['updated_at_ms'] as num?)?.toInt();
      updatedAt = ms == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(ms);
    }

    return Expense(
      expenseId: expenseId,
      userId: userId,
      amount: (data['amount'] as num).toDouble(),
      currencyAtEntry: CurrencyCode.fromCode(data['currency_at_entry'] as String),
      exchangeRateAtEntry: data['exchange_rate_at_entry'] == null
          ? null
          : (data['exchange_rate_at_entry'] as num).toDouble(),
      categoryId: data['category_id'] as String,
      description: data['description'] as String?,
      isFixed: data['is_fixed'] as bool? ?? false,
      recurrenceFrequency:
          ExpenseRecurrenceFrequencyCode.fromCode(data['recurrence_frequency'] as String?),
      recurrenceDay: data['recurrence_day'] == null
          ? null
          : (data['recurrence_day'] as num).toInt(),
      autoAddNextOccurrence:
          data['auto_add_next_occurrence'] as bool? ?? false,
      date: date,
      paymentMethod: PaymentMethodCode.fromCode(data['payment_method'] as String?),
      receiptUrls: (data['receipt_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      aiCategorized: data['ai_categorized'] as bool? ?? false,
      aiConfidence: data['ai_confidence'] == null
          ? null
          : (data['ai_confidence'] as num).toDouble(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      synced: true,
    );
  }
}

