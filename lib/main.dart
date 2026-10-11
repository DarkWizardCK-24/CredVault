import 'package:cred_vault/app.dart';
import 'package:cred_vault/core/password/breach_checker.dart';
import 'package:cred_vault/firebase_options.dart';
import 'package:cred_vault/providers/auth_provider.dart';
import 'package:cred_vault/providers/vault_provider.dart';
import 'package:cred_vault/services/settings_service.dart';
import 'package:cred_vault/services/vault_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final settings = SettingsService();
  await settings.load();

  runApp(
    CredVaultApp(
      auth: FirebaseAuthProvider(),
      vault: VaultProvider(
        repository: FirestoreVaultRepository(),
        breachChecker: HibpBreachChecker(),
      ),
      settings: settings,
    ),
  );
}
