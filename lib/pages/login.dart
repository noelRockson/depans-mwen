import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:auth_buttons/auth_buttons.dart';
import 'package:flutter_svg/svg.dart';

import '../services/auth_service.dart';

enum AuthMode { signIn, signUp }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  AuthMode _mode = AuthMode.signIn;
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  String? _errorMessage;
  String? _infoMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  AnimationController? _fadeController;

  // ── Couleurs harmonisées avec dashboard.dart ─────────────────────────────
  static const _bgColor = Color(0xFFF0F4F8);
  static const _cardColor = Colors.white;
  static const _accentBlue = Color(0xFF4AC9FF);
  static const _accentBlueDeep = Color(0xFF1A9ED4);
  static const _textDark = Color(0xFF1A1A2E);
  static const _textMuted = Colors.black54;
  static const _borderColor = Color(0xFFDDE3EC);

  bool get _showAppleSignIn {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  bool get _isAnyLoading =>
      _isEmailLoading || _isGoogleLoading || _isAppleLoading;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeController?.forward();
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isEmailLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      if (_mode == AuthMode.signIn) {
        await AuthService.instance.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await AuthService.instance.registerWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isEmailLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez entrer votre email pour réinitialiser.';
      });
      return;
    }

    setState(() {
      _isEmailLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await AuthService.instance.sendPasswordResetEmail(
        _emailController.text.trim(),
      );
      setState(() {
        _infoMessage =
            'Email de réinitialisation envoyé. Vérifiez votre boîte de réception.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isEmailLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await AuthService.instance.signInWithGoogle();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isAppleLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await AuthService.instance.signInWithApple();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAppleLoading = false;
        });
      }
    }
  }

  // ── InputDecoration réutilisable ─────────────────────────────────────────
  InputDecoration _fieldDecoration({
    required String label,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textMuted, fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: _accentBlueDeep, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _bgColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accentBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = _mode == AuthMode.signUp;

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: FadeTransition(
            opacity: _fadeController ?? const AlwaysStoppedAnimation(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo / En-tête ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 0, bottom: 7),
                  child: Center(
                    child: Column(
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -1),
                          child:  SvgPicture.asset(
                            'lib/assets/images/logo.svg',
                            height: 165,
                            fit: BoxFit.contain,
                          ),
                        ),
                       
                        const Text(
                          'ExpenseTracker',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: _textDark,
                            letterSpacing: 0.3,
                          ),
                        
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Gérez vos finances simplement',
                          style: TextStyle(
                            fontSize: 13,
                            color: _textMuted,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ) ,

                // ── Carte principale ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Titre
                      Text(
                        isSignUp ? 'Créer un compte' : 'Se connecter',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSignUp
                            ? tr('app_name')
                            : tr('greeting.morning'),
                        style: const TextStyle(fontSize: 13, color: _textMuted),
                      ),
                      const SizedBox(height: 24),

                      // Message d'erreur
                      if (_errorMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Message d'info
                      if (_infoMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _infoMessage!,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Formulaire
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Email
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                color: _textDark,
                                fontSize: 14,
                              ),
                              decoration: _fieldDecoration(
                                label: 'Email',
                                prefixIcon: Icons.email_outlined,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Veuillez entrer un email.';
                                }
                                if (!value.contains('@')) {
                                  return 'Email invalide.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Mot de passe
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(
                                color: _textDark,
                                fontSize: 14,
                              ),
                              decoration: _fieldDecoration(
                                label: 'Mot de passe',
                                prefixIcon: Icons.lock_outlined,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: _textMuted,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Veuillez entrer un mot de passe.';
                                }
                                if (value.trim().length < 6) {
                                  return 'Le mot de passe doit contenir au moins 6 caractères.';
                                }
                                return null;
                              },
                            ),

                            // Confirmer mot de passe (inscription)
                            if (isSignUp) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                style: const TextStyle(
                                  color: _textDark,
                                  fontSize: 14,
                                ),
                                decoration: _fieldDecoration(
                                  label: 'Confirmer le mot de passe',
                                  prefixIcon: Icons.lock_outlined,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: _textMuted,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Veuillez confirmer le mot de passe.';
                                  }
                                  if (value.trim() !=
                                      _passwordController.text.trim()) {
                                    return 'Les mots de passe ne correspondent pas.';
                                  }
                                  return null;
                                },
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Bouton principal — gradient identique à la balance card
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8CE1FA),
                                    Color(0xFF4AC9FF),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _accentBlue.withValues(alpha: 0.30),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isEmailLoading ? null : _submit,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: _isEmailLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                      Colors.white,
                                                    ),
                                              ),
                                            ),
                                          )
                                        : Text(
                                            isSignUp
                                                ? 'Créer un compte'
                                                : 'Se connecter',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),

                            // Mot de passe oublié + OAuth (connexion uniquement)
                            if (!isSignUp) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isEmailLoading
                                      ? null
                                      : _resetPassword,
                                  style: TextButton.styleFrom(
                                    foregroundColor: _accentBlueDeep,
                                  ),
                                  child: const Text(
                                    'Mot de passe oublié ?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),

                              // Séparateur
                              Row(
                                children: [
                                  const Expanded(
                                    child: Divider(
                                      color: _borderColor,
                                      thickness: 1,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      'ou',
                                      style: TextStyle(
                                        color: _textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    child: Divider(
                                      color: _borderColor,
                                      thickness: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Boutons OAuth
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GoogleAuthButton(
                                    onPressed: _isGoogleLoading
                                        ? () {}
                                        : _signInWithGoogle,
                                    isLoading: _isGoogleLoading,
                                    style: AuthButtonStyle(
                                      buttonType: AuthButtonType.icon,
                                      width: 52,
                                      height: 52,
                                      borderColor: _borderColor,
                                      buttonColor: _cardColor,
                                    ),
                                  ),
                                  if (_showAppleSignIn) ...[
                                    const SizedBox(width: 12),
                                    AppleAuthButton(
                                      onPressed: _isAppleLoading
                                          ? () {}
                                          : _signInWithApple,
                                      isLoading: _isAppleLoading,
                                      style: AuthButtonStyle(
                                        buttonType: AuthButtonType.icon,
                                        width: 52,
                                        height: 52,
                                        buttonColor: _cardColor,
                                        borderColor: _borderColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Basculer connexion / inscription ────────────────────────
                Center(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: isSignUp
                              ? "J'ai déjà un compte ? "
                              : "Pas encore de compte ? ",
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 14,
                          ),
                        ),
                        TextSpan(
                          text: isSignUp ? 'Se connecter' : "S'inscrire",
                          style: const TextStyle(
                            color: _accentBlueDeep,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = _isAnyLoading
                                ? null
                                : () {
                                    setState(() {
                                      _mode = isSignUp
                                          ? AuthMode.signIn
                                          : AuthMode.signUp;
                                      _errorMessage = null;
                                      _infoMessage = null;
                                    });
                                  },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}