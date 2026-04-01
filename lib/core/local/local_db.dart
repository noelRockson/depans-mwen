import 'package:hive_flutter/hive_flutter.dart';

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  static const _expensesBoxPrefix = 'expenses_';
  static const _expenseQueueBoxPrefix = 'expense_queue_';

  static const _incomesBoxPrefix = 'incomes_';
  static const _incomeQueueBoxPrefix = 'income_queue_';

  static const _budgetsBoxPrefix = 'budgets_';
  static const _budgetQueueBoxPrefix = 'budget_queue_';

  Future<void> init() async {
    await Hive.initFlutter();
  }

  String expensesBoxName(String userId) => '$_expensesBoxPrefix$userId';
  String expenseQueueBoxName(String userId) =>
      '$_expenseQueueBoxPrefix$userId';

  String incomesBoxName(String userId) => '$_incomesBoxPrefix$userId';
  String incomeQueueBoxName(String userId) =>
      '$_incomeQueueBoxPrefix$userId';

  String budgetsBoxName(String userId) => '$_budgetsBoxPrefix$userId';
  String budgetQueueBoxName(String userId) =>
      '$_budgetQueueBoxPrefix$userId';

  Future<void> openForUser(String userId) async {
    await Hive.openBox<String>(expensesBoxName(userId));
    await Hive.openBox<String>(expenseQueueBoxName(userId));
    await Hive.openBox<String>(incomesBoxName(userId));
    await Hive.openBox<String>(incomeQueueBoxName(userId));
    await Hive.openBox<String>(budgetsBoxName(userId));
    await Hive.openBox<String>(budgetQueueBoxName(userId));
  }

  Box<String> expensesBox(String userId) =>
      Hive.box<String>(expensesBoxName(userId));
  Box<String> expenseQueueBox(String userId) =>
      Hive.box<String>(expenseQueueBoxName(userId));

  Box<String> incomesBox(String userId) =>
      Hive.box<String>(incomesBoxName(userId));

  Box<String> incomeQueueBox(String userId) =>
      Hive.box<String>(incomeQueueBoxName(userId));

  Box<String> budgetsBox(String userId) =>
      Hive.box<String>(budgetsBoxName(userId));
  Box<String> budgetQueueBox(String userId) =>
      Hive.box<String>(budgetQueueBoxName(userId));
}

