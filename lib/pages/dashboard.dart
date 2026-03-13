import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/exchange_rate_service.dart';

enum _DashboardCurrencyView { combined, split }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _exchangeRateService = const ExchangeRateService();
  _DashboardCurrencyView _view = _DashboardCurrencyView.combined;
  int _selectedTab = 0;

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
          extendBody: true, // Important for the floating transparent nav bar
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                _buildBody(user),
                // Floating Bottom Navigation Bar
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: _buildFloatingNavBar(),
                ),
              ],
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
        );
      },
    );
  }

  Widget _buildBody(UserModel user) {
    if (_selectedTab == 1) {
      return const Center(child: Text('TransactionsScreen (à implémenter)'));
    }
    if (_selectedTab == 2) {
      return const Center(child: Text('StatisticsScreen (à implémenter)'));
    }
    if (_selectedTab == 3) {
      return const Center(child: Text('ProfileScreen (à implémenter)'));
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
                  '$greeting 👋',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  user.displayName ?? 'Utilisateur',
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
        )
      ],
    );
  }

  Widget _buildBalanceOverview() {
    final isCombined = _view == _DashboardCurrencyView.combined;

    if (isCombined) {
      return Container(
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
              color: const Color(0xFF4AC9FF).withValues(alpha: (0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Solde Total',
              style: TextStyle(
                fontSize: 14, 
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '0 HTG',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _MiniStatPill(
                    label: 'Revenus',
                    value: '0 HTG',
                    icon: Icons.arrow_downward,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: (0.2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStatPill(
                    label: 'Dépenses',
                    value: '0 HTG',
                    icon: Icons.arrow_upward,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: (0.2),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE4F0D0), Color(0xFFB5DE9E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB5DE9E).withValues(alpha: (0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Solde HTG',
                      style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '0 HTG',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    SizedBox(height: 16),
                    _MiniStatPillSmall(label: 'Rev', value: '0', icon: Icons.arrow_downward, color: Colors.green),
                    SizedBox(height: 8),
                    _MiniStatPillSmall(label: 'Dép', value: '0', icon: Icons.arrow_upward, color: Colors.red),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF9E8D9), Color(0xFFF1C0B3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF1C0B3).withValues(alpha: (0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Solde USD',
                      style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '0 USD',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    SizedBox(height: 16),
                    _MiniStatPillSmall(label: 'Rev', value: '0', icon: Icons.arrow_downward, color: Colors.green),
                    SizedBox(height: 8),
                    _MiniStatPillSmall(label: 'Dép', value: '0', icon: Icons.arrow_upward, color: Colors.red),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Actions Rapides',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _IconBoxButton(
              label: 'Dépense',
              icon: Icons.add,
              color: const Color(0xFFFF9F43),
              onTap: _showAddExpenseSheet,
            ),
            _IconBoxButton(
              label: 'Reçu',
              icon: Icons.document_scanner,
              color: const Color(0xFF00CFE8),
              onTap: () {},
            ),
            _IconBoxButton(
              label: 'Budgets',
              icon: Icons.pie_chart_outline,
              color: const Color(0xFF28C76F),
              onTap: () {},
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Transactions récentes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            Text(
              'Voir tout',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            )
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: (0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: const [
              Icon(Icons.receipt_long, size: 36, color: Colors.black26),
              SizedBox(height: 12),
              Text(
                'Aucune transaction pour le moment',
                style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveBudgets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Budgets actifs',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: (0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: const [
              Icon(Icons.account_balance_wallet_outlined, size: 36, color: Colors.black26),
              SizedBox(height: 12),
              Text(
                'Aucun budget actif',
                style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExchangeRateImpact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Taux de Change',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
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
                color: Colors.black.withValues(alpha: (0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FutureBuilder<double>(
            future: _exchangeRateService.getCurrentUsdToHtgRate(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Row(
                  children: [
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Chargement du taux en cours...', style: TextStyle(color: Colors.black54)),
                  ],
                );
              }

              if (snapshot.hasError) {
                return const Text('Impossible de récupérer le taux de change.', style: TextStyle(color: Colors.black54));
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
                    child: const Icon(Icons.currency_exchange, color: Colors.blue),
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
                        const Text(
                          'Taux actuel. Impact détaillé plus tard.',
                          style: TextStyle(fontSize: 12, color: Colors.black45),
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
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: (0.85),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: (0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: (0.1),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavBarItem(
                icon: Icons.home_rounded,
                isSelected: _selectedTab == 0,
                onTap: () => setState(() => _selectedTab = 0),
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

  void _showAddExpenseSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: const Text('AddExpenseBottomSheet (à implémenter)', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  String _timeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
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
              color: Colors.black.withValues(alpha: (0.04),
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
                  color: color.withValues(alpha: (0.9),
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
            color: color.withValues(alpha: (0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 12),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
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
                  color: color.withValues(alpha: (0.15),
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
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.black45,
          size: 26,
        ),
      ),
    );
  }
}

