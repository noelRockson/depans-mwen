import 'enums.dart';

class Expense {
  final String expenseId;
  final String userId;
  final double amount;
  final Currency currencyAtEntry;
  final double? exchangeRateAtEntry;
  final String categoryId;
  final String? description;
  final bool isFixed;
  final ExpenseRecurrenceFrequency? recurrenceFrequency;
  final int? recurrenceDay;
  final bool autoAddNextOccurrence;
  final DateTime date;
  final PaymentMethod? paymentMethod;
  final List<String> receiptUrls;
  final bool aiCategorized;
  final double? aiConfidence;
  final DateTime createdAt;
  final DateTime updatedAt;
  bool synced;

  Expense({
    required this.expenseId,
    required this.userId,
    required this.amount,
    required this.currencyAtEntry,
    this.exchangeRateAtEntry,
    required this.categoryId,
    this.description,
    this.isFixed = false,
    this.recurrenceFrequency,
    this.recurrenceDay,
    this.autoAddNextOccurrence = false,
    required this.date,
    this.paymentMethod,
    this.receiptUrls = const [],
    this.aiCategorized = false,
    this.aiConfidence,
    required this.createdAt,
    required this.updatedAt,
    this.synced = false,
  });
}

