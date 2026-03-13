import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:auth_buttons/auth_buttons.dart';
import 'package:google_fonts/google_fonts.dart';

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

  @override
  Widget build(BuildContext context) {
    final isSignUp = _mode == AuthMode.signUp;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F1419),
              const Color(0xFF1A1F2E),
              const Color(0xFF0F1419),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20,
              ),
              child: FadeTransition(
                opacity: _fadeController ?? const AlwaysStoppedAnimation(1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo section
                    Padding(
                      padding: const EdgeInsets.only(top: 20.0, bottom: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade400,
                                    Colors.purple.shade400,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.shield,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'ExpenseTracker',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Gérez vos finances simplement',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Title
                    Text(
                      isSignUp ? 'Créer un compte' : 'Se connecter',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSignUp
                          ? 'Rejoignez-nous pour commencer.'
                          : 'Bienvenue à nouveau',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Error message
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    // Info message
                    if (_infoMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _infoMessage!,
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    // Form
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(
                                color: Colors.grey.shade400,
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: Colors.grey.shade600,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.blue,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF1A1F2E),
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

                          // Password field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              labelStyle: TextStyle(
                                color: Colors.grey.shade400,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outlined,
                                color: Colors.grey.shade600,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey.shade600,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.blue,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF1A1F2E),
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

                          // Confirm password field (Sign up only)
                          if (isSignUp) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Confirmer le mot de passe',
                                labelStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outlined,
                                  color: Colors.grey.shade600,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey.shade600,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.blue,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF1A1F2E),
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

                          // Submit button
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade600,
                                  Colors.blue.shade400,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isEmailLoading ? null : _submit,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: _isEmailLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          isSignUp
                                              ? 'Créer un compte'
                                              : 'Se connecter',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),

                          if (!isSignUp) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isEmailLoading
                                    ? null
                                    : _resetPassword,
                                child: Text(
                                  'Mot de passe oublié ?',
                                  style: GoogleFonts.poppins(
                                    color: Colors.blue.shade400,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.grey.shade700,
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                  ),
                                  child: Text(
                                    'ou',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.grey.shade700,
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // OAuth sign-in buttons (icon-only)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GoogleAuthButton(
                                  onPressed: _isGoogleLoading
                                      ? () {}
                                      : () => _signInWithGoogle(),
                                  isLoading: _isGoogleLoading,
                                  style: AuthButtonStyle(
                                    buttonType: AuthButtonType.icon,
                                    width: 50,
                                    height: 50,
                                    borderColor: Colors.grey.shade600,
                                  ),
                                ),
                                if (_showAppleSignIn) ...[
                                  const SizedBox(width: 12),
                                  AppleAuthButton(
                                    onPressed: _isAppleLoading
                                        ? () {}
                                        : () => _signInWithApple(),
                                    isLoading: _isAppleLoading,
                                    style: AuthButtonStyle(
                                      buttonType: AuthButtonType.icon,
                                      width: 50,
                                      height: 50,
                                      buttonColor: const Color.fromARGB(
                                        255,
                                        255,
                                        255,
                                        255,
                                      ),
                                      borderColor: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Toggle between sign in and sign up
                          Center(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: isSignUp
                                        ? 'J\'ai déjà un compte? '
                                        : 'Pas encore de compte? ',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey.shade400,
                                      fontSize: 14,
                                    ),
                                  ),
                                  TextSpan(
                                    text: isSignUp
                                        ? 'Se connecter'
                                        : 'S\'inscrire',
                                    style: GoogleFonts.poppins(
                                      color: Colors.blue.shade400,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
