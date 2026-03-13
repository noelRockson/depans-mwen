enum Currency {
  htg,
  usd,
}

extension CurrencyCode on Currency {
  String get code {
    switch (this) {
      case Currency.htg:
        return 'HTG';
      case Currency.usd:
        return 'USD';
    }
  }

  static Currency fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'USD':
        return Currency.usd;
      case 'HTG':
      default:
        return Currency.htg;
    }
  }
}

enum IncomeFrequency {
  biWeekly,
  monthly,
}

extension IncomeFrequencyCode on IncomeFrequency {
  String get code {
    switch (this) {
      case IncomeFrequency.biWeekly:
        return 'Bi-weekly';
      case IncomeFrequency.monthly:
        return 'Monthly';
    }
  }

  static IncomeFrequency fromCode(String code) {
    switch (code) {
      case 'Bi-weekly':
        return IncomeFrequency.biWeekly;
      case 'Monthly':
      default:
        return IncomeFrequency.monthly;
    }
  }
}

enum ExpenseRecurrenceFrequency {
  weekly,
  biWeekly,
  monthly,
  quarterly,
  annual,
}

extension ExpenseRecurrenceFrequencyCode on ExpenseRecurrenceFrequency {
  String get code {
    switch (this) {
      case ExpenseRecurrenceFrequency.weekly:
        return 'Weekly';
      case ExpenseRecurrenceFrequency.biWeekly:
        return 'Bi-weekly';
      case ExpenseRecurrenceFrequency.monthly:
        return 'Monthly';
      case ExpenseRecurrenceFrequency.quarterly:
        return 'Quarterly';
      case ExpenseRecurrenceFrequency.annual:
        return 'Annual';
    }
  }

  static ExpenseRecurrenceFrequency? fromCode(String? code) {
    switch (code) {
      case 'Weekly':
        return ExpenseRecurrenceFrequency.weekly;
      case 'Bi-weekly':
        return ExpenseRecurrenceFrequency.biWeekly;
      case 'Monthly':
        return ExpenseRecurrenceFrequency.monthly;
      case 'Quarterly':
        return ExpenseRecurrenceFrequency.quarterly;
      case 'Annual':
        return ExpenseRecurrenceFrequency.annual;
      default:
        return null;
    }
  }
}

enum PaymentMethod {
  cash,
  card,
  mobileMoney,
  bankTransfer,
  other,
}

extension PaymentMethodCode on PaymentMethod {
  String get code {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.mobileMoney:
        return 'Mobile_Money';
      case PaymentMethod.bankTransfer:
        return 'Bank_Transfer';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  static PaymentMethod? fromCode(String? code) {
    switch (code) {
      case 'Cash':
        return PaymentMethod.cash;
      case 'Card':
        return PaymentMethod.card;
      case 'Mobile_Money':
        return PaymentMethod.mobileMoney;
      case 'Bank_Transfer':
        return PaymentMethod.bankTransfer;
      case 'Other':
        return PaymentMethod.other;
      default:
        return null;
    }
  }
}

