import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/services/session_service.dart';
import '../core/offline/expense_sync_service.dart';
import '../core/offline/income_sync_service.dart';
import '../core/offline/budget_sync_service.dart';
import '../pages/dashboard.dart';
import '../pages/onboarding_screen.dart';
import 'login.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

void _log(String msg) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('[SessionGate] $msg');
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> with WidgetsBindingObserver {
  bool _checking = true;
  bool _locked = false;
  DateTime? _lastPausedAt;
  Timer? _authCheckDebounce;
  String? _resolvedForUserId;
  bool _flowInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SessionService.instance.onboardingCompleted.addListener(_onOnboardingChanged);
    AuthService.instance.user.addListener(_onAuthChanged);
    _startFlow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authCheckDebounce?.cancel();
    SessionService.instance.onboardingCompleted.removeListener(_onOnboardingChanged);
    AuthService.instance.user.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onOnboardingChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onAuthChanged() {
    final user = AuthService.instance.user.value;
    final userId = user?.id;

    _log('_onAuthChanged: userId=$userId flowInProgress=$_flowInProgress resolvedFor=$_resolvedForUserId');

    if (userId == null) {
      _resolvedForUserId = null;
      if (mounted) setState(() => _locked = false);
      return;
    }

    if (_flowInProgress) return;
    if (_resolvedForUserId == userId) return;

    _flowInProgress = true;
    if (mounted) setState(() => _checking = true);

    _runSessionFlowAndUpdateUi(userId).whenComplete(() {
      _flowInProgress = false;
      if (!mounted) return;
      _log('_onAuthChanged flow complete: user=${AuthService.instance.user.value?.id} onboarding=${SessionService.instance.onboardingCompleted.value}');
      setState(() => _checking = false);
    });
  }

  Future<void> _runSessionFlowAndUpdateUi(String userId) async {
    final current = AuthService.instance.user.value;
    if (current?.id != userId) {
      _log('_runSessionFlowAndUpdateUi: user changed mid-flight, aborting');
      return;
    }

    try {
      await _resolveInitial();
    } catch (e) {
      _log('_runSessionFlowAndUpdateUi: _resolveInitial threw: $e');
    }

    // After the flow: verify user is still signed in.
    final stillSignedIn = AuthService.instance.user.value != null;
    _log('_runSessionFlowAndUpdateUi done: stillSignedIn=$stillSignedIn onboarding=${SessionService.instance.onboardingCompleted.value}');
  }

  Future<void> _startFlow() async {
    _flowInProgress = true;
    _log('_startFlow: initializing SessionService...');
    try {
      await SessionService.instance.init();
    } catch (e, st) {
      _log('_startFlow: SessionService.init failed: $e');
      _log('startFlow stack: $st');
    }

    if (!mounted) {
      _flowInProgress = false;
      return;
    }

    setState(() => _checking = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) {
      _flowInProgress = false;
      return;
    }

    _log('_startFlow: running _resolveInitial...');
    try {
      await _resolveInitial();
    } catch (e, st) {
      _log('_startFlow: _resolveInitial threw: $e');
      _log('resolveInitial stack: $st');
    }

    if (!mounted) {
      _flowInProgress = false;
      return;
    }

    _log('_startFlow complete: user=${AuthService.instance.user.value?.id} onboarding=${SessionService.instance.onboardingCompleted.value}');
    setState(() => _checking = false);
    _flowInProgress = false;
  }

  Future<void> _resolveInitial() async {
    final user = AuthService.instance.user.value;
    _log('_resolveInitial: user=${user?.id}');

    if (user == null) {
      _log('_resolveInitial: no user -> unbind');
      await SessionService.instance.unbindUser();
      return;
    }

    // Step 1: bind user + load local preferences
    await SessionService.instance.bindUser(user);
    _resolvedForUserId = user.id;

    // Step 2: check session timeout
    final timedOut = await SessionService.instance.isSessionTimedOut();
    if (timedOut) {
      _log('_resolveInitial: session timed out -> lockout');
      await SessionService.instance.lockoutAndSignOut();
      return;
    }

    // Step 3: refresh onboarding from remote (best-effort, non-blocking for OAuth)
    try {
      await SessionService.instance.refreshOnboardingFromRemoteBestEffort();
    } catch (e) {
      _log('_resolveInitial: refreshOnboarding error (ignored): $e');
    }

    // Step 4: mark session active
    await SessionService.instance.touch();

    // Step 5: best-effort data synchronization (fire-and-forget)
    _log('_resolveInitial: launching sync services...');
    ExpenseSyncService.instance.syncNow().catchError((_) {});
    IncomeSyncService.instance.syncNow().catchError((_) {});
    BudgetSyncService.instance.syncNow().catchError((_) {});

    // Step 6: biometric prompt (only if enabled AND device supports it)
    _log('_resolveInitial: biometricEnabled=${SessionService.instance.biometricEnabled}');
    if (SessionService.instance.biometricEnabled) {
      final ok = await SessionService.instance.promptBiometricUnlock();
      _log('_resolveInitial: biometric result=$ok');
      if (!ok) {
        _log('_resolveInitial: biometric FAILED -> lockout');
        await SessionService.instance.lockoutAndSignOut();
        return;
      }
    }

    _log('_resolveInitial: done successfully. onboarding=${SessionService.instance.onboardingCompleted.value}');
  }

  Future<void> _maybePromptOnResume() async {
    if (_locked) return;

    final user = AuthService.instance.user.value;
    if (user == null) return;

    if (!SessionService.instance.biometricEnabled) return;
    final pausedAt = _lastPausedAt;
    if (pausedAt == null) return;

    final minutes = DateTime.now().difference(pausedAt).inMinutes;
    if (minutes < SessionService.instance.biometricAfterMinutes) return;

    await SessionService.instance.bindUser(user);

    if (await SessionService.instance.isSessionTimedOut()) {
      await SessionService.instance.lockoutAndSignOut();
      if (!mounted) return;
      setState(() => _locked = false);
      return;
    }
    setState(() => _locked = true);

    final ok = await SessionService.instance.promptBiometricUnlock();
    if (!ok) {
      await SessionService.instance.lockoutAndSignOut();
      if (!mounted) return;
      setState(() => _locked = false);
      return;
    }

    await SessionService.instance.touch();
    if (!mounted) return;
    setState(() => _locked = false);

    ExpenseSyncService.instance.syncNow().catchError((_) {});
    IncomeSyncService.instance.syncNow().catchError((_) {});
    BudgetSyncService.instance.syncNow().catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _lastPausedAt = DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _authCheckDebounce?.cancel();
      _authCheckDebounce = Timer(const Duration(milliseconds: 250), () async {
        if (!mounted) return;
        await _maybePromptOnResume();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: AuthService.instance.user,
      builder: (context, user, _) {
        _log('build: _checking=$_checking user=${user?.id} onboarding=${SessionService.instance.onboardingCompleted.value} locked=$_locked');

        if (_checking) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (user == null) {
          return const LoginPage();
        }

        final onboardingDone = SessionService.instance.onboardingCompleted.value;

        return Stack(
          children: [
            if (onboardingDone) const DashboardScreen() else const OnboardingScreen(),
            if (_locked) const _LockedOverlay(),
          ],
        );
      },
    );
  }
}

class _LockedOverlay extends StatelessWidget {
  const _LockedOverlay();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: true,
      child: Container(
        color: Colors.black.withOpacity(0.55),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 16),
              Text(
                'Deverrouillage requis...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
