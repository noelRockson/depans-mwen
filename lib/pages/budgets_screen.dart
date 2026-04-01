import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/budget_model.dart';
import '../models/enums.dart';
import '../services/auth_service.dart';
import '../core/offline/budget_local_store.dart';
import '../core/offline/budget_sync_service.dart';
import '../core/offline/expense_local_store.dart';
import 'create_budget_sheet.dart';
import 'budget_detail_screen.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  List<Budget> _active = [];
  List<Budget> _past = [];
  bool _loading = true;
  bool _pastExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _userId() => AuthService.instance.user.value?.id;

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = _userId();
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    await BudgetSyncService.instance.syncNow().catchError((_) {});

    final all = await BudgetLocalStore.instance.queryBudgets(userId: userId);
    final now = DateTime.now();
    final active = <Budget>[];
    final past = <Budget>[];

    for (final b in all) {
      if (b.status == BudgetStatus.active && b.endDate.isAfter(now)) {
        active.add(b);
      } else {
        past.add(b);
      }
    }

    if (!mounted) return;
    setState(() {
      _active = active;
      _past = past;
      _loading = false;
    });
  }

  Future<double> _computeSpent(Budget budget) async {
    final userId = _userId();
    if (userId == null) return 0;
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

  Future<void> _openCreateBudget([Budget? initial]) async {
    final result = await showModalBottomSheet<Budget>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateBudgetSheet(initialBudget: initial),
    );
    if (result != null && mounted) {
      _load();
    }
  }

  Future<void> _deleteBudget(Budget budget) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('budgets.delete_confirm_title')),
        content: Text('${tr('budgets.delete_confirm_body')}\n« ${budget.name} »'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('common.delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final userId = _userId();
    if (userId == null) return;

    await BudgetLocalStore.instance.deleteBudget(
      userId: userId,
      budgetId: budget.budgetId,
    );
    await BudgetLocalStore.instance.enqueueDelete(
      userId: userId,
      budgetId: budget.budgetId,
      opCreatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    BudgetSyncService.instance.syncNow().catchError((_) {});
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr('budgets.title'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              tooltip: tr('budgets.create'),
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => _openCreateBudget(),
                            ),
                            IconButton(
                              tooltip: tr('budgets.refresh'),
                              icon: const Icon(Icons.refresh),
                              onPressed: _load,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr('dashboard.active_budgets'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_active.isEmpty)
                      _EmptyCard(
                        icon: Icons.account_balance_wallet_outlined,
                        message: tr('budgets.no_budgets'),
                        cta: tr('budgets.create'),
                        onCta: () => _openCreateBudget(),
                      ),
                    ..._active.map((b) => _BudgetCard(
                          budget: b,
                          computeSpent: () => _computeSpent(b),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => BudgetDetailScreen(budget: b),
                              ),
                            );
                          },
                          onEdit: () => _openCreateBudget(b),
                          onDelete: () => _deleteBudget(b),
                        )),
                    const SizedBox(height: 24),
                    if (_past.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () =>
                            setState(() => _pastExpanded = !_pastExpanded),
                        child: Row(
                          children: [
                            Icon(
                              _pastExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Budgets passés (${_past.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_pastExpanded) ...[
                        const SizedBox(height: 12),
                        ..._past.map((b) => _BudgetCard(
                              budget: b,
                              computeSpent: () => _computeSpent(b),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        BudgetDetailScreen(budget: b),
                                  ),
                                );
                              },
                              onEdit: () => _openCreateBudget(b),
                              onDelete: () => _deleteBudget(b),
                            )),
                      ],
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final Future<double> Function() computeSpent;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.budget,
    required this.computeSpent,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  Color _progressColor(double pct) {
    if (pct >= 90) return Colors.red;
    if (pct >= 70) return Colors.orange;
    return Colors.green;
  }

  String _statusBadge(BuildContext context) {
    final now = DateTime.now();
    if (budget.status == BudgetStatus.exceeded) return tr('budgets.over_budget');
    if (budget.endDate.isBefore(now)) return tr('budgets.completed');
    return tr('budgets.active');
  }

  Color _statusColor() {
    final now = DateTime.now();
    if (budget.status == BudgetStatus.exceeded) return Colors.red;
    if (budget.endDate.isBefore(now)) return Colors.grey;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FutureBuilder<double>(
          future: computeSpent(),
          builder: (context, snap) {
            final spent = snap.data ?? 0;
            final pct =
                budget.amount > 0 ? (spent / budget.amount * 100) : 0.0;
            final remaining = budget.amount - spent;
            final daysLeft =
                budget.endDate.difference(DateTime.now()).inDays.clamp(0, 9999);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        budget.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor().withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Builder(
                        builder: (ctx) => Text(
                          _statusBadge(ctx),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        budget.currency.code,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_fmtDate(budget.startDate)} – ${_fmtDate(budget.endDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      _progressColor(pct),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${pct.toStringAsFixed(0)}% utilisé',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _progressColor(pct),
                      ),
                    ),
                    Text(
                      'Reste: ${remaining.toStringAsFixed(2)} ${budget.currency.code}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (pct >= budget.alertThresholdPercentage) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        'Attention! ${pct.toStringAsFixed(0)}% utilisé',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$daysLeft jour${daysLeft > 1 ? 's' : ''} restant${daysLeft > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onEdit,
                      child: const Icon(Icons.edit_outlined,
                          size: 18, color: Colors.blueGrey),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String cta;
  final VoidCallback onCta;

  const _EmptyCard({
    required this.icon,
    required this.message,
    required this.cta,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
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
          Icon(icon, size: 36, color: Colors.black26),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onCta,
            child: Text(cta),
          ),
        ],
      ),
    );
  }
}
