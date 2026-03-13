import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:app_base_ui/pages/login.dart';
import 'package:app_base_ui/services/auth_service.dart';
import 'package:app_base_ui/models/user_model.dart';
import 'package:app_base_ui/pages/dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await AuthService.instance.ensureInitialized();
  } catch (e) {
    // ignore: avoid_print
    print('Initialization error: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      theme: ThemeData(useMaterial3: true),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<UserModel?>(
        valueListenable: AuthService.instance.user,
        builder: (context, user, _) {
          if (user == null) {
            return const LoginPage();
          }
          return const DashboardScreen();
        },
      ),
    );
  }
}
