// import 'package:flutter/material.dart';

// import '../core/offline/income_local_store.dart';
// import '../core/offline/income_sync_service.dart';
// import '../models/enums.dart';
// import '../models/income_model.dart';
// import '../services/auth_service.dart';

// class AddIncomeBottomSheet extends StatefulWidget {
//   const AddIncomeBottomSheet({super.key, this.initialIncome});

//   final Income? initialIncome;

//   @override
//   State<AddIncomeBottomSheet> createState() =>
//       _AddIncomeBottomSheetState();
// }

// class _AddIncomeBottomSheetState extends State<AddIncomeBottomSheet> {
//   final _formKey = GlobalKey<FormState>();

//   final _sourceController = TextEditingController();
//   final _amountController = TextEditingController();

//   Currency _currency = Currency.htg;
//   IncomeFrequency _frequency = IncomeFrequency.monthly;
//   DateTime _nextPaymentDate = DateTime.now();
//   bool _isActive = true;

//   bool _isSaving = false;

//   @override
//   void initState() {
//     super.initState();
//     final initial = widget.initialIncome;
//     if (initial != null) {
//       _sourceController.text = initial.sourceLabel;
//       _amountController.text = initial.amount.toStringAsFixed(2);
//       _currency = initial.currency;
//       _frequency = initial.frequency;
//       _nextPaymentDate = initial.nextPaymentDate;
//       _isActive = initial.isActive;
//     } else {
//       _amountController.text = '0.00';
//     }
//   }

//   @override
//   void dispose() {
//     _sourceController.dispose();
//     _amountController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final mediaQuery = MediaQuery.of(context);
//     final bottomInset = mediaQuery.viewInsets.bottom;

//     return SafeArea(
//       top: false,
//       child: AnimatedPadding(
//         duration: const Duration(milliseconds: 200),
//         padding: EdgeInsets.only(bottom: bottomInset),
//         child: FractionallySizedBox(
//           heightFactor: 0.8,
//           child: Container(
//             decoration: const BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//             ),
//             child: Column(
//               children: [
//                 Container(
//                   width: 40,
//                   height: 4,
//                   margin: const EdgeInsets.only(top: 12, bottom: 8),
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade300,
//                     borderRadius: BorderRadius.circular(2),
//                   ),
//                 ),
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 20),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       const Text(
//                         'Ajouter un revenu',
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.close),
//                         onPressed: () => Navigator.of(context).pop(),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Expanded(
//                   child: SingleChildScrollView(
//                     padding: const EdgeInsets.symmetric(horizontal: 20),
//                     child: Form(
//                       key: _formKey,
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           _buildSourceField(),
//                           const SizedBox(height: 12),
//                           _buildAmountField(),
//                           const SizedBox(height: 12),
//                           _buildCurrencySelector(),
//                           const SizedBox(height: 12),
//                           _buildFrequencySelector(),
//                           const SizedBox(height: 12),
//                           _buildDatePicker(),
//                           const SizedBox(height: 12),
//                           _buildIsActiveSwitch(),
//                           const SizedBox(height: 24),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//                 Padding(
//                   padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: TextButton(
//                           onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
//                           child: const Text('Annuler'),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: ElevatedButton(
//                           onPressed: _isSaving ? null : _onSave,
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.blue,
//                             foregroundColor: Colors.white,
//                             padding: const EdgeInsets.symmetric(vertical: 14),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                           ),
//                           child: _isSaving
//                               ? const SizedBox(
//                                   height: 20,
//                                   width: 20,
//                                   child: CircularProgressIndicator(strokeWidth: 2),
//                                 )
//                               : const Text(
//                                   'Enregistrer',
//                                   style: TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSourceField() {
//     return TextFormField(
//       controller: _sourceController,
//       decoration: const InputDecoration(
//         labelText: 'Nom de la source',
//         hintText: 'Ex: Salaire principal, Freelance',
//         border: OutlineInputBorder(),
//       ),
//       validator: (value) {
//         final v = value?.trim() ?? '';
//         if (v.isEmpty) return 'Le nom de la source est requis.';
//         if (v.length > 100) return 'Max 100 caractères.';
//         return null;
//       },
//     );
//   }

//   Widget _buildAmountField() {
//     return TextFormField(
//       controller: _amountController,
//       keyboardType:
//           const TextInputType.numberWithOptions(decimal: true),
//       style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
//       decoration: const InputDecoration(
//         labelText: 'Montant NET',
//         hintText: '0.00',
//         border: UnderlineInputBorder(),
//       ),
//       validator: (value) {
//         if (value == null || value.trim().isEmpty) return 'Montant requis.';
//         final parsed = double.tryParse(value.replaceAll(',', '.'));
//         if (parsed == null || parsed <= 0) return 'Le montant doit être > 0.';
//         return null;
//       },
//     );
//   }

//   Widget _buildCurrencySelector() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Devise',
//           style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
//         ),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             _CurrencyChip(
//               selected: _currency == Currency.htg,
//               flag: '🇭🇹',
//               label: 'G',
//               onTap: () => setState(() => _currency = Currency.htg),
//             ),
//             const SizedBox(width: 8),
//             _CurrencyChip(
//               selected: _currency == Currency.usd,
//               flag: '🇺🇸',
//               label: '\$',
//               onTap: () => setState(() => _currency = Currency.usd),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildFrequencySelector() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Fréquence',
//           style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
//         ),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             Expanded(
//               child: ChoiceChip(
//                 selected: _frequency == IncomeFrequency.biWeekly,
//                 label: const Text('Quinzaine'),
//                 onSelected: (_) => setState(() => _frequency = IncomeFrequency.biWeekly),
//               ),
//             ),
//             const SizedBox(width: 8),
//             Expanded(
//               child: ChoiceChip(
//                 selected: _frequency == IncomeFrequency.monthly,
//                 label: const Text('Mensuel'),
//                 onSelected: (_) => setState(() => _frequency = IncomeFrequency.monthly),
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildDatePicker() {
//     final formatted = '${_nextPaymentDate.day.toString().padLeft(2, '0')}/'
//         '${_nextPaymentDate.month.toString().padLeft(2, '0')}/'
//         '${_nextPaymentDate.year}';

//     return Row(
//       children: [
//         const Icon(Icons.calendar_today, size: 18),
//         const SizedBox(width: 8),
//         const Text(
//           'Prochaine date de paiement',
//           style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
//         ),
//         const Spacer(),
//         TextButton(
//           onPressed: () async {
//             final now = DateTime.now();
//             final picked = await showDatePicker(
//               context: context,
//               initialDate: _nextPaymentDate,
//               firstDate: DateTime(now.year - 5),
//               lastDate: DateTime(now.year + 30),
//             );
//             if (picked != null) {
//               setState(() => _nextPaymentDate = picked);
//             }
//           },
//           child: Text(formatted),
//         ),
//       ],
//     );
//   }

//   Widget _buildIsActiveSwitch() {
//     return Row(
//       children: [
//         Switch(
//           value: _isActive,
//           onChanged: (v) => setState(() => _isActive = v),
//         ),
//         const SizedBox(width: 8),
//         const Expanded(
//           child: Text(
//             'Revenu actif (compte dans calculs)',
//             style: TextStyle(fontSize: 14),
//           ),
//         ),
//       ],
//     );
//   }

//   Future<void> _onSave() async {
//     if (!_formKey.currentState!.validate()) return;

//     final user = AuthService.instance.user.value;
//     if (user == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Utilisateur non connecté.')),
//       );
//       return;
//     }

//     setState(() => _isSaving = true);
//     try {
//       final now = DateTime.now();
//       final nowMs = now.millisecondsSinceEpoch;
//       final isEditing = widget.initialIncome != null;
//       final incomeId = widget.initialIncome?.incomeId ?? nowMs.toString();

//       final income = Income(
//         incomeId: incomeId,
//         userId: user.id,
//         sourceLabel: _sourceController.text.trim(),
//         amount: double.parse(_amountController.text.replaceAll(',', '.')),
//         currency: _currency,
//         frequency: _frequency,
//         nextPaymentDate: _nextPaymentDate,
//         isActive: _isActive,
//         createdAt: widget.initialIncome?.createdAt ?? now,
//         lastUpdated: now,
//         synced: false,
//       );

//       // local cache
//       await IncomeLocalStore.instance.putIncome(
//         userId: user.id,
//         income: income,
//         synced: false,
//       );

//       // queue op
//       if (isEditing) {
//         await IncomeLocalStore.instance.enqueueUpdate(
//           userId: user.id,
//           income: income,
//           opCreatedAtMs: nowMs,
//         );
//       } else {
//         await IncomeLocalStore.instance.enqueueCreate(
//           userId: user.id,
//           income: income,
//           opCreatedAtMs: nowMs,
//         );
//       }

//       IncomeSyncService.instance.syncNow().catchError((_) {});

//       if (!mounted) return;
//       Navigator.of(context).pop<Income>(income);
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Revenu ajouté/actualisé avec succès.')),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Erreur: $e')),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => _isSaving = false);
//       }
//     }
//   }
// }

// class _CurrencyChip extends StatelessWidget {
//   const _CurrencyChip({
//     required this.selected,
//     required this.flag,
//     required this.label,
//     required this.onTap,
//   });

//   final bool selected;
//   final String flag;
//   final String label;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 150),
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//         decoration: BoxDecoration(
//           color: selected ? Colors.blue.shade50 : Colors.grey.shade100,
//           borderRadius: BorderRadius.circular(24),
//           border: Border.all(
//             color: selected ? Colors.blue : Colors.transparent,
//             width: 1.5,
//           ),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(flag),
//             const SizedBox(width: 6),
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w700,
//                 color: selected ? Colors.blue : Colors.black87,
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/app_toast.dart';

import '../core/offline/income_local_store.dart';
import '../core/offline/income_sync_service.dart';
import '../models/enums.dart';
import '../models/income_model.dart';
import '../services/auth_service.dart';

class AddIncomeBottomSheet extends StatefulWidget {
  const AddIncomeBottomSheet({super.key, this.initialIncome});

  final Income? initialIncome;

  @override
  State<AddIncomeBottomSheet> createState() => _AddIncomeBottomSheetState();
}

class _AddIncomeBottomSheetState extends State<AddIncomeBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  final _sourceController = TextEditingController();
  final _amountController = TextEditingController();

  Currency _currency = Currency.htg;
  IncomeFrequency _frequency = IncomeFrequency.monthly;
  DateTime _nextPaymentDate = DateTime.now();
  bool _isActive = true;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialIncome;
    if (initial != null) {
      _sourceController.text = initial.sourceLabel;
      _amountController.text = initial.amount.toStringAsFixed(2);
      _currency = initial.currency;
      _frequency = initial.frequency;
      _nextPaymentDate = initial.nextPaymentDate;
      _isActive = initial.isActive;
    } else {
      _amountController.text = '0.00';
    }
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: FractionallySizedBox(
          heightFactor: 0.8,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Drag handle — identique à AddExpenseBottomSheet
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.initialIncome != null
                            ? tr('common.edit')
                            : tr('add_income.title'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildAmountField(),
                          const SizedBox(height: 12),
                          _buildCurrencySelector(),
                          const SizedBox(height: 16),
                          _buildSourceField(),
                          const SizedBox(height: 16),
                          _buildFrequencySelector(),
                          const SizedBox(height: 16),
                          _buildDatePicker(),
                          const SizedBox(height: 16),
                          _buildIsActiveSwitch(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                // Footer — identique à AddExpenseBottomSheet
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed:
                              _isSaving ? null : () => Navigator.of(context).pop(),
                          child: Text(tr('common.cancel')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _onSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  tr('add_income.btn_save'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Champ montant (style identique à AddExpenseBottomSheet) ─────────────────
  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: tr('add_income.label_amount'),
        hintText: tr('add_income.hint_amount'),
        border: const UnderlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return tr('add_income.error_amount');
        final parsed = double.tryParse(value.replaceAll(',', '.'));
        if (parsed == null || parsed <= 0) return tr('add_income.error_amount');
        return null;
      },
    );
  }

  // ── Devise — _CurrencyChip aligné avec AddExpenseBottomSheet (sans flag) ────
  Widget _buildCurrencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Devise',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _CurrencyChip(
              label: 'HTG',
              selected: _currency == Currency.htg,
              onTap: () => setState(() => _currency = Currency.htg),
            ),
            const SizedBox(width: 8),
            _CurrencyChip(
              label: 'USD',
              selected: _currency == Currency.usd,
              onTap: () => setState(() => _currency = Currency.usd),
            ),
          ],
        ),
      ],
    );
  }

  // ── Source ──────────────────────────────────────────────────────────────────
  Widget _buildSourceField() {
    return TextFormField(
      controller: _sourceController,
      decoration: const InputDecoration(
        labelText: 'Nom de la source',
        hintText: 'Ex: Salaire principal, Freelance',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Le nom de la source est requis.';
        if (v.length > 100) return 'Max 100 caractères.';
        return null;
      },
    );
  }

  // ── Fréquence — ChoiceChip identique à AddExpenseBottomSheet ────────────────
  Widget _buildFrequencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('add_income.label_frequency'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFrequencyChip(
              IncomeFrequency.biWeekly,
              'Quinzaine',
              FontAwesomeIcons.calendarWeek,
            ),
            _buildFrequencyChip(
              IncomeFrequency.monthly,
              'Mensuel',
              FontAwesomeIcons.calendarDays,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFrequencyChip(
    IncomeFrequency freq,
    String label,
    IconData icon,
  ) {
    final selected = _frequency == freq;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            icon,
            size: 13,
            color: selected ? Colors.white : Colors.black87,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => setState(() => _frequency = freq),
    );
  }

  // ── Date picker ─────────────────────────────────────────────────────────────
  Widget _buildDatePicker() {
    final formatted =
        '${_nextPaymentDate.day.toString().padLeft(2, '0')}/'
        '${_nextPaymentDate.month.toString().padLeft(2, '0')}/'
        '${_nextPaymentDate.year}';

    return Row(
      children: [
        const FaIcon(FontAwesomeIcons.calendarCheck, size: 16),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Prochaine date de paiement',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        TextButton(
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _nextPaymentDate,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 30),
            );
            if (picked != null) {
              setState(() => _nextPaymentDate = picked);
            }
          },
          child: Text(formatted),
        ),
      ],
    );
  }

  // ── Switch actif ─────────────────────────────────────────────────────────────
  Widget _buildIsActiveSwitch() {
    return Row(
      children: [
        Switch(
          value: _isActive,
          onChanged: (v) => setState(() => _isActive = v),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Revenu actif (compte dans les calculs)',
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  // ── Sauvegarde ───────────────────────────────────────────────────────────────
  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final user = AuthService.instance.user.value;
    if (user == null) {
      AppToast.show(
        context,
        message: 'Non connecté',
        subtitle: 'Veuillez vous reconnecter.',
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;
      final isEditing = widget.initialIncome != null;
      final incomeId = widget.initialIncome?.incomeId ?? nowMs.toString();

      final income = Income(
        incomeId: incomeId,
        userId: user.id,
        sourceLabel: _sourceController.text.trim(),
        amount: double.parse(_amountController.text.replaceAll(',', '.')),
        currency: _currency,
        frequency: _frequency,
        nextPaymentDate: _nextPaymentDate,
        isActive: _isActive,
        createdAt: widget.initialIncome?.createdAt ?? now,
        lastUpdated: now,
        synced: false,
      );

      await IncomeLocalStore.instance.putIncome(
        userId: user.id,
        income: income,
        synced: false,
      );

      if (isEditing) {
        await IncomeLocalStore.instance.enqueueUpdate(
          userId: user.id,
          income: income,
          opCreatedAtMs: nowMs,
        );
      } else {
        await IncomeLocalStore.instance.enqueueCreate(
          userId: user.id,
          income: income,
          opCreatedAtMs: nowMs,
        );
      }

      IncomeSyncService.instance.syncNow().catchError((_) {});

      if (!mounted) return;
      Navigator.of(context).pop<Income>(income);
      AppToast.show(
        context,
        message: isEditing ? 'Revenu modifié' : 'Revenu ajouté',
        subtitle: 'Sauvegardé offline, sync en cours.',
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'Une erreur est survenue',
        subtitle: e.toString(),
        type: ToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

// ── _CurrencyChip — identique à AddExpenseBottomSheet (sans flag emoji) ───────
class _CurrencyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CurrencyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? Colors.blue : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.blue : Colors.black87,
          ),
        ),
      ),
    );
  }
}