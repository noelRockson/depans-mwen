import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../models/expense_model.dart';
import '../models/budget_model.dart';
import '../models/enums.dart';
import '../services/auth_service.dart';
import '../services/exchange_rate_service.dart';
import '../core/offline/expense_local_store.dart';
import '../core/offline/expense_sync_service.dart';
import '../core/offline/income_local_store.dart';
import '../core/offline/income_sync_service.dart';
import '../core/offline/budget_local_store.dart';
import 'add_expense_bottom_sheet.dart';
import 'transactions_screen.dart';
import 'income_management_screen.dart';
import 'budgets_screen.dart';
import 'profile_screen.dart';

enum _DashboardCurrencyView { combined, split }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _MonthTotals {
  const _MonthTotals({
    required this.revHtg,
    required this.revUsd,
    required this.expHtg,
    required this.expUsd,
  });

  final double revHtg;
  final double revUsd;
  final double expHtg;
  final double expUsd;
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _exchangeRateService = const ExchangeRateService();
  _DashboardCurrencyView _view = _DashboardCurrencyView.combined;
  int _selectedTab = 0;

  /// When false (default), monetary amounts on balance cards are masked.
  bool _amountsVisible = false;

  String? _totalsUserId;
  _MonthTotals? _lastMonthTotals;
  bool _isRefreshingTotals = false;
  bool _refreshQueued = false;
  Timer? _realtimeRefreshDebounce;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _expensesRealtimeSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _incomesRealtimeSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _budgetsRealtimeSub;
  List<Expense> _recentExpenses = const <Expense>[];
  bool _recentLoaded = false;
  bool _isRefreshingRecent = false;
  bool _recentRefreshQueued = false;
  List<Budget> _activeBudgets = const <Budget>[];
  bool _budgetsLoaded = false;
  bool _isRefreshingBudgets = false;
  bool _budgetsRefreshQueued = false;

  Future<_MonthTotals> _computeMonthTotals(String userId) async {
    // Best-effort sync; never block the dashboard if Firestore is unreachable.
    try {
      await ExpenseSyncService.instance.syncNow();
    } catch (_) {}
    try {
      await IncomeSyncService.instance.syncNow();
    } catch (_) {}

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);

    try {
      final expenses = await ExpenseLocalStore.instance.queryExpenses(
        userId: userId,
        startInclusive: start,
        endInclusive: end,
      );
      var expHtg = 0.0;
      var expUsd = 0.0;
      for (final e in expenses) {
        if (e.currencyAtEntry == Currency.htg) {
          expHtg += e.amount;
        } else {
          expUsd += e.amount;
        }
      }

      final incomes = await IncomeLocalStore.instance.queryIncomes(
        userId: userId,
        startInclusive: start,
        endInclusive: end,
      );
      var revHtg = 0.0;
      var revUsd = 0.0;
      for (final i in incomes) {
        if (!i.isActive) continue;
        if (i.currency == Currency.htg) {
          revHtg += i.amount;
        } else {
          revUsd += i.amount;
        }
      }

      return _MonthTotals(
        revHtg: revHtg,
        revUsd: revUsd,
        expHtg: expHtg,
        expUsd: expUsd,
      );
    } catch (_) {
      return const _MonthTotals(
        revHtg: 0,
        revUsd: 0,
        expHtg: 0,
        expUsd: 0,
      );
    }
  }

  void _bindTotalsForUser(String userId) {
    if (_totalsUserId == userId) return;
    _totalsUserId = userId;
    _lastMonthTotals = null;
    _recentLoaded = false;
    _recentExpenses = const <Expense>[];
    _budgetsLoaded = false;
    _activeBudgets = const <Budget>[];
    _startRealtimeListeners(userId);
    unawaited(_refreshMonthTotals());
    unawaited(_refreshRecentExpenses());
    unawaited(_refreshActiveBudgets());
  }

  Future<void> _refreshMonthTotals() async {
    final id = AuthService.instance.user.value?.id;
    if (id == null) return;
    if (_isRefreshingTotals) {
      _refreshQueued = true;
      return;
    }

    _isRefreshingTotals = true;
    try {
      final totals = await _computeMonthTotals(id);
      if (!mounted) return;
      setState(() {
        _lastMonthTotals = totals;
      });
    } finally {
      _isRefreshingTotals = false;
      if (_refreshQueued) {
        _refreshQueued = false;
        unawaited(_refreshMonthTotals());
      }
    }
  }

  Future<void> _refreshRecentExpenses() async {
    if (_isRefreshingRecent) {
      _recentRefreshQueued = true;
      return;
    }
    _isRefreshingRecent = true;
    try {
      final recent = await ExpenseSyncService.instance.getLatestLocalExpenses(
        limit: 5,
      );
      if (!mounted) return;
      setState(() {
        _recentExpenses = recent;
        _recentLoaded = true;
      });
    } finally {
      _isRefreshingRecent = false;
      if (_recentRefreshQueued) {
        _recentRefreshQueued = false;
        unawaited(_refreshRecentExpenses());
      }
    }
  }

  Future<void> _refreshActiveBudgets() async {
    final userId = AuthService.instance.user.value?.id;
    if (userId == null) return;
    if (_isRefreshingBudgets) {
      _budgetsRefreshQueued = true;
      return;
    }
    _isRefreshingBudgets = true;
    try {
      final budgets = await BudgetLocalStore.instance.queryBudgets(
        userId: userId,
        status: BudgetStatus.active,
      );
      final active = budgets
          .where((b) => b.endDate.isAfter(DateTime.now()))
          .take(3)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _activeBudgets = active;
        _budgetsLoaded = true;
      });
    } finally {
      _isRefreshingBudgets = false;
      if (_budgetsRefreshQueued) {
        _budgetsRefreshQueued = false;
        unawaited(_refreshActiveBudgets());
      }
    }
  }

  void _startRealtimeListeners(String userId) {
    _expensesRealtimeSub?.cancel();
    _incomesRealtimeSub?.cancel();
    _budgetsRealtimeSub?.cancel();

    final baseRef = FirebaseFirestore.instance.collection('users').doc(userId);
    _expensesRealtimeSub = baseRef.collection('expenses').snapshots().listen(
      (_) => _scheduleRealtimeRefresh(),
      onError: (_) {},
    );
    _incomesRealtimeSub = baseRef.collection('incomes').snapshots().listen(
      (_) => _scheduleRealtimeRefresh(),
      onError: (_) {},
    );
    _budgetsRealtimeSub = baseRef.collection('budgets').snapshots().listen(
      (_) => _scheduleRealtimeRefresh(),
      onError: (_) {},
    );
  }

  void _scheduleRealtimeRefresh() {
    _realtimeRefreshDebounce?.cancel();
    _realtimeRefreshDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      unawaited(_refreshMonthTotals());
      unawaited(_refreshRecentExpenses());
      unawaited(_refreshActiveBudgets());
    });
  }

  void _stopRealtimeListeners() {
    _realtimeRefreshDebounce?.cancel();
    _expensesRealtimeSub?.cancel();
    _incomesRealtimeSub?.cancel();
    _budgetsRealtimeSub?.cancel();
    _expensesRealtimeSub = null;
    _incomesRealtimeSub = null;
    _budgetsRealtimeSub = null;
  }

  void _onAuthUserChanged() {
    final u = AuthService.instance.user.value;
    if (u == null) {
      _stopRealtimeListeners();
      setState(() {
        _totalsUserId = null;
        _lastMonthTotals = null;
        _recentLoaded = false;
        _recentExpenses = const <Expense>[];
        _budgetsLoaded = false;
        _activeBudgets = const <Budget>[];
      });
      return;
    }
    _bindTotalsForUser(u.id);
  }

  @override
  void initState() {
    super.initState();
    AuthService.instance.user.addListener(_onAuthUserChanged);
    _onAuthUserChanged();
  }

  @override
  void dispose() {
    _stopRealtimeListeners();
    AuthService.instance.user.removeListener(_onAuthUserChanged);
    super.dispose();
  }

  static String _formatAmount(double v, String code) =>
      '${v.toStringAsFixed(2)} $code';

  static String _maskAmount() => '••••••';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: AuthService.instance.user,
      builder: (context, user, _) {
        if (user == null) {
          return const Scaffold(
            backgroundColor: Color(0xFFF0F4F8),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF0F4F8),
          extendBody: true,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                _buildBody(user),
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: _buildFloatingNavBar(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(UserModel user) {
    if (_selectedTab == 1) {
      return const TransactionsScreen();
    }
    if (_selectedTab == 2) {
      return const BudgetsScreen();
    }
    if (_selectedTab == 3) {
      return const ProfileScreen();
    }

    return ListView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
      children: [
        _buildHeader(user),
        const SizedBox(height: 24),
        _buildBalanceOverview(),
        const SizedBox(height: 28),
        _buildQuickActions(),
        const SizedBox(height: 28),
        _buildRecentTransactions(),
        const SizedBox(height: 28),
        _buildActiveBudgets(),
        const SizedBox(height: 28),
        _buildExchangeRateImpact(),
      ],
    );
  }

  Widget _buildHeader(UserModel user) {
    final greeting = _timeBasedGreeting();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: user.photoUrl != null
                  ? NetworkImage(user.photoUrl!)
                  : null,
              child: user.photoUrl == null
                  ? const Icon(Icons.person, color: Colors.blue, size: 28)
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  user.displayName ?? tr('common.user'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            _SoftIconButton(
              icon: Icons.compare_arrows,
              onTap: () {
                setState(() {
                  _view = _view == _DashboardCurrencyView.combined
                      ? _DashboardCurrencyView.split
                      : _DashboardCurrencyView.combined;
                });
              },
            ),
            const SizedBox(width: 8),
            _SoftIconButton(
              icon: Icons.logout,
              onTap: () async {
                await AuthService.instance.signOut();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceOverview() {
    final isCombined = _view == _DashboardCurrencyView.combined;
    final totals = _lastMonthTotals;

    if (totals == null) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    String fmtBalance(bool visible, double v, String code) =>
        visible ? _formatAmount(v, code) : _maskAmount();

    final t = totals;
    return FutureBuilder<double>(
      future: _exchangeRateService.getCurrentUsdToHtgRate(),
      builder: (context, rateSnap) {
        final rate = rateSnap.data ?? 150.0;

            final revHtgEq = t.revHtg + t.revUsd * rate;
            final expHtgEq = t.expHtg + t.expUsd * rate;
            final balanceHtgEq = revHtgEq - expHtgEq;

            final balHtg = t.revHtg - t.expHtg;
            final balUsd = t.revUsd - t.expUsd;

        if (isCombined) {
          return Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8CE1FA), Color(0xFF4AC9FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4AC9FF).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('dashboard.total_balance'),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                fmtBalance(
                                  _amountsVisible,
                                  balanceHtgEq,
                                  'HTG',
                                ),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: _amountsVisible
                              ? tr('dashboard.hide_amounts')
                              : tr('dashboard.show_amounts'),
                          onPressed: () => setState(
                            () => _amountsVisible = !_amountsVisible,
                          ),
                          icon: Icon(
                            _amountsVisible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const IncomeManagementScreen(),
                                ),
                              );
                            },
                            child:                               _MiniStatPill(
                              label: tr('dashboard.income'),
                              value: fmtBalance(
                                _amountsVisible,
                                revHtgEq,
                                'HTG',
                              ),
                              icon: Icons.arrow_downward,
                              color: Colors.white,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child:                             _MiniStatPill(
                            label: tr('dashboard.expense'),
                            value: fmtBalance(
                              _amountsVisible,
                              expHtgEq,
                              'HTG',
                            ),
                            icon: Icons.arrow_upward,
                            color: Colors.white,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_isRefreshingTotals)
                const Positioned(
                  top: 10,
                  right: 10,
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          );
        }

            void openIncomes() {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const IncomeManagementScreen(),
                ),
              );
            }

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: _amountsVisible
                          ? tr('dashboard.hide_amounts')
                          : tr('dashboard.show_amounts'),
                      onPressed: () => setState(
                        () => _amountsVisible = !_amountsVisible,
                      ),
                      icon: Icon(
                        _amountsVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: openIncomes,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFE4F0D0),
                                Color(0xFFB5DE9E),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFB5DE9E)
                                    .withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('dashboard.balance_htg'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fmtBalance(_amountsVisible, balHtg, 'HTG'),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _MiniStatPillSmall(
                                label: tr('dashboard.income'),
                                value: fmtBalance(
                                  _amountsVisible,
                                  t.revHtg,
                                  'HTG',
                                ),
                                icon: Icons.arrow_downward,
                                color: Colors.green,
                              ),
                              const SizedBox(height: 8),
                              _MiniStatPillSmall(
                                label: tr('dashboard.expense'),
                                value: fmtBalance(
                                  _amountsVisible,
                                  t.expHtg,
                                  'HTG',
                                ),
                                icon: Icons.arrow_upward,
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: openIncomes,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFF9E8D9),
                                Color(0xFFF1C0B3),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF1C0B3)
                                    .withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('dashboard.balance_usd'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fmtBalance(_amountsVisible, balUsd, 'USD'),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _MiniStatPillSmall(
                                label: tr('dashboard.income'),
                                value: fmtBalance(
                                  _amountsVisible,
                                  t.revUsd,
                                  'USD',
                                ),
                                icon: Icons.arrow_downward,
                                color: Colors.green,
                              ),
                              const SizedBox(height: 8),
                              _MiniStatPillSmall(
                                label: tr('dashboard.expense'),
                                value: fmtBalance(
                                  _amountsVisible,
                                  t.expUsd,
                                  'USD',
                                ),
                                icon: Icons.arrow_upward,
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_isRefreshingTotals)
              const Positioned(
                top: 6,
                right: 6,
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tr('dashboard.quick_actions'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _IconBoxButton(
              label: tr('dashboard.add_expense'),
              icon: Icons.add,
              color: const Color(0xFFFF9F43),
              onTap: () {
                _showAddExpenseSheet();
              },
            ),
            _IconBoxButton(
              label: tr('nav.transactions'),
              icon: Icons.document_scanner,
              color: const Color(0xFF00CFE8),
              onTap: () => setState(() => _selectedTab = 1),
            ),
            _IconBoxButton(
              label: tr('nav.budgets'),
              icon: Icons.pie_chart_outline,
              color: const Color(0xFF28C76F),
              onTap: () => setState(() => _selectedTab = 2),
            ),
            _IconBoxButton(
              label: 'Coach IA',
              icon: Icons.psychology_outlined,
              color: const Color(0xFFEA5455),
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentTransactions() {
    final expenses = _recentExpenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tr('dashboard.recent_transactions'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() => _selectedTab = 1);
              },
              child: Text(
                tr('dashboard.see_all'),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!_recentLoaded)
          const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Stack(
            children: [
              Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: expenses.isEmpty
                  ? Column(
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          size: 36,
                          color: Colors.black26,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tr('dashboard.no_recent_transactions'),
                          style: const TextStyle(
                            color: Colors.black45,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : Column(
                      children: expenses.map((e) {
                        final date =
                            '${e.date.day.toString().padLeft(2, '0')}/'
                            '${e.date.month.toString().padLeft(2, '0')}/'
                            '${e.date.year}';
                        final amount = e.amount.toStringAsFixed(2);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                radius: 20,
                                backgroundColor: Color(0xFFFFCDD2),
                                child: Icon(
                                  Icons.arrow_upward,
                                  color: Colors.red,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.description ?? e.categoryId,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      date,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$amount ${e.currencyAtEntry.code}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
              ),
              if (_isRefreshingRecent)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildActiveBudgets() {
    final userId = AuthService.instance.user.value?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tr('dashboard.active_budgets'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _selectedTab = 2),
              child: Text(
                tr('dashboard.see_all'),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (userId == null)
          const SizedBox.shrink()
        else
          FutureBuilder<List<Budget>>(
            future: BudgetLocalStore.instance.queryBudgets(
              userId: userId,
              status: BudgetStatus.active,
            ),
            builder: (context, snap) {
              final budgets = snap.data ?? const [];
              final active = budgets
                  .where((b) => b.endDate.isAfter(DateTime.now()))
                  .take(3)
                  .toList();

              if (active.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 32,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 36,
                        color: Colors.black26,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr('dashboard.no_active_budgets'),
                        style: const TextStyle(
                          color: Colors.black45,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _selectedTab = 2),
                        child: Text(tr('budgets.create')),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: active.map((b) {
                  return _DashboardBudgetMini(budget: b, userId: userId);
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildExchangeRateImpact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('dashboard.exchange_rate_impact'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FutureBuilder<double>(
            future: _exchangeRateService.getCurrentUsdToHtgRate(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Row(
                  children: [
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      tr('exchange_rate.loading'),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                );
              }

              if (snapshot.hasError) {
                return Text(
                  tr('exchange_rate.error'),
                  style: const TextStyle(color: Colors.black54),
                );
              }

              final rate = snapshot.data ?? 150.0;
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.currency_exchange,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1 USD = ${rate.toStringAsFixed(2)} HTG',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('dashboard.exchange_rate_source'),
                          style: const TextStyle(fontSize: 12, color: Colors.black45),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingNavBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFFD6E4FF),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4AC9FF).withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavBarItem(
                icon: Icons.home_rounded,
                isSelected: _selectedTab == 0,
                onTap: () {
                  setState(() => _selectedTab = 0);
                  unawaited(_refreshMonthTotals());
                  unawaited(_refreshRecentExpenses());
                  unawaited(_refreshActiveBudgets());
                },
              ),
              _NavBarItem(
                icon: Icons.receipt_long_rounded,
                isSelected: _selectedTab == 1,
                onTap: () => setState(() => _selectedTab = 1),
              ),
              _NavBarItem(
                icon: Icons.bar_chart_rounded,
                isSelected: _selectedTab == 2,
                onTap: () => setState(() => _selectedTab = 2),
              ),
              _NavBarItem(
                icon: Icons.person_rounded,
                isSelected: _selectedTab == 3,
                onTap: () => setState(() => _selectedTab = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddExpenseSheet() async {
    final added = await showModalBottomSheet<Expense>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddExpenseBottomSheet(),
    );
    if (!mounted) return;
    if (added != null) {
      setState(() {
        _recentExpenses = <Expense>[added, ..._recentExpenses]
            .take(5)
            .toList(growable: false);
        _recentLoaded = true;
      });
      unawaited(_refreshMonthTotals());
      unawaited(_refreshRecentExpenses());
    }
  }

  String _timeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return tr('greeting.morning');
    if (hour < 18) return tr('greeting.afternoon');
    return tr('greeting.evening');
  }
}

// Custom UI Components

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

class _MiniStatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _MiniStatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: color.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatPillSmall extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStatPillSmall({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 12),
        ),
                const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _IconBoxButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconBoxButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4AC9FF).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFF1A9ED4) : Colors.black38,
          size: 26,
        ),
      ),
    );
  }
}

class _DashboardBudgetMini extends StatelessWidget {
  final Budget budget;
  final String userId;

  const _DashboardBudgetMini({required this.budget, required this.userId});

  Color _color(double pct) {
    if (pct >= 90) return Colors.red;
    if (pct >= 70) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: _computeSpent(),
      builder: (context, snap) {
        final spent = snap.data ?? 0;
        final pct = budget.amount > 0 ? (spent / budget.amount * 100) : 0.0;
        final remaining = budget.amount - spent;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      budget.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    budget.currency.code,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(_color(pct)),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _color(pct),
                    ),
                  ),
                  Text(
                    'Reste: ${remaining.toStringAsFixed(0)} ${budget.currency.code}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<double> _computeSpent() async {
    final expenses = await ExpenseLocalStore.instance.queryExpenses(
      userId: userId,
      startInclusive: budget.startDate,
      endInclusive: budget.endDate,
      currency: budget.currency,
      categoryIds: budget.categoryIds.isEmpty ? null : budget.categoryIds,
    );
    var sum = 0.0;
    for (final e in expenses) {
      sum += e.amount;
    }
    return sum;
  }
}
