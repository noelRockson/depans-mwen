import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../core/l10n/app_locale.dart';
import '../core/offline/budget_sync_service.dart';
import '../core/offline/expense_sync_service.dart';
import '../core/offline/income_sync_service.dart';
import '../core/services/session_service.dart';
import '../models/enums.dart';
import '../services/auth_service.dart';
import '../services/exchange_rate_service.dart';
import 'income_management_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _syncing = false;

  Future<void> _forceSync() async {
    setState(() => _syncing = true);
    try {
      await Future.wait([
        ExpenseSyncService.instance.syncNow(),
        IncomeSyncService.instance.syncNow(),
        BudgetSyncService.instance.syncNow(),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('profile.sync_success'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('profile.sync_error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('auth.sign_out_confirm_title')),
        content: Text(tr('auth.sign_out_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              tr('auth.sign_out'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService.instance.signOut();
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('auth.delete_account_confirm_title')),
        content: Text(tr('auth.delete_account_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              tr('common.delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService.instance.signOut();
    }
  }

  void _showCurrencySelectorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr('currency_selector.title')),
        children: Currency.values.map((c) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${tr('profile.preferred_currency')} : ${c.code}',
                  ),
                ),
              );
            },
            child: Text(c.code),
          );
        }).toList(),
      ),
    );
  }

  void _showExchangeRateDialog() async {
    final rate = await const ExchangeRateService().getCurrentUsdToHtgRate();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('exchange_rate.title')),
        content: Text(
          '1 USD = ${rate.toStringAsFixed(2)} HTG\n\n${tr('exchange_rate.source_brh')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('common.ok')),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelectorDialog() {
    final currentLocale = context.locale;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return _LanguageSelectorSheet(
          currentLocale: currentLocale,
          onSelected: (locale) async {
            Navigator.of(sheetCtx).pop();
            await AppLocale.changeLocale(context, locale);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tr('language.changed')),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              setState(() {});
            }
          },
        );
      },
    );
  }

  void _showBiometricSettings() {
    final ss = SessionService.instance;
    showDialog(
      context: context,
      builder: (ctx) {
        bool enabled = ss.biometricEnabled;
        int minutes = ss.biometricAfterMinutes;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(tr('biometric.title')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text(tr('biometric.enable')),
                    value: enabled,
                    onChanged: (v) {
                      setDialogState(() => enabled = v);
                    },
                  ),
                  if (enabled)
                    Row(
                      children: [
                        Text(tr('biometric.delay_label')),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: minutes,
                          items: [
                            DropdownMenuItem(
                              value: 1,
                              child: Text(tr('biometric.delay_1min')),
                            ),
                            DropdownMenuItem(
                              value: 5,
                              child: Text(tr('biometric.delay_5min')),
                            ),
                            DropdownMenuItem(
                              value: 15,
                              child: Text(tr('biometric.delay_15min')),
                            ),
                            DropdownMenuItem(
                              value: 30,
                              child: Text(tr('biometric.delay_30min')),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => minutes = v);
                            }
                          },
                        ),
                      ],
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tr('common.cancel')),
                ),
                TextButton(
                  onPressed: () async {
                    await ss.updateBiometricEnabled(enabled);
                    await ss.updateBiometricAfterMinutes(minutes);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(tr('common.save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSessionTimeoutSettings() {
    final ss = SessionService.instance;
    showDialog(
      context: context,
      builder: (ctx) {
        int days = ss.sessionTimeoutDays;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(tr('session.title')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [7, 30, 90, -1].map((d) {
                  final label = d == -1
                      ? tr('session.never')
                      : tr('session.${d}days');
                  return RadioListTile<int>(
                    value: d,
                    groupValue: days,
                    title: Text(label),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => days = v);
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tr('common.cancel')),
                ),
                TextButton(
                  onPressed: () async {
                    await ss.updateSessionTimeoutDays(days);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(tr('common.save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AuthService.instance.user,
      builder: (context, user, _) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Text(
              tr('profile.title'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
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
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage: user?.photoUrl != null
                        ? NetworkImage(user!.photoUrl!)
                        : null,
                    child: user?.photoUrl == null
                        ? const Icon(Icons.person, size: 32, color: Colors.blue)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? tr('common.user'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_outline, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('profile.plan_free'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tr('profile.plan_premium_coming')),
                        ),
                      );
                    },
                    child: Text(tr('profile.plan_upgrade')),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _SectionTitle(title: tr('profile.section_financial')),
            const SizedBox(height: 8),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.attach_money,
                  label: tr('profile.my_incomes'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const IncomeManagementScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.currency_exchange,
                  label: tr('profile.preferred_currency'),
                  trailing: Text(
                    'HTG',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  onTap: _showCurrencySelectorDialog,
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.trending_up,
                  label: tr('profile.exchange_rate'),
                  onTap: _showExchangeRateDialog,
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.savings,
                  label: tr('profile.savings_goal'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tr('profile.savings_goal_coming')),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.category,
                  label: tr('profile.categories'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tr('profile.categories_coming')),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),
            _SectionTitle(title: tr('profile.section_settings')),
            const SizedBox(height: 8),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.language,
                  label: tr('profile.language'),
                  trailing: Text(
                    AppLocale.labelFor(context.locale),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  onTap: _showLanguageSelectorDialog,
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.notifications_none,
                  label: tr('profile.notifications'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tr('profile.notifications_coming')),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.fingerprint,
                  label: tr('profile.biometric_security'),
                  onTap: _showBiometricSettings,
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.timer,
                  label: tr('profile.session_expiry'),
                  onTap: _showSessionTimeoutSettings,
                ),
              ],
            ),

            const SizedBox(height: 24),
            _SectionTitle(title: tr('profile.section_data')),
            const SizedBox(height: 8),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.sync,
                  label: tr('profile.sync'),
                  trailing: _syncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _forceSync,
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.download,
                  label: tr('profile.export'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tr('profile.export_coming')),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),
            _SectionTitle(title: tr('profile.section_help')),
            const SizedBox(height: 8),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.help_outline,
                  label: tr('profile.guide'),
                  onTap: () {},
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.question_answer_outlined,
                  label: tr('profile.faq'),
                  onTap: () {},
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.email_outlined,
                  label: tr('profile.support'),
                  onTap: () {},
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.star_rate_outlined,
                  label: tr('profile.rate_app'),
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 24),
            _SectionTitle(title: tr('profile.section_legal')),
            const SizedBox(height: 8),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.article_outlined,
                  label: tr('profile.terms'),
                  onTap: () {},
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  label: tr('profile.privacy'),
                  onTap: () {},
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.info_outline,
                  label: tr('profile.version'),
                  trailing: Text(
                    '1.4.0',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 24),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.logout,
                  label: tr('profile.logout'),
                  onTap: _confirmSignOut,
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.delete_forever,
                  label: tr('profile.delete_account'),
                  labelColor: Colors.red,
                  onTap: _confirmDeleteAccount,
                ),
              ],
            ),

            const SizedBox(height: 100),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.labelColor,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: labelColor ?? Colors.black54),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? Colors.black87,
                ),
              ),
            ),
            ?trailing,
            if (trailing == null)
              Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ── Language selector bottom sheet ──────────────────────────────────────────

class _LanguageSelectorSheet extends StatelessWidget {
  final Locale currentLocale;
  final void Function(Locale) onSelected;

  const _LanguageSelectorSheet({
    required this.currentLocale,
    required this.onSelected,
  });

  static const _languages = [
    (locale: Locale('fr'), flag: '🇫🇷', label: 'Français', sub: 'French'),
    (locale: Locale('ht'), flag: '🇭🇹', label: 'Kreyòl Ayisyen', sub: 'Haitian Creole'),
    (locale: Locale('en'), flag: '🇺🇸', label: 'English', sub: 'Anglais'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF0F4F8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4AC9FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    color: Color(0xFF1A9ED4),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('language.title'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      tr('profile.language'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Language options
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: _languages.asMap().entries.map((entry) {
                  final i = entry.key;
                  final lang = entry.value;
                  final isSelected = currentLocale.languageCode == lang.locale.languageCode;
                  final isLast = i == _languages.length - 1;

                  return Column(
                    children: [
                      InkWell(
                        onTap: () => onSelected(lang.locale),
                        borderRadius: BorderRadius.vertical(
                          top: i == 0 ? const Radius.circular(20) : Radius.zero,
                          bottom: isLast ? const Radius.circular(20) : Radius.zero,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF4AC9FF).withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.vertical(
                              top: i == 0 ? const Radius.circular(20) : Radius.zero,
                              bottom: isLast ? const Radius.circular(20) : Radius.zero,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Flag in a pill
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF4AC9FF).withValues(alpha: 0.12)
                                      : const Color(0xFFF0F4F8),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    lang.flag,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Labels
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.label,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? const Color(0xFF1A9ED4)
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      lang.sub,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Check indicator
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: isSelected
                                    ? Container(
                                        key: const ValueKey('check'),
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4AC9FF),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF4AC9FF)
                                                  .withValues(alpha: 0.35),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      )
                                    : const SizedBox(
                                        key: ValueKey('empty'),
                                        width: 26,
                                        height: 26,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!isLast)
                        const Divider(height: 1, indent: 76, endIndent: 16),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
