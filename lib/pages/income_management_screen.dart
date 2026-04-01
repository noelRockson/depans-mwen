import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../core/offline/income_local_store.dart';
import '../core/offline/income_sync_service.dart';
import '../models/enums.dart';
import '../models/income_model.dart';
import '../services/auth_service.dart';
import 'add_income_bottom_sheet.dart';

class IncomeManagementScreen extends StatefulWidget {
  const IncomeManagementScreen({super.key});

  @override
  State<IncomeManagementScreen> createState() => _IncomeManagementScreenState();
}

class _IncomeManagementScreenState extends State<IncomeManagementScreen> {
  bool _loading = true;
  List<Income> _incomes = const [];

  String? get _userId => AuthService.instance.user.value?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _loading = false;
        _incomes = const [];
      });
      return;
    }

    setState(() => _loading = true);

    // Offline-first: load local immediately, then sync best-effort, then refresh.
    final local = await IncomeLocalStore.instance.queryIncomes(userId: userId);
    if (mounted) {
      setState(() {
        _incomes = local;
        _loading = false;
      });
    }

    await IncomeSyncService.instance.syncNow().catchError((_) {});
    final afterSync =
        await IncomeLocalStore.instance.queryIncomes(userId: userId);
    if (mounted) {
      setState(() => _incomes = afterSync);
    }
  }

  Future<void> _openAddIncome({Income? initial}) async {
    final result = await showModalBottomSheet<Income>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddIncomeBottomSheet(initialIncome: initial),
    );

    if (result != null && mounted) {
      await _load();
    }
  }

  Future<void> _deleteIncome(Income income) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer le revenu'),
        content: const Text(
          'Suppression offline-first : le revenu sera retiré localement et synchronisé ensuite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final userId = _userId;
    if (userId == null) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
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

    IncomeSyncService.instance.syncNow().catchError((_) {});
    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(tr('income_management.title')),
        actions: [
          IconButton(
            tooltip: tr('common.refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddIncome(),
        icon: const Icon(Icons.add),
        label: Text(tr('income_management.add_income')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _incomes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      tr('income_management.no_incomes'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: _incomes.length,
                  itemBuilder: (context, index) {
                    final income = _incomes[index];
                    final amount =
                        '${income.amount.toStringAsFixed(2)} ${income.currency.code}';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
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
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.arrow_downward,
                              color: Colors.green,
                            ),
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
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${income.frequency.code} • Prochain: ${_formatDate(income.nextPaymentDate)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                amount,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Modifier',
                                    icon: const Icon(Icons.edit),
                                    onPressed: () =>
                                        _openAddIncome(initial: income),
                                  ),
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _deleteIncome(income),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

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
}

