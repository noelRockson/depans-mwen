import 'enums.dart';

class Income {
  final String incomeId;
  final String userId;
  final String sourceLabel;
  final double amount;
  final Currency currency;
  final IncomeFrequency frequency;
  final DateTime nextPaymentDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime lastUpdated;
  bool synced;

  Income({
    required this.incomeId,
    required this.userId,
    required this.sourceLabel,
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.nextPaymentDate,
    this.isActive = true,
    required this.createdAt,
    required this.lastUpdated,
    this.synced = false,
  });
}

