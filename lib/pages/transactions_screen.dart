import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../core/offline/expense_local_store.dart';
import '../core/offline/expense_sync_service.dart';
import '../core/offline/income_local_store.dart';
import '../core/offline/income_sync_service.dart';
import '../models/enums.dart';
import '../models/expense_model.dart';
import '../models/income_model.dart';
import '../services/auth_service.dart';
import 'add_expense_bottom_sheet.dart';
import 'add_income_bottom_sheet.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  String _period = 'month'; // today|week|month|quarter|year|custom
  String _currencyFilter = 'all'; // all|HTG|USD
  String _type = 'all'; // all|expenses|incomes
  List<String> _selectedCategoryIds = const [];

  DateTime? _customStart;
  DateTime? _customEnd;

  bool _loading = true;
  List<_TxnItem> _filtered = const [];
  int _page = 0;
  final int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_loading) return;
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (current + 400 >= max) {
      if ((_page + 1) * _pageSize < _filtered.length) {
        setState(() => _page += 1);
      }
    }
  }

  DateTimeRange _resolveRange() {
    final now = DateTime.now();
    DateTime startOfDay(DateTime d) =>
        DateTime(d.year, d.month, d.day);
    DateTime endOfDay(DateTime d) =>
        DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

    switch (_period) {
      case 'today':
        return DateTimeRange(start: startOfDay(now), end: endOfDay(now));
      case 'week':
        {
          final start = startOfDay(now.subtract(Duration(days: now.weekday - 1)));
          return DateTimeRange(start: start, end: endOfDay(now));
        }
      case 'quarter':
        {
          final quarterIndex = ((now.month - 1) / 3).floor();
          final startMonth = quarterIndex * 3 + 1;
          final start = startOfDay(DateTime(now.year, startMonth, 1));
          final endDate = DateTime(now.year, startMonth + 3, 0);
          final end = endOfDay(endDate);
          return DateTimeRange(start: start, end: end);
        }
      case 'year':
        return DateTimeRange(
          start: startOfDay(DateTime(now.year, 1, 1)),
          end: endOfDay(now),
        );
      case 'custom':
        return DateTimeRange(
          start: startOfDay(_customStart ?? now.subtract(const Duration(days: 30))),
          end: endOfDay(_customEnd ?? now),
        );
      case 'month':
      default:
        final start = startOfDay(DateTime(now.year, now.month, 1));
        final endDate = DateTime(now.year, now.month + 1, 0);
        final end = endOfDay(endDate);
        return DateTimeRange(start: start, end: end);
    }
  }

  String? _userId() => AuthService.instance.user.value?.id;

  Future<void> _load() async {
    setState(() => _loading = true);

    final userId = _userId();
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    await ExpenseSyncService.instance.syncNow().catchError((_) {});
    await IncomeSyncService.instance.syncNow().catchError((_) {});

    final range = _resolveRange();
    final currency = _currencyFilter == 'HTG'
        ? Currency.htg
        : _currencyFilter == 'USD'
        ? Currency.usd
        : null;

    final searchQuery = _searchController.text;

    final txns = <_TxnItem>[];

    final normalizedSearch =
        searchQuery.trim().isEmpty ? null : searchQuery.trim();

    if (_type == 'expenses' || _type == 'all') {
      final expenses = await ExpenseLocalStore.instance.queryExpenses(
        userId: userId,
        startInclusive: range.start,
        endInclusive: range.end,
        currency: currency,
        categoryIds:
            _selectedCategoryIds.isEmpty ? null : _selectedCategoryIds,
        searchQuery: normalizedSearch,
      );
      txns.addAll(expenses.map((e) => _TxnItem.fromExpense(e)));
    }

    if (_type == 'incomes' || _type == 'all') {
      final incomes = await IncomeLocalStore.instance.queryIncomes(
        userId: userId,
        startInclusive: range.start,
        endInclusive: range.end,
        currency: currency,
        searchQuery: normalizedSearch,
      );
      txns.addAll(incomes.map((i) => _TxnItem.fromIncome(i)));
    }

    txns.sort((a, b) => b.date.compareTo(a.date));
    setState(() {
      _filtered = txns;
      _page = 0;
      _loading = false;
    });
  }

  void _onFiltersChanged() => _load();

  @override
  Widget build(BuildContext context) {
    final visibleCount = _pageSize * (_page + 1);
    final slice = _filtered.take(visibleCount).toList();

    return Container(
      color: const Color(0xFFF0F4F8),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    tr('transactions.title'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  _SoftIconButton(
                    icon: Icons.tune_rounded,
                    onTap: () async {
                      if (_type == 'incomes') return;
                      final selected = await showModalBottomSheet<List<String>>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) =>
                            _CategoryPicker(initial: _selectedCategoryIds),
                      );
                      if (selected == null) return;
                      setState(() => _selectedCategoryIds = selected);
                      _onFiltersChanged();
                    },
                  ),
                ],
              ),
            ),

            // ── Filters ───────────────────────────────────────────
            _buildFilters(),

            // ── List ─────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : slice.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            size: 48,
                            color: Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            tr('transactions.empty'),
                            style: const TextStyle(
                              color: Colors.black45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      itemCount: slice.length,
                      itemBuilder: (context, index) {
                        final txn = slice[index];
                        if (txn.kind == _TxnKind.expense) {
                          final expense = txn.expense!;
                          final category = _mockCategoryFor(expense.categoryId);
                          return _TransactionCard(
                            expense: expense,
                            category: category,
                            onEdit: () async {
                              final updated =
                                  await showModalBottomSheet<Expense>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => AddExpenseBottomSheet(
                                  initialExpense: expense,
                                ),
                              );
                              if (updated != null && mounted) {
                                await _load();
                              }
                            },
                            onDelete: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: Text(tr('add_expense.delete_confirm_title')),
                                  content: Text(tr('add_expense.delete_confirm_body')),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: Text(tr('common.cancel')),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: Text(
                                        tr('common.delete'),
                                        style: const TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;

                              final userId = _userId();
                              if (userId == null) return;
                              final nowMs =
                                  DateTime.now().millisecondsSinceEpoch;

                              await ExpenseLocalStore.instance.deleteExpense(
                                userId: userId,
                                expenseId: expense.expenseId,
                              );
                              await ExpenseLocalStore.instance
                                  .enqueueDelete(
                                userId: userId,
                                expenseId: expense.expenseId,
                                opCreatedAtMs: nowMs,
                                updatedAtMs: nowMs,
                              );
                              ExpenseSyncService.instance
                                  .syncNow()
                                  .catchError((_) {});
                              if (mounted) await _load();
                            },
                            formatDate: _formatDate,
                            formatTime: _formatTime,
                          );
                        }

                        final income = txn.income!;
                        return _IncomeTransactionCard(
                          income: income,
                          onEdit: () async {
                            final updated =
                                await showModalBottomSheet<Income>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => AddIncomeBottomSheet(
                                initialIncome: income,
                              ),
                            );
                            if (updated != null && mounted) {
                              await _load();
                            }
                          },
                          onDelete: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: Text(tr('add_income.deleted')),
                                content: Text(tr('add_expense.delete_confirm_body')),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: Text(tr('common.cancel')),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: Text(
                                      tr('common.delete'),
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirm != true) return;

                            final userId = _userId();
                            if (userId == null) return;
                            final nowMs =
                                DateTime.now().millisecondsSinceEpoch;

                            await IncomeLocalStore.instance.deleteIncome(
                              userId: userId,
                              incomeId: income.incomeId,
                            );
                            await IncomeLocalStore.instance.enqueueDelete(
                              userId: userId,
                              incomeId: income.incomeId,
                              opCreatedAtMs: nowMs,
                              updatedAtMs: nowMs,
                            );
                            IncomeSyncService.instance
                                .syncNow()
                                .catchError((_) {});
                            if (mounted) await _load();
                          },
                          formatDate: _formatDate,
                          formatTime: _formatTime,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter panel ─────────────────────────────────────────────────────────

  Widget _buildFilters() {
    final periodLabels = {
      'today': tr('common.today'),
      'week': tr('common.week'),
      'month': tr('common.month'),
      'quarter': tr('common.quarter'),
      'year': tr('common.year'),
      'custom': tr('common.custom'),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period dropdown styled as a soft white pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _period,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.black54,
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                items: periodLabels.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _period = v);
                  _onFiltersChanged();
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Currency + type pills in a scrollable row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _pill(
                  'all',
                  tr('common.all'),
                  _currencyFilter,
                  (v) => setState(() => _currencyFilter = v),
                ),
                const SizedBox(width: 6),
                _pill(
                  'HTG',
                  'HTG',
                  _currencyFilter,
                  (v) => setState(() => _currencyFilter = v),
                ),
                const SizedBox(width: 6),
                _pill(
                  'USD',
                  'USD',
                  _currencyFilter,
                  (v) => setState(() => _currencyFilter = v),
                ),
                const SizedBox(width: 14),
                Container(width: 1, height: 20, color: Colors.black12),
                const SizedBox(width: 14),
                _pill('all', tr('transactions.filter_all'), _type, (v) => setState(() => _type = v)),
                const SizedBox(width: 6),
                _pill(
                  'expenses',
                  tr('transactions.filter_expenses'),
                  _type,
                  (v) => setState(() => _type = v),
                ),
                const SizedBox(width: 6),
                _pill(
                  'incomes',
                  tr('transactions.filter_incomes'),
                  _type,
                  (v) => setState(() => _type = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, color: Colors.black38),
                hintText: 'Rechercher...',
                hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 300),
                  _onFiltersChanged,
                );
              },
            ),
          ),

          // Active category filter badge (expenses only)
          if (_selectedCategoryIds.isNotEmpty && _type != 'incomes')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_selectedCategoryIds.length} catégorie(s)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategoryIds = const []);
                      _onFiltersChanged();
                    },
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(
    String value,
    String label,
    String current,
    ValueChanged<String> onChanged,
  ) {
    final selected = current == value;
    return GestureDetector(
      onTap: () {
        onChanged(value);
        _onFiltersChanged();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(selected ? 0.08 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  _MockCategory _mockCategoryFor(String categoryId) {
    return _mockCategories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => const _MockCategory(
        id: 'other',
        label: 'Autre',
        icon: Icons.help_outline,
        color: 0xFF795548,
      ),
    );
  }

  List<_MockCategory> get _mockCategories => const [
    _MockCategory(
      id: 'food',
      label: 'Nourriture',
      icon: Icons.restaurant,
      color: 0xFF4CAF50,
    ),
    _MockCategory(
      id: 'transport',
      label: 'Transport',
      icon: Icons.directions_car,
      color: 0xFF2196F3,
    ),
    _MockCategory(
      id: 'shopping',
      label: 'Shopping',
      icon: Icons.shopping_cart,
      color: 0xFFFF9800,
    ),
    _MockCategory(
      id: 'bills',
      label: 'Factures',
      icon: Icons.lightbulb_outline,
      color: 0xFFFFC107,
    ),
    _MockCategory(
      id: 'health',
      label: 'Santé',
      icon: Icons.favorite,
      color: 0xFFF44336,
    ),
    _MockCategory(
      id: 'education',
      label: 'Éducation',
      icon: Icons.book,
      color: 0xFF9C27B0,
    ),
    _MockCategory(
      id: 'entertainment',
      label: 'Loisirs',
      icon: Icons.music_note,
      color: 0xFF3F51B5,
    ),
    _MockCategory(
      id: 'other',
      label: 'Autre',
      icon: Icons.add,
      color: 0xFF795548,
    ),
  ];

  String _formatDate(DateTime d) {
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

enum _TxnKind {
  expense,
  income,
}

class _TxnItem {
  _TxnItem._({
    required this.kind,
    this.expense,
    this.income,
  }) : assert(kind == _TxnKind.expense ? expense != null : true),
       assert(kind == _TxnKind.income ? income != null : true);

  final _TxnKind kind;
  final Expense? expense;
  final Income? income;

  DateTime get date => kind == _TxnKind.expense
      ? expense!.date
      : income!.nextPaymentDate;

  static _TxnItem fromExpense(Expense expense) {
    return _TxnItem._(kind: _TxnKind.expense, expense: expense);
  }

  static _TxnItem fromIncome(Income income) {
    return _TxnItem._(kind: _TxnKind.income, income: income);
  }
}

// ── Transaction card ─────────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  final Expense expense;
  final _MockCategory category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(DateTime) formatDate;
  final String Function(DateTime) formatTime;

  const _TransactionCard({
    required this.expense,
    required this.category,
    required this.onEdit,
    required this.onDelete,
    required this.formatDate,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Category icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color(category.color).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(category.icon, color: Color(category.color), size: 22),
          ),
          const SizedBox(width: 12),

          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${expense.description ?? 'Aucune note'} • '
                  '${formatDate(expense.date)} ${formatTime(expense.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Amount + action icons
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${expense.amount.toStringAsFixed(2)} ${expense.currencyAtEntry.code}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionIcon(
                    icon: Icons.edit_outlined,
                    color: Colors.black45,
                    tooltip: 'Modifier',
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 4),
                  _ActionIcon(
                    icon: Icons.delete_outline,
                    color: Colors.red,
                    tooltip: 'Supprimer',
                    onTap: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Income transaction card ───────────────────────────────────────────────

class _IncomeTransactionCard extends StatelessWidget {
  final Income income;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(DateTime) formatDate;
  final String Function(DateTime) formatTime;

  const _IncomeTransactionCard({
    required this.income,
    required this.onEdit,
    required this.onDelete,
    required this.formatDate,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Income icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance_wallet,
                color: Colors.green, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  income.sourceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${income.frequency.code} • '
                  '${formatDate(income.nextPaymentDate)} ${formatTime(income.nextPaymentDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${income.amount.toStringAsFixed(2)} ${income.currency.code}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionIcon(
                    icon: Icons.edit,
                    color: Colors.blue,
                    tooltip: 'Modifier',
                    onTap: onEdit,
                  ),
                  _ActionIcon(
                    icon: Icons.delete,
                    color: Colors.red,
                    tooltip: 'Supprimer',
                    onTap: onDelete,
                  ),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ── Soft icon button (identical to Dashboard's _SoftIconButton) ──────────────

class _SoftIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SoftIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black87, size: 22),
      ),
    );
  }
}

// ── Category picker bottom sheet ─────────────────────────────────────────────

class _CategoryPicker extends StatefulWidget {
  const _CategoryPicker({required this.initial});

  final List<String> initial;

  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  late List<String> _selected;

  final List<_MockCategory> _categories = const [
    _MockCategory(
      id: 'food',
      label: 'Nourriture',
      icon: Icons.restaurant,
      color: 0xFF4CAF50,
    ),
    _MockCategory(
      id: 'transport',
      label: 'Transport',
      icon: Icons.directions_car,
      color: 0xFF2196F3,
    ),
    _MockCategory(
      id: 'shopping',
      label: 'Shopping',
      icon: Icons.shopping_cart,
      color: 0xFFFF9800,
    ),
    _MockCategory(
      id: 'bills',
      label: 'Factures',
      icon: Icons.lightbulb_outline,
      color: 0xFFFFC107,
    ),
    _MockCategory(
      id: 'health',
      label: 'Santé',
      icon: Icons.favorite,
      color: 0xFFF44336,
    ),
    _MockCategory(
      id: 'education',
      label: 'Éducation',
      icon: Icons.book,
      color: 0xFF9C27B0,
    ),
    _MockCategory(
      id: 'entertainment',
      label: 'Loisirs',
      icon: Icons.music_note,
      color: 0xFF3F51B5,
    ),
    _MockCategory(
      id: 'other',
      label: 'Autre',
      icon: Icons.add,
      color: 0xFF795548,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF0F4F8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Filtrer par catégories',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (context, index) {
                    final c = _categories[index];
                    final checked = _selected.contains(c.id);
                    return CheckboxListTile(
                      value: checked,
                      secondary: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Color(c.color).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(c.icon, color: Color(c.color), size: 18),
                      ),
                      title: Text(
                        c.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            if (!_selected.contains(c.id)) _selected.add(c.id);
                          } else {
                            _selected.remove(c.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: const BorderSide(color: Colors.black12),
                      ),
                      onPressed: () => Navigator.of(context).pop(const []),
                      child: const Text(
                        'Toutes',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.of(context).pop(_selected),
                      child: const Text(
                        'Appliquer',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _MockCategory {
  final String id;
  final String label;
  final IconData icon;
  final int color;

  const _MockCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}
