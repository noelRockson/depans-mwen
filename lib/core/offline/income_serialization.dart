import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/enums.dart';
import '../../models/income_model.dart';

class IncomeSerialization {
  static Map<String, dynamic> toLocalMap(Income income) {
    return <String, dynamic>{
      'income_id': income.incomeId,
      'user_id': income.userId,
      'source_label': income.sourceLabel,
      'amount': income.amount,
      'currency': income.currency.code,
      'frequency': income.frequency.code,
      'next_payment_date_ms': income.nextPaymentDate.millisecondsSinceEpoch,
      'is_active': income.isActive,
      'created_at_ms': income.createdAt.millisecondsSinceEpoch,
      'last_updated_ms': income.lastUpdated.millisecondsSinceEpoch,
      'synced': income.synced,
    };
  }

  static Income fromLocalMap(Map<String, dynamic> map) {
    final nextMs = map['next_payment_date_ms'] as num;
    return Income(
      incomeId: map['income_id'] as String,
      userId: map['user_id'] as String,
      sourceLabel: map['source_label'] as String,
      amount: (map['amount'] as num).toDouble(),
      currency: CurrencyCode.fromCode(map['currency'] as String),
      frequency: IncomeFrequencyCode.fromCode(map['frequency'] as String),
      nextPaymentDate: DateTime.fromMillisecondsSinceEpoch(nextMs.toInt()),
      isActive: map['is_active'] as bool? ?? true,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch((map['created_at_ms'] as num).toInt()),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(
        (map['last_updated_ms'] as num).toInt(),
      ),
      synced: (map['synced'] as bool?) ?? false,
    );
  }

  static Map<String, dynamic> toFirestoreMap(Income income) {
    return <String, dynamic>{
      'income_id': income.incomeId,
      'user_id': income.userId,
      'source_label': income.sourceLabel,
      'amount': income.amount,
      'currency': income.currency.code,
      'frequency': income.frequency.code,
      'next_payment_date': Timestamp.fromDate(income.nextPaymentDate),
      'is_active': income.isActive,
      'created_at': Timestamp.fromDate(income.createdAt),
      'last_updated': Timestamp.fromDate(income.lastUpdated),
      // conflict resolution numeric millis
      'last_updated_ms': income.lastUpdated.millisecondsSinceEpoch,
    };
  }

  static Income fromFirestoreDoc({
    required String incomeId,
    required Map<String, dynamic> data,
    required String userId,
  }) {
    final currencyCode = data['currency'] as String;
    final freqCode = data['frequency'] as String;

    final nextVal = data['next_payment_date'];
    final nextPaymentDate = nextVal is Timestamp
        ? nextVal.toDate()
        : nextVal is DateTime
            ? nextVal
            : DateTime.now();

    final createdVal = data['created_at'];
    final createdAt = createdVal is Timestamp
        ? createdVal.toDate()
        : DateTime.now();

    final lastVal = data['last_updated'];
    final lastUpdated = lastVal is Timestamp
        ? lastVal.toDate()
        : DateTime.now();

    return Income(
      incomeId: incomeId,
      userId: userId,
      sourceLabel: data['source_label'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: CurrencyCode.fromCode(currencyCode),
      frequency: IncomeFrequencyCode.fromCode(freqCode),
      nextPaymentDate: nextPaymentDate,
      isActive: data['is_active'] as bool? ?? true,
      createdAt: createdAt,
      lastUpdated: lastUpdated,
      synced: true,
    );
  }
}

