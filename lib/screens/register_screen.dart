import 'package:cred_vault/core/password/password_strength.dart';
import 'package:cred_vault/core/validators.dart';
import 'package:cred_vault/providers/auth_provider.dart';
import 'package:cred_vault/providers/vault_provider.dart';
import 'package:cred_vault/theme/app_theme.dart';
import 'package:cred_vault/widgets/custom_button.dart';
import 'package:cred_vault/widgets/custom_text_field.dart';
import 'package:cred_vault/widgets/glass_container.dart';
import 'package:cred_vault/widgets/snackbar_helper.dart';
import 'package:cred_vault/widgets/strength_meter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _accountPassword = TextEditingController();
  final _master = TextEditingController();
  final _masterConfirm = TextEditingController();

  bool _obscureAccount = true;
  bool _obscureMaster = true;
  bool _understood = false;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _accountPassword.dispose();
    _master.dispose();
    _masterConfirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_understood) {
      SnackBarHelper.showError(
        context,
        'Please confirm that you understand the master password cannot be recovered.',
      );
      return;
    }
    setState(() => _loading = true);

    final vault = context.read<VaultProvider>();
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    try {
      await vault.registerAccount(
        auth: auth,
        name: _name.text,
        email: _email.text,
        accountPassword: _accountPassword.text,
        masterPassword: _master.text,
      );
      // The app root now shows the unlocked vault; drop this screen.
      navigator.popUntil((route) => route.isFirst);
    } on AuthFailure catch (e) {
      if (mounted) SnackBarHelper.showError(context, e.message);
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          "We couldn't finish creating your vault. Please try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _visibilityToggle(bool obscure, VoidCallback onTap) => IconButton(
    tooltip: obscure ? 'Show password' : 'Hide password',
    icon: Icon(
      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
    ),
    onPressed: onTap,
  );

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrengthEstimator.evaluate(_master.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Create your vault')),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SectionLabel(
                        icon: Icons.person_outline_rounded,
                        title: 'Your account',
                        subtitle: 'Used to sign in on any device.',
                      ),
                      GlassContainer(
                        child: Column(
                          children: [
                            CustomTextField(
                              controller: _name,
                              label: 'Full name',
                              prefixIcon: Icons.badge_outlined,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              validator: (v) => Validators.required(
                                v,
                                'Please enter your name',
                              ),
                            ),
                            const SizedBox(height: 14),
                            CustomTextField(
                              controller: _email,
                              label: 'Email',
                              prefixIcon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: Validators.email,
                            ),
                            const SizedBox(height: 14),
                            CustomTextField(
                              controller: _accountPassword,
                              label: 'Account password',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: _obscureAccount,
                              textInputAction: TextInputAction.next,
                              validator: Validators.accountPassword,
                              suffixIcon: _visibilityToggle(
                                _obscureAccount,
                                () => setState(
                                  () => _obscureAccount = !_obscureAccount,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      const _SectionLabel(
                        icon: Icons.shield_moon_outlined,
                        title: 'Your master password',
                        subtitle:
                            'Encrypts everything in your vault. It never leaves '
                            'this device.',
                      ),
                      GlassContainer(
                        child: Column(
                          children: [
                            CustomTextField(
                              controller: _master,
                              label: 'Master password',
                              prefixIcon: Icons.key_rounded,
                              obscureText: _obscureMaster,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                              validator: Validators.masterPassword,
                              suffixIcon: _visibilityToggle(
                                _obscureMaster,
                                () => setState(
                                  () => _obscureMaster = !_obscureMaster,
                                ),
                              ),
                            ),
                            if (_master.text.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              StrengthMeter(strength: strength),
                            ],
                            const SizedBox(height: 14),
                            CustomTextField(
                              controller: _masterConfirm,
                              label: 'Confirm master password',
                              prefixIcon: Icons.key_rounded,
                              obscureText: _obscureMaster,
                              textInputAction: TextInputAction.done,
                              validator: Validators.matches(
                                () => _master.text,
                                'The master passwords do not match',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.warning.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppTheme.warning,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Nobody can recover your master password - not '
                                'even us. If you forget it, your saved '
                                'credentials cannot be decrypted.',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _understood,
                        activeColor: AppTheme.gold,
                        checkColor: AppTheme.background,
                        onChanged: (v) =>
                            setState(() => _understood = v ?? false),
                        title: const Text(
                          'I understand and have saved it somewhere safe',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Create vault',
                        icon: Icons.lock_rounded,
                        isLoading: _loading,
                        onPressed: _register,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionLabel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.gold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
