import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/budget_model.dart';
import '../models/expense_model.dart';
import '../models/enums.dart';
import '../services/auth_service.dart';
import '../core/offline/expense_local_store.dart';
import '../core/offline/budget_local_store.dart';
import '../core/offline/budget_sync_service.dart';
import 'create_budget_sheet.dart';

class BudgetDetailScreen extends StatefulWidget {
  final Budget budget;

  const BudgetDetailScreen({super.key, required this.budget});

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  late Budget _budget;
  List<Expense> _expenses = [];
  double _totalSpent = 0;
  Map<String, double> _categorySpending = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _budget = widget.budget;
    _load();
  }

  String? _userId() => AuthService.instance.user.value?.id;

  Future<void> _load() async {
    final userId = _userId();
    if (userId == null) return;

    setState(() => _loading = true);

    final expenses = await ExpenseLocalStore.instance.queryExpenses(
      userId: userId,
      startInclusive: _budget.startDate,
      endInclusive: _budget.endDate,
      currency: _budget.currency,
      categoryIds: _budget.categoryIds.isEmpty ? null : _budget.categoryIds,
    );

    var sum = 0.0;
    final catMap = <String, double>{};
    for (final e in expenses) {
      sum += e.amount;
      catMap[e.categoryId] = (catMap[e.categoryId] ?? 0) + e.amount;
    }

    if (!mounted) return;
    setState(() {
      _expenses = expenses;
      _totalSpent = sum;
      _categorySpending = catMap;
      _loading = false;
    });
  }

  Future<void> _deleteBudget() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le budget'),
        content: Text('Supprimer « ${_budget.name} » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final userId = _userId();
    if (userId == null) return;

    await BudgetLocalStore.instance.deleteBudget(
      userId: userId,
      budgetId: _budget.budgetId,
    );
    await BudgetLocalStore.instance.enqueueDelete(
      userId: userId,
      budgetId: _budget.budgetId,
      opCreatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    BudgetSyncService.instance.syncNow().catchError((_) {});
    if (mounted) Navigator.pop(context);
  }

  Future<void> _editBudget() async {
    final result = await showModalBottomSheet<Budget>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateBudgetSheet(initialBudget: _budget),
    );
    if (result != null && mounted) {
      setState(() => _budget = result);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct =
        _budget.amount > 0 ? (_totalSpent / _budget.amount * 100) : 0.0;
    final remaining = _budget.amount - _totalSpent;
    final daysTotal =
        _budget.endDate.difference(_budget.startDate).inDays.clamp(1, 9999);
    final daysLeft =
        _budget.endDate.difference(DateTime.now()).inDays.clamp(0, 9999);
    final dailyAllowed = daysLeft > 0 ? remaining / daysLeft : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(_budget.name),
        backgroundColor: const Color(0xFFF0F4F8),
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editBudget,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deleteBudget,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  _buildGauge(pct, remaining),
                  const SizedBox(height: 20),
                  _buildQuickStats(remaining, daysLeft, dailyAllowed),
                  const SizedBox(height: 20),
                  _buildSpendingTrend(pct, daysTotal, daysLeft),
                  const SizedBox(height: 20),
                  _buildCategoryBreakdown(),
                  const SizedBox(height: 20),
                  _buildRelatedTransactions(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildGauge(double pct, double remaining) {
    final clampedPct = pct.clamp(0, 100).toDouble();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: CustomPaint(
              painter: _GaugePainter(
                percentage: clampedPct,
                color: _progressColor(clampedPct),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      remaining.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _progressColor(clampedPct),
                      ),
                    ),
                    Text(
                      _budget.currency.code,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const Text(
                      'restant',
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${clampedPct.toStringAsFixed(0)}% utilisé',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _progressColor(clampedPct),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(
    double remaining,
    int daysLeft,
    double dailyAllowed,
  ) {
    return Row(
      children: [
        _StatChip(
          label: 'Budget',
          value:
              '${_budget.amount.toStringAsFixed(2)} ${_budget.currency.code}',
          color: Colors.blue,
        ),
        const SizedBox(width: 10),
        _StatChip(
          label: 'Dépensé',
          value:
              '${_totalSpent.toStringAsFixed(2)} ${_budget.currency.code}',
          color: Colors.orange,
        ),
        const SizedBox(width: 10),
        _StatChip(
          label: 'Moy./jour',
          value: '${dailyAllowed.toStringAsFixed(0)} ${_budget.currency.code}',
          color: Colors.teal,
        ),
      ],
    );
  }

  Widget _buildSpendingTrend(double pct, int daysTotal, int daysLeft) {
    final daysPassed = daysTotal - daysLeft;
    final idealPct =
        daysTotal > 0 ? (daysPassed / daysTotal * 100).clamp(0.0, 100.0) : 0.0;

    String trendText;
    if (pct > idealPct + 5) {
      trendText =
          'Vous dépensez plus vite que prévu (${pct.toStringAsFixed(0)}% vs ${idealPct.toStringAsFixed(0)}% idéal).';
    } else if (pct < idealPct - 5) {
      trendText =
          'Bon rythme ! Vous êtes en dessous de la trajectoire idéale.';
    } else {
      trendText = 'Rythme normal. Continuez ainsi !';
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tendance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BarIndicator(
                      label: 'Réel',
                      pct: pct.clamp(0, 100),
                      color: _progressColor(pct),
                    ),
                    const SizedBox(height: 8),
                    _BarIndicator(
                      label: 'Idéal',
                      pct: idealPct,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            trendText,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    if (_categorySpending.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = _categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Par catégorie',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...sorted.map((entry) {
            final catPct =
                _totalSpent > 0 ? (entry.value / _totalSpent * 100) : 0.0;
            final cat = kDefaultCategories[entry.key];
            final catName = (cat?['name'] ?? entry.key) as String;
            final catColor =
                Color((cat?['color'] as int?) ?? 0xFF607D8B);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      catName,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (catPct / 100).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(catColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${entry.value.toStringAsFixed(0)} ${_budget.currency.code}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRelatedTransactions() {
    final recent = _expenses.take(10).toList();
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dépenses liées (${_expenses.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            const Text(
              'Aucune dépense liée.',
              style: TextStyle(color: Colors.black45),
            ),
          ...recent.map((e) {
            final date =
                '${e.date.day.toString().padLeft(2, '0')}/${e.date.month.toString().padLeft(2, '0')}';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFFFCDD2),
                    child: Icon(Icons.arrow_upward,
                        size: 14, color: Colors.red),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.description ?? e.categoryId,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${e.amount.toStringAsFixed(2)} ${e.currencyAtEntry.code}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static Color _progressColor(double pct) {
    if (pct >= 90) return Colors.red;
    if (pct >= 70) return Colors.orange;
    return Colors.green;
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _BarIndicator extends StatelessWidget {
  final String label;
  final double pct;
  final Color color;

  const _BarIndicator({
    required this.label,
    required this.pct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '${pct.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percentage;
  final Color color;

  _GaugePainter({required this.percentage, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    const startAngle = -math.pi;
    const sweepTotal = 2 * math.pi;

    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      bgPaint,
    );

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final sweep = sweepTotal * (percentage / 100).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.percentage != percentage || oldDelegate.color != color;
}
