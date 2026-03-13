import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'App Manager',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.instance.signOut();
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<UserModel?>(
        valueListenable: AuthService.instance.user,
        builder: (context, user, _) {
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user.photoUrl != null) ...[
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(user.photoUrl!),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Bonjour, ${user.displayName ?? 'Utilisateur'}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connecté avec ${user.provider}',
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
