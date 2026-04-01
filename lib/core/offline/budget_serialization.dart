import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/enums.dart';
import '../../models/budget_model.dart';

class BudgetSerialization {
  static Map<String, dynamic> toLocalMap(Budget b) {
    return <String, dynamic>{
      'budget_id': b.budgetId,
      'user_id': b.userId,
      'name': b.name,
      'description': b.description,
      'amount': b.amount,
      'currency': b.currency.code,
      'period_type': b.periodType.code,
      'start_date_ms': b.startDate.millisecondsSinceEpoch,
      'end_date_ms': b.endDate.millisecondsSinceEpoch,
      'category_ids': b.categoryIds,
      'alert_threshold_percentage': b.alertThresholdPercentage,
      'rollover_unused': b.rolloverUnused,
      'status': b.status.code,
      'created_at_ms': b.createdAt.millisecondsSinceEpoch,
      'synced': b.synced,
    };
  }

  static Budget fromLocalMap(Map<String, dynamic> map) {
    return Budget(
      budgetId: map['budget_id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      amount: (map['amount'] as num).toDouble(),
      currency: CurrencyCode.fromCode(map['currency'] as String),
      periodType: BudgetPeriodTypeCode.fromCode(map['period_type'] as String),
      startDate: DateTime.fromMillisecondsSinceEpoch(map['start_date_ms'] as int),
      endDate: DateTime.fromMillisecondsSinceEpoch(map['end_date_ms'] as int),
      categoryIds: (map['category_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      alertThresholdPercentage:
          (map['alert_threshold_percentage'] as num?)?.toDouble() ?? 80.0,
      rolloverUnused: (map['rollover_unused'] as bool?) ?? false,
      status: BudgetStatusCode.fromCode(map['status'] as String),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at_ms'] as int),
      synced: (map['synced'] as bool?) ?? false,
    );
  }

  static Map<String, dynamic> toFirestoreMap(Budget b) {
    return <String, dynamic>{
      'budget_id': b.budgetId,
      'user_id': b.userId,
      'name': b.name,
      'description': b.description,
      'amount': b.amount,
      'currency': b.currency.code,
      'period_type': b.periodType.code,
      'start_date': Timestamp.fromDate(b.startDate),
      'end_date': Timestamp.fromDate(b.endDate),
      'category_ids': b.categoryIds,
      'alert_threshold_percentage': b.alertThresholdPercentage,
      'rollover_unused': b.rolloverUnused,
      'status': b.status.code,
      'created_at': Timestamp.fromDate(b.createdAt),
      'created_at_ms': b.createdAt.millisecondsSinceEpoch,
    };
  }

  static Budget fromFirestoreDoc(
    String budgetId,
    Map<String, dynamic> data, {
    required String userId,
  }) {
    DateTime ts(dynamic val, [int? fallbackMs]) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (fallbackMs != null) {
        return DateTime.fromMillisecondsSinceEpoch(fallbackMs);
      }
      return DateTime.now();
    }

    return Budget(
      budgetId: budgetId,
      userId: userId,
      name: data['name'] as String,
      description: data['description'] as String?,
      amount: (data['amount'] as num).toDouble(),
      currency: CurrencyCode.fromCode(data['currency'] as String),
      periodType: BudgetPeriodTypeCode.fromCode(data['period_type'] as String),
      startDate: ts(data['start_date']),
      endDate: ts(data['end_date']),
      categoryIds: (data['category_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      alertThresholdPercentage:
          (data['alert_threshold_percentage'] as num?)?.toDouble() ?? 80.0,
      rolloverUnused: (data['rollover_unused'] as bool?) ?? false,
      status: BudgetStatusCode.fromCode(
        (data['status'] as String?) ?? 'Active',
      ),
      createdAt: ts(
        data['created_at'],
        (data['created_at_ms'] as num?)?.toInt(),
      ),
      synced: true,
    );
  }
}
