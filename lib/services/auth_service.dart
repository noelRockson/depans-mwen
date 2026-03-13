import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/user_model.dart';

class AuthService {
  AuthService._privateConstructor();
  static final AuthService instance = AuthService._privateConstructor();

  final ValueNotifier<UserModel?> user = ValueNotifier(null);
  bool _initialized = false;

  /// Must be called exactly once before using other methods.
  Future<void> ensureInitialized() async {
    if (_initialized) return;

    try {
      await GoogleSignIn.instance.initialize();
      FirebaseAuth.instance.authStateChanges().listen((firebaseUser) {
        user.value = _toUserModel(firebaseUser);
      });
      _initialized = true;
    } catch (e) {
      // ignore: avoid_print
      print('AuthService init failed: $e');
    }
  }

  UserModel? _toUserModel(User? firebaseUser) {
    if (firebaseUser == null) return null;
    return UserModel(
      id: firebaseUser.uid,
      displayName: firebaseUser.displayName,
      email: firebaseUser.email,
      photoUrl: firebaseUser.photoURL,
      provider: firebaseUser.providerData.isNotEmpty
          ? firebaseUser.providerData.first.providerId
          : 'firebase',
    );
  }

  /// Signs in using email + password (existing account).
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    user.value = _toUserModel(credential.user);
  }

  /// Creates an account with email + password.
  Future<void> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    user.value = _toUserModel(credential.user);
  }

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  /// Signs in using Google (Android/iOS/web).
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      final userCredential = await FirebaseAuth.instance.signInWithPopup(
        googleProvider,
      );
      user.value = _toUserModel(userCredential.user);
      return;
    }

    // The new google_sign_in API requires initialization before usage.
    await GoogleSignIn.instance.initialize();

    final GoogleSignInAccount account = await GoogleSignIn.instance
        .authenticate();

    final authentication = account.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: authentication.idToken,
    );

    final userCredential = await FirebaseAuth.instance.signInWithCredential(
      credential,
    );
    user.value = _toUserModel(userCredential.user);
  }

  /// Signs in using Apple (iOS/macOS).
  Future<void> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    final userCredential = await FirebaseAuth.instance.signInWithCredential(
      oauthCredential,
    );
    user.value = _toUserModel(userCredential.user);
  }

  /// Signs out the current user (and clears local state).
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    if (user.value?.provider == 'google') {
      await GoogleSignIn.instance.signOut();
    }
    user.value = null;
  }
}
