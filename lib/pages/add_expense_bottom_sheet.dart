// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// import '../models/enums.dart';
// import '../models/expense_model.dart';
// import '../core/offline/expense_local_store.dart';
// import '../core/offline/expense_sync_service.dart';
// import '../services/auth_service.dart';
// import '../services/exchange_rate_service.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// class AddExpenseBottomSheet extends StatefulWidget {
//   const AddExpenseBottomSheet({super.key, this.initialExpense});

//   final Expense? initialExpense;

//   @override
//   State<AddExpenseBottomSheet> createState() => _AddExpenseBottomSheetState();
// }

// class _AddExpenseBottomSheetState extends State<AddExpenseBottomSheet> {
//   final _formKey = GlobalKey<FormState>();
//   final _amountController = TextEditingController();
//   final _descriptionController = TextEditingController();

//   final _exchangeRateService = const ExchangeRateService();

//   Currency _currency = Currency.htg;
//   String? _selectedCategoryId;
//   DateTime _selectedDate = DateTime.now();
//   bool _isFixed = false;
//   ExpenseRecurrenceFrequency? _recurrenceFrequency;
//   int? _recurrenceDay;
//   bool _autoAddNext = false;
//   PaymentMethod? _paymentMethod;

//   bool _isSaving = false;

//   @override
//   void initState() {
//     super.initState();
//     final initial = widget.initialExpense;
//     _amountController.text = initial?.amount.toStringAsFixed(2) ?? '0.00';
//     _descriptionController.text = initial?.description ?? '';
//     _currency = initial?.currencyAtEntry ?? Currency.htg;
//     _selectedCategoryId = initial?.categoryId;
//     _selectedDate = initial?.date ?? DateTime.now();
//     _isFixed = initial?.isFixed ?? false;
//     _recurrenceFrequency = initial?.recurrenceFrequency;
//     _recurrenceDay = initial?.recurrenceDay;
//     _autoAddNext = initial?.autoAddNextOccurrence ?? false;
//     _paymentMethod = initial?.paymentMethod;
//   }

//   @override
//   void dispose() {
//     _amountController.dispose();
//     _descriptionController.dispose();
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
//                         'Ajouter une dépense',
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
//                           const SizedBox(height: 8),
//                           _buildAmountField(),
//                           const SizedBox(height: 12),
//                           _buildCurrencySelector(),
//                           const SizedBox(height: 16),
//                           _buildCategorySelector(),
//                           const SizedBox(height: 16),
//                           _buildDescriptionField(),
//                           const SizedBox(height: 16),
//                           _buildDatePicker(context),
//                           const SizedBox(height: 16),
//                           _buildFixedSwitch(),
//                           if (_isFixed) ...[
//                             const SizedBox(height: 12),
//                             _buildRecurrenceSettings(),
//                           ],
//                           const SizedBox(height: 16),
//                           _buildPaymentMethodChips(),
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
//                           onPressed: _isSaving
//                               ? null
//                               : () => Navigator.of(context).pop(),
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
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 2,
//                                     valueColor: AlwaysStoppedAnimation<Color>(
//                                       Colors.white,
//                                     ),
//                                   ),
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

//   Widget _buildAmountField() {
//     return TextFormField(
//       controller: _amountController,
//       keyboardType: const TextInputType.numberWithOptions(decimal: true),
//       inputFormatters: [
//         FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
//       ],
//       style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
//       decoration: const InputDecoration(
//         labelText: 'Montant',
//         hintText: '0.00',
//         border: UnderlineInputBorder(),
//       ),
//       validator: (value) {
//         if (value == null || value.trim().isEmpty) {
//           return 'Veuillez entrer un montant.';
//         }
//         final parsed = double.tryParse(value.replaceAll(',', '.'));
//         if (parsed == null || parsed <= 0) {
//           return 'Le montant doit être supérieur à 0.';
//         }
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
//               label: 'HTG',
//               // flag: '🇭🇹',
//               selected: _currency == Currency.htg,
//               onTap: () => setState(() => _currency = Currency.htg),
//             ),
//             const SizedBox(width: 8),
//             _CurrencyChip(
//               label: "USD",
//               // flag: '🇺🇸',
//               selected: _currency == Currency.usd,
//               onTap: () => setState(() => _currency = Currency.usd),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildCategorySelector() {
//     final categories = _mockCategories;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Catégorie',
//           style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
//         ),
//         const SizedBox(height: 8),
//         GridView.builder(
//           shrinkWrap: true,
//           physics: const NeverScrollableScrollPhysics(),
//           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: 4,
//             mainAxisSpacing: 8,
//             crossAxisSpacing: 8,
//             childAspectRatio: 0.9,
//           ),
//           itemCount: categories.length,
//           itemBuilder: (context, index) {
//             final cat = categories[index];
//             final isSelected = _selectedCategoryId == cat.id;
//             return GestureDetector(
//               onTap: () {
//                 setState(() {
//                   _selectedCategoryId = cat.id;
//                 });
//               },
//               child: Column(
//                 children: [
//                   Container(
//                     width: 64,
//                     height: 64,
//                     decoration: BoxDecoration(
//                       color: isSelected
//                           ? Color(cat.color).withValues(alpha: 0.15)
//                           : Colors.grey.shade100,
//                       borderRadius: BorderRadius.circular(18),
//                       border: Border.all(
//                         color: isSelected
//                             ? Color(cat.color)
//                             : Colors.transparent,
//                         width: 2,
//                       ),
//                     ),
//                     child: Center(
//                       child: Icon(
//                         cat.icon,
//                         size: 26,
//                         color: isSelected
//                             ? Color(cat.color)
//                             : Color(cat.color).withOpacity(0.7),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     cat.label,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(fontSize: 12),
//                   ),
//                 ],
//               ),
//             );
//           },
//         ),
//         if (_selectedCategoryId == null)
//           const Padding(
//             padding: EdgeInsets.only(top: 4),
//             child: Text(
//               'Sélectionnez une catégorie.',
//               style: TextStyle(fontSize: 11, color: Colors.red),
//             ),
//           ),
//       ],
//     );
//   }

//   Widget _buildDescriptionField() {
//     return TextFormField(
//       controller: _descriptionController,
//       maxLines: 2,
//       decoration: const InputDecoration(
//         labelText: 'Description (optionnel)',
//         hintText: 'Ex: Déjeuner au restaurant',
//         border: OutlineInputBorder(),
//       ),
//     );
//   }

//   Widget _buildDatePicker(BuildContext context) {
//     final formatted =
//         '${_selectedDate.day.toString().padLeft(2, '0')}/'
//         '${_selectedDate.month.toString().padLeft(2, '0')}/'
//         '${_selectedDate.year}';

//     return Row(
//       children: [
//         const Icon(Icons.calendar_today, size: 18),
//         const SizedBox(width: 8),
//         const Text(
//           'Date',
//           style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
//         ),
//         const Spacer(),
//         TextButton(
//           onPressed: () async {
//             final now = DateTime.now();
//             final picked = await showDatePicker(
//               context: context,
//               initialDate: _selectedDate,
//               firstDate: DateTime(now.year - 1),
//               lastDate: now,
//             );
//             if (picked != null) {
//               setState(() {
//                 _selectedDate = picked;
//               });
//             }
//           },
//           child: Text(formatted),
//         ),
//       ],
//     );
//   }

//   Widget _buildFixedSwitch() {
//     return Row(
//       children: [
//         Switch(
//           value: _isFixed,
//           onChanged: (value) {
//             setState(() {
//               _isFixed = value;
//             });
//           },
//         ),
//         const SizedBox(width: 8),
//         const Expanded(
//           child: Text(
//             'Dépense fixe récurrente ?',
//             style: TextStyle(fontSize: 14),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildRecurrenceSettings() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         DropdownButtonFormField<ExpenseRecurrenceFrequency>(
//           initialValue: _recurrenceFrequency,
//           decoration: const InputDecoration(
//             labelText: 'Fréquence',
//             border: OutlineInputBorder(),
//           ),
//           items: const [
//             DropdownMenuItem(
//               value: ExpenseRecurrenceFrequency.weekly,
//               child: Text('Hebdomadaire'),
//             ),
//             DropdownMenuItem(
//               value: ExpenseRecurrenceFrequency.biWeekly,
//               child: Text('Bimensuel'),
//             ),
//             DropdownMenuItem(
//               value: ExpenseRecurrenceFrequency.monthly,
//               child: Text('Mensuel'),
//             ),
//             DropdownMenuItem(
//               value: ExpenseRecurrenceFrequency.quarterly,
//               child: Text('Trimestriel'),
//             ),
//             DropdownMenuItem(
//               value: ExpenseRecurrenceFrequency.annual,
//               child: Text('Annuel'),
//             ),
//           ],
//           onChanged: (value) {
//             setState(() {
//               _recurrenceFrequency = value;
//             });
//           },
//           validator: (value) {
//             if (_isFixed && value == null) {
//               return 'Choisissez une fréquence.';
//             }
//             return null;
//           },
//         ),
//         const SizedBox(height: 12),
//         if (_recurrenceFrequency == ExpenseRecurrenceFrequency.monthly)
//           TextFormField(
//             initialValue: _recurrenceDay?.toString(),
//             keyboardType: TextInputType.number,
//             decoration: const InputDecoration(
//               labelText: 'Jour du mois',
//               border: OutlineInputBorder(),
//             ),
//             onChanged: (value) {
//               final parsed = int.tryParse(value);
//               if (parsed == null || parsed < 1 || parsed > 31) {
//                 _recurrenceDay = null;
//               } else {
//                 _recurrenceDay = parsed;
//               }
//             },
//           ),
//         const SizedBox(height: 12),
//         Row(
//           children: [
//             Switch(
//               value: _autoAddNext,
//               onChanged: (value) {
//                 setState(() {
//                   _autoAddNext = value;
//                 });
//               },
//             ),
//             const SizedBox(width: 8),
//             const Expanded(
//               child: Text(
//                 'Ajouter automatiquement la prochaine occurrence',
//                 style: TextStyle(fontSize: 14),
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildPaymentMethodChips() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Moyen de paiement',
//           style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
//         ),
//         const SizedBox(height: 8),
//         Wrap(
//           spacing: 8,
//           children: [
//             _buildPaymentChip(
//               PaymentMethod.cash,
//               'Espèces',
//               FontAwesomeIcons.moneyBillWave,
//               color: Colors.green,
//             ),
//             _buildPaymentChip(
//               PaymentMethod.card,
//               'Carte',
//               FontAwesomeIcons.creditCard,
//               color: Colors.blue,
//             ),
//             _buildPaymentChip(
//               PaymentMethod.mobileMoney,
//               'Mobile Money',
//               FontAwesomeIcons.mobileAlt,
//               color: Colors.orange,
//             ),
//             _buildPaymentChip(
//               PaymentMethod.bankTransfer,
//               'Virement',
//               FontAwesomeIcons.university,
//               color: Colors.purple,
//             ),
//             _buildPaymentChip(
//               PaymentMethod.other,
//               'Autre',
//               FontAwesomeIcons.plus,
//               color: Colors.grey,
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildPaymentChip(
//     PaymentMethod method,
//     String label,
//     IconData icon, {
//     Color? color,
//   }) {
//     final selected = _paymentMethod == method;
//     return ChoiceChip(
//       label: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(
//             icon,
//             size: 16,
//             color: color ?? (selected ? Colors.white : Colors.black87),
//           ),
//           const SizedBox(width: 4),
//           Text(label),
//         ],
//       ),
//       selected: selected,
//       onSelected: (_) {
//         setState(() {
//           _paymentMethod = method;
//         });
//       },
//     );
//   }

//   Future<void> _onSave() async {
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }
//     if (_selectedCategoryId == null) {
//       setState(() {});
//       return;
//     }

//     setState(() {
//       _isSaving = true;
//     });

//     try {
//       final user = AuthService.instance.user.value;
//       if (user == null) {
//         throw Exception('Utilisateur non connecté.');
//       }

//       final amount = double.parse(_amountController.text.replaceAll(',', '.'));
//       double? rate;
//       if (_currency == Currency.usd) {
//         rate = await _exchangeRateService.getCurrentUsdToHtgRate();
//       }

//       final now = DateTime.now();
//       final nowMs = now.millisecondsSinceEpoch;

//       final isEditing = widget.initialExpense != null;
//       final expenseId =
//           widget.initialExpense?.expenseId ?? nowMs.toString();

//       final expense = Expense(
//         expenseId: expenseId,
//         userId: user.id,
//         amount: amount,
//         currencyAtEntry: _currency,
//         exchangeRateAtEntry: rate,
//         categoryId: _selectedCategoryId!,
//         description: _descriptionController.text.trim().isEmpty
//             ? null
//             : _descriptionController.text.trim(),
//         isFixed: _isFixed,
//         recurrenceFrequency: _isFixed ? _recurrenceFrequency : null,
//         recurrenceDay:
//             _isFixed &&
//                 _recurrenceFrequency == ExpenseRecurrenceFrequency.monthly
//             ? _recurrenceDay
//             : null,
//         autoAddNextOccurrence: _isFixed ? _autoAddNext : false,
//         date: _selectedDate,
//         paymentMethod: _paymentMethod,
//         receiptUrls: widget.initialExpense?.receiptUrls ?? const [],
//         aiCategorized: widget.initialExpense?.aiCategorized ?? false,
//         aiConfidence: widget.initialExpense?.aiConfidence,
//         createdAt: widget.initialExpense?.createdAt ?? now,
//         updatedAt: now,
//       );

//       // 1) Écriture OFFLINE-FIRST: local_only (synced=false) + enqueue operation.
//       await ExpenseLocalStore.instance.putExpense(
//         userId: user.id,
//         expense: expense,
//         synced: false,
//       );

//       if (isEditing) {
//         await ExpenseLocalStore.instance.enqueueUpdate(
//           userId: user.id,
//           expense: expense,
//           opCreatedAtMs: nowMs,
//         );
//       } else {
//         await ExpenseLocalStore.instance.enqueueCreate(
//           userId: user.id,
//           expense: expense,
//           opCreatedAtMs: nowMs,
//         );
//       }

//       // 2) Sync best-effort (ne pas bloquer l’UX).
//       ExpenseSyncService.instance.syncNow().catchError((_) {});

//       if (mounted) {
//         Navigator.of(context).pop<Expense>(expense);
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Dépense ajoutée avec succès.')),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isSaving = false;
//         });
//       }
//     }
//   }

//   List<_MockCategory> get _mockCategories => const [
//     _MockCategory(
//       id: 'food',
//       label: 'Nourriture',
//       icon: FontAwesomeIcons.utensils,
//       color: 0xFF4CAF50,
//     ),
//     _MockCategory(
//       id: 'transport',
//       label: 'Transport',
//       icon: FontAwesomeIcons.car,
//       color: 0xFF2196F3,
//     ),
//     _MockCategory(
//       id: 'shopping',
//       label: 'Shopping',
//       icon: FontAwesomeIcons.shoppingBag,
//       color: 0xFFFF9800,
//     ),
//     _MockCategory(
//       id: 'bills',
//       label: 'Factures',
//       icon: FontAwesomeIcons.lightbulb,
//       color: 0xFFFFC107,
//     ),
//     _MockCategory(
//       id: 'health',
//       label: 'Santé',
//       icon: FontAwesomeIcons.heart,
//       color: 0xFFF44336,
//     ),
//     _MockCategory(
//       id: 'education',
//       label: 'Éducation',
//       icon: FontAwesomeIcons.book,
//       color: 0xFF9C27B0,
//     ),
//     _MockCategory(
//       id: 'entertainment',
//       label: 'Loisirs',
//       icon: FontAwesomeIcons.headphones,
//       color: 0xFF3F51B5,
//     ),
//     _MockCategory(
//       id: 'other',
//       label: 'Autre',
//       icon: FontAwesomeIcons.plus,
//       color: 0xFF795548,
//     ),
//   ];
// }

// class _CurrencyChip extends StatelessWidget {
//   final String label;
//   // final String flag;
//   final bool selected;
//   final VoidCallback onTap;

//   const _CurrencyChip({
//     required this.label,
//     // required this.flag,
//     required this.selected,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 150),
//         padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
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
//             // Text(flag),
//             const SizedBox(width: 6),
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 color: selected ? Colors.blue : Colors.black87,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _MockCategory {
//   final String id;
//   final String label;
//   final IconData icon;
//   final int color;

//   const _MockCategory({
//     required this.id,
//     required this.label,
//     required this.icon,
//     required this.color,
//   });
// }
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/enums.dart';
import '../models/expense_model.dart';
import '../core/offline/expense_local_store.dart';
import '../core/offline/expense_sync_service.dart';
import '../services/auth_service.dart';
import '../services/exchange_rate_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/app_toast.dart';

class AddExpenseBottomSheet extends StatefulWidget {
  const AddExpenseBottomSheet({super.key, this.initialExpense});

  final Expense? initialExpense;

  @override
  State<AddExpenseBottomSheet> createState() => _AddExpenseBottomSheetState();
}

class _AddExpenseBottomSheetState extends State<AddExpenseBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _exchangeRateService = const ExchangeRateService();

  Currency _currency = Currency.htg;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  bool _isFixed = false;
  ExpenseRecurrenceFrequency? _recurrenceFrequency;
  int? _recurrenceDay;
  bool _autoAddNext = false;
  PaymentMethod? _paymentMethod;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialExpense;
    _amountController.text = initial?.amount.toStringAsFixed(2) ?? '0.00';
    _descriptionController.text = initial?.description ?? '';
    _currency = initial?.currencyAtEntry ?? Currency.htg;
    _selectedCategoryId = initial?.categoryId;
    _selectedDate = initial?.date ?? DateTime.now();
    _isFixed = initial?.isFixed ?? false;
    _recurrenceFrequency = initial?.recurrenceFrequency;
    _recurrenceDay = initial?.recurrenceDay;
    _autoAddNext = initial?.autoAddNextOccurrence ?? false;
    _paymentMethod = initial?.paymentMethod;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
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
                        widget.initialExpense == null
                            ? tr('add_expense.title')
                            : tr('common.edit'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
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
                          _buildCategorySelector(),
                          const SizedBox(height: 16),
                          _buildDescriptionField(),
                          const SizedBox(height: 16),
                          _buildDatePicker(context),
                          const SizedBox(height: 16),
                          _buildFixedSwitch(),
                          if (_isFixed) ...[
                            const SizedBox(height: 12),
                            _buildRecurrenceSettings(),
                          ],
                          const SizedBox(height: 16),
                          _buildPaymentMethodChips(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(),
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
                                  tr('add_expense.btn_save'),
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

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
      ],
      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: tr('add_expense.label_amount'),
        hintText: tr('add_expense.hint_amount'),
        border: const UnderlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return tr('add_expense.error_amount');
        }
        final parsed = double.tryParse(value.replaceAll(',', '.'));
        if (parsed == null || parsed <= 0) {
          return tr('add_expense.error_amount');
        }
        return null;
      },
    );
  }

  Widget _buildCurrencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('add_expense.label_currency'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _CurrencyChip(
              label: 'HTG',
              // flag: '🇭🇹',
              selected: _currency == Currency.htg,
              onTap: () => setState(() => _currency = Currency.htg),
            ),
            const SizedBox(width: 8),
            _CurrencyChip(
              label: "USD",
              // flag: '🇺🇸',
              selected: _currency == Currency.usd,
              onTap: () => setState(() => _currency = Currency.usd),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    final categories = _mockCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('add_expense.label_category'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.9,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            final isSelected = _selectedCategoryId == cat.id;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryId = cat.id;
                });
              },
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Color(cat.color).withValues(alpha: 0.15)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? Color(cat.color)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        cat.icon,
                        size: 26,
                        color: isSelected
                            ? Color(cat.color)
                            : Color(cat.color).withOpacity(0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cat.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
          },
        ),
        if (_selectedCategoryId == null)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Sélectionnez une catégorie.',
              style: TextStyle(fontSize: 11, color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: tr('add_expense.label_description'),
        hintText: tr('add_expense.hint_description'),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    final formatted =
        '${_selectedDate.day.toString().padLeft(2, '0')}/'
        '${_selectedDate.month.toString().padLeft(2, '0')}/'
        '${_selectedDate.year}';

    return Row(
      children: [
        const Icon(Icons.calendar_today, size: 18),
        const SizedBox(width: 8),
        Text(
          tr('add_expense.label_date'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        TextButton(
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(now.year - 1),
              lastDate: now,
            );
            if (picked != null) {
              setState(() {
                _selectedDate = picked;
              });
            }
          },
          child: Text(formatted),
        ),
      ],
    );
  }

  Widget _buildFixedSwitch() {
    return Row(
      children: [
        Switch(
          value: _isFixed,
          onChanged: (value) {
            setState(() {
              _isFixed = value;
            });
          },
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Dépense fixe récurrente ?',
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildRecurrenceSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<ExpenseRecurrenceFrequency>(
          value: _recurrenceFrequency,
          decoration: const InputDecoration(
            labelText: 'Fréquence',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: ExpenseRecurrenceFrequency.weekly,
              child: Text('Hebdomadaire'),
            ),
            DropdownMenuItem(
              value: ExpenseRecurrenceFrequency.biWeekly,
              child: Text('Bimensuel'),
            ),
            DropdownMenuItem(
              value: ExpenseRecurrenceFrequency.monthly,
              child: Text('Mensuel'),
            ),
            DropdownMenuItem(
              value: ExpenseRecurrenceFrequency.quarterly,
              child: Text('Trimestriel'),
            ),
            DropdownMenuItem(
              value: ExpenseRecurrenceFrequency.annual,
              child: Text('Annuel'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _recurrenceFrequency = value;
            });
          },
          validator: (value) {
            if (_isFixed && value == null) {
              return 'Choisissez une fréquence.';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        if (_recurrenceFrequency == ExpenseRecurrenceFrequency.monthly)
          TextFormField(
            initialValue: _recurrenceDay?.toString(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Jour du mois',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value);
              if (parsed == null || parsed < 1 || parsed > 31) {
                _recurrenceDay = null;
              } else {
                _recurrenceDay = parsed;
              }
            },
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Switch(
              value: _autoAddNext,
              onChanged: (value) {
                setState(() {
                  _autoAddNext = value;
                });
              },
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Ajouter automatiquement la prochaine occurrence',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethodChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Moyen de paiement',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildPaymentChip(
              PaymentMethod.cash,
              'Espèces',
              FontAwesomeIcons.moneyBillWave,
              color: Colors.green,
            ),
            _buildPaymentChip(
              PaymentMethod.card,
              'Carte',
              FontAwesomeIcons.creditCard,
              color: Colors.blue,
            ),
            _buildPaymentChip(
              PaymentMethod.mobileMoney,
              'Mobile Money',
              FontAwesomeIcons.mobileAlt,
              color: Colors.orange,
            ),
            _buildPaymentChip(
              PaymentMethod.bankTransfer,
              'Virement',
              FontAwesomeIcons.university,
              color: Colors.purple,
            ),
            _buildPaymentChip(
              PaymentMethod.other,
              'Autre',
              FontAwesomeIcons.plus,
              color: Colors.grey,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentChip(
    PaymentMethod method,
    String label,
    IconData icon, {
    Color? color,
  }) {
    final selected = _paymentMethod == method;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color ?? (selected ? Colors.white : Colors.black87),
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _paymentMethod = method;
        });
      },
    );
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedCategoryId == null) {
      setState(() {});
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = AuthService.instance.user.value;
      if (user == null) {
        throw Exception('Utilisateur non connecté.');
      }

      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      double? rate;
      if (_currency == Currency.usd) {
        rate = await _exchangeRateService.getCurrentUsdToHtgRate();
      }

      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      final isEditing = widget.initialExpense != null;
      final expenseId =
          widget.initialExpense?.expenseId ?? nowMs.toString();

      final expense = Expense(
        expenseId: expenseId,
        userId: user.id,
        amount: amount,
        currencyAtEntry: _currency,
        exchangeRateAtEntry: rate,
        categoryId: _selectedCategoryId!,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isFixed: _isFixed,
        recurrenceFrequency: _isFixed ? _recurrenceFrequency : null,
        recurrenceDay:
            _isFixed &&
                _recurrenceFrequency == ExpenseRecurrenceFrequency.monthly
            ? _recurrenceDay
            : null,
        autoAddNextOccurrence: _isFixed ? _autoAddNext : false,
        date: _selectedDate,
        paymentMethod: _paymentMethod,
        receiptUrls: widget.initialExpense?.receiptUrls ?? const [],
        aiCategorized: widget.initialExpense?.aiCategorized ?? false,
        aiConfidence: widget.initialExpense?.aiConfidence,
        createdAt: widget.initialExpense?.createdAt ?? now,
        updatedAt: now,
      );

      // 1) Écriture OFFLINE-FIRST: local_only (synced=false) + enqueue operation.
      await ExpenseLocalStore.instance.putExpense(
        userId: user.id,
        expense: expense,
        synced: false,
      );

      if (isEditing) {
        await ExpenseLocalStore.instance.enqueueUpdate(
          userId: user.id,
          expense: expense,
          opCreatedAtMs: nowMs,
        );
      } else {
        await ExpenseLocalStore.instance.enqueueCreate(
          userId: user.id,
          expense: expense,
          opCreatedAtMs: nowMs,
        );
      }

      // 2) Sync best-effort (ne pas bloquer l’UX).
      ExpenseSyncService.instance.syncNow().catchError((_) {});

      if (mounted) {
        Navigator.of(context).pop<Expense>(expense);
        AppToast.show(
          context,
          message: 'Dépense enregistrée',
          subtitle: isEditing ? 'Modification sauvegardée.' : 'Ajoutée offline, sync en cours.',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          message: 'Une erreur est survenue',
          subtitle: e.toString(),
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  List<_MockCategory> get _mockCategories => const [
    _MockCategory(
      id: 'food',
      label: 'Nourriture',
      icon: FontAwesomeIcons.utensils,
      color: 0xFF4CAF50,
    ),
    _MockCategory(
      id: 'transport',
      label: 'Transport',
      icon: FontAwesomeIcons.car,
      color: 0xFF2196F3,
    ),
    _MockCategory(
      id: 'shopping',
      label: 'Shopping',
      icon: FontAwesomeIcons.shoppingBag,
      color: 0xFFFF9800,
    ),
    _MockCategory(
      id: 'bills',
      label: 'Factures',
      icon: FontAwesomeIcons.lightbulb,
      color: 0xFFFFC107,
    ),
    _MockCategory(
      id: 'health',
      label: 'Santé',
      icon: FontAwesomeIcons.heart,
      color: 0xFFF44336,
    ),
    _MockCategory(
      id: 'education',
      label: 'Éducation',
      icon: FontAwesomeIcons.book,
      color: 0xFF9C27B0,
    ),
    _MockCategory(
      id: 'entertainment',
      label: 'Loisirs',
      icon: FontAwesomeIcons.headphones,
      color: 0xFF3F51B5,
    ),
    _MockCategory(
      id: 'other',
      label: 'Autre',
      icon: FontAwesomeIcons.plus,
      color: 0xFF795548,
    ),
  ];
}

class _CurrencyChip extends StatelessWidget {
  final String label;
  // final String flag;
  final bool selected;
  final VoidCallback onTap;

  const _CurrencyChip({
    required this.label,
    // required this.flag,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Text(flag),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.blue : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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