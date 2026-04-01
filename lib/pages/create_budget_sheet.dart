import 'package:flutter/material.dart';

import '../models/budget_model.dart';
import '../models/enums.dart';
import '../services/auth_service.dart';
import '../core/offline/budget_local_store.dart';
import '../core/offline/budget_sync_service.dart';

/// Default expense categories used throughout the app.
const kDefaultCategories = <String, Map<String, dynamic>>{
  'transport': {'name': 'Transport', 'icon': Icons.directions_car, 'color': 0xFF2196F3},
  'restaurant': {'name': 'Restaurant', 'icon': Icons.restaurant, 'color': 0xFFFF9800},
  'courses': {'name': 'Courses', 'icon': Icons.shopping_cart, 'color': 0xFF4CAF50},
  'loyer': {'name': 'Loyer', 'icon': Icons.home, 'color': 0xFF9C27B0},
  'sante': {'name': 'Santé', 'icon': Icons.local_hospital, 'color': 0xFFF44336},
  'education': {'name': 'Éducation', 'icon': Icons.school, 'color': 0xFF00BCD4},
  'loisirs': {'name': 'Loisirs', 'icon': Icons.sports_esports, 'color': 0xFFE91E63},
  'shopping': {'name': 'Shopping', 'icon': Icons.shopping_bag, 'color': 0xFF673AB7},
  'factures': {'name': 'Factures', 'icon': Icons.receipt_long, 'color': 0xFF795548},
  'epargne': {'name': 'Épargne', 'icon': Icons.savings, 'color': 0xFF009688},
  'autre': {'name': 'Autre', 'icon': Icons.more_horiz, 'color': 0xFF607D8B},
};

class CreateBudgetSheet extends StatefulWidget {
  final Budget? initialBudget;

  const CreateBudgetSheet({super.key, this.initialBudget});

  @override
  State<CreateBudgetSheet> createState() => _CreateBudgetSheetState();
}

class _CreateBudgetSheetState extends State<CreateBudgetSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  Currency _currency = Currency.htg;
  BudgetPeriodType _periodType = BudgetPeriodType.monthly;
  DateTime? _customStart;
  DateTime? _customEnd;
  double _alertThreshold = 80;
  final Set<String> _selectedCategories = {};
  bool _saving = false;

  bool get _isEdit => widget.initialBudget != null;

  @override
  void initState() {
    super.initState();
    final b = widget.initialBudget;
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _amountCtrl = TextEditingController(
      text: b != null ? b.amount.toStringAsFixed(2) : '',
    );
    if (b != null) {
      _currency = b.currency;
      _periodType = b.periodType;
      _customStart = b.startDate;
      _customEnd = b.endDate;
      _alertThreshold = b.alertThresholdPercentage;
      _selectedCategories.addAll(b.categoryIds);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  (DateTime, DateTime) _resolveDates() {
    if (_periodType == BudgetPeriodType.custom &&
        _customStart != null &&
        _customEnd != null) {
      return (_customStart!, _customEnd!);
    }
    final now = DateTime.now();
    if (_periodType == BudgetPeriodType.quarterly) {
      final qStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
      final start = DateTime(now.year, qStartMonth, 1);
      final end = DateTime(now.year, qStartMonth + 3, 0, 23, 59, 59, 999);
      return (start, end);
    }
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    return (start, end);
  }

  Future<void> _onSave() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    if (name.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom et montant requis.')),
      );
      return;
    }
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins une catégorie.')),
      );
      return;
    }

    setState(() => _saving = true);
    final userId = AuthService.instance.user.value?.id;
    if (userId == null) {
      setState(() => _saving = false);
      return;
    }

    final now = DateTime.now();
    final (start, end) = _resolveDates();

    final budget = Budget(
      budgetId: widget.initialBudget?.budgetId ??
          'bgt_${now.millisecondsSinceEpoch}',
      userId: userId,
      name: name,
      amount: amount,
      currency: _currency,
      periodType: _periodType,
      startDate: start,
      endDate: end,
      categoryIds: _selectedCategories.toList(),
      alertThresholdPercentage: _alertThreshold,
      status: BudgetStatus.active,
      createdAt: widget.initialBudget?.createdAt ?? now,
      synced: false,
    );

    try {
      await BudgetLocalStore.instance.putBudget(
        userId: userId,
        budget: budget,
        synced: false,
      );

      final opMs = now.millisecondsSinceEpoch;
      if (_isEdit) {
        await BudgetLocalStore.instance.enqueueUpdate(
          userId: userId,
          budget: budget,
          opCreatedAtMs: opMs,
        );
      } else {
        await BudgetLocalStore.instance.enqueueCreate(
          userId: userId,
          budget: budget,
          opCreatedAtMs: opMs,
        );
      }

      BudgetSyncService.instance.syncNow().catchError((_) {});

      if (mounted) Navigator.pop(context, budget);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_customStart ?? DateTime.now())
        : (_customEnd ?? DateTime.now().add(const Duration(days: 30)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _customStart = picked;
      } else {
        _customEnd = DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 16 + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isEdit ? 'Modifier le budget' : 'Nouveau budget',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nom',
                    hintText: 'Ex: Budget alimentation mars',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Montant',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Devise',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: Currency.values.map((c) {
                    final selected = _currency == c;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(c.code),
                          selected: selected,
                          onSelected: (_) => setState(() => _currency = c),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Période',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: BudgetPeriodType.values.map((pt) {
                    return ChoiceChip(
                      label: Text(pt.label),
                      selected: _periodType == pt,
                      onSelected: (_) => setState(() => _periodType = pt),
                    );
                  }).toList(),
                ),
                if (_periodType == BudgetPeriodType.custom) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickDate(isStart: true),
                          child: Text(
                            _customStart != null
                                ? _fmtDate(_customStart!)
                                : 'Début',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickDate(isStart: false),
                          child: Text(
                            _customEnd != null
                                ? _fmtDate(_customEnd!)
                                : 'Fin',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Catégories',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedCategories.length ==
                              kDefaultCategories.length) {
                            _selectedCategories.clear();
                          } else {
                            _selectedCategories.addAll(kDefaultCategories.keys);
                          }
                        });
                      },
                      child: Text(
                        _selectedCategories.length == kDefaultCategories.length
                            ? 'Tout décocher'
                            : 'Tout cocher',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kDefaultCategories.entries.map((entry) {
                    final sel = _selectedCategories.contains(entry.key);
                    final cat = entry.value;
                    return FilterChip(
                      label: Text(cat['name'] as String),
                      avatar: Icon(cat['icon'] as IconData, size: 16),
                      selected: sel,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedCategories.add(entry.key);
                          } else {
                            _selectedCategories.remove(entry.key);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Alerte à ${_alertThreshold.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: _alertThreshold,
                  min: 50,
                  max: 100,
                  divisions: 10,
                  label: '${_alertThreshold.toStringAsFixed(0)}%',
                  onChanged: (v) => setState(() => _alertThreshold = v),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4AC9FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEdit ? 'Modifier' : 'Créer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
