import 'package:cred_vault/core/password/password_generator.dart';
import 'package:cred_vault/screens/add_credential_screen.dart';
import 'package:cred_vault/theme/app_theme.dart';
import 'package:cred_vault/widgets/generator_panel.dart';
import 'package:flutter/material.dart';

/// The generator tab: make a strong password and optionally save it.
class GeneratorScreen extends StatelessWidget {
  /// Injectable for tests (a seeded generator gives repeatable output).
  final PasswordGenerator? generator;

  const GeneratorScreen({super.key, this.generator});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              const Text(
                'Generator',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Random, unique and impossible to guess',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              GeneratorPanel(
                generator: generator,
                useLabel: 'Save as a new login',
                useIcon: Icons.add_rounded,
                onUse: (password) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AddCredentialScreen(initialPassword: password),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
