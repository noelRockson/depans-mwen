import 'enums.dart';

class Budget {
  final String budgetId;
  final String userId;
  final String name;
  final String? description;
  final double amount;
  final Currency currency;
  final BudgetPeriodType periodType;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> categoryIds;
  final double alertThresholdPercentage;
  final bool rolloverUnused;
  final BudgetStatus status;
  final DateTime createdAt;
  bool synced;

  Budget({
    required this.budgetId,
    required this.userId,
    required this.name,
    this.description,
    required this.amount,
    required this.currency,
    required this.periodType,
    required this.startDate,
    required this.endDate,
    this.categoryIds = const [],
    this.alertThresholdPercentage = 80.0,
    this.rolloverUnused = false,
    this.status = BudgetStatus.active,
    required this.createdAt,
    this.synced = false,
  });
}
