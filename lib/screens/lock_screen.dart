import 'package:cred_vault/core/password/password_strength.dart';
import 'package:cred_vault/core/validators.dart';
import 'package:cred_vault/providers/auth_provider.dart';
import 'package:cred_vault/providers/vault_provider.dart';
import 'package:cred_vault/theme/app_theme.dart';
import 'package:cred_vault/screens/splash_screen.dart';
import 'package:cred_vault/widgets/app_logo.dart';
import 'package:cred_vault/widgets/custom_button.dart';
import 'package:cred_vault/widgets/custom_text_field.dart';
import 'package:cred_vault/widgets/glass_container.dart';
import 'package:cred_vault/widgets/snackbar_helper.dart';
import 'package:cred_vault/widgets/strength_meter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Asks for the master password to unlock the vault.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_loading) return;
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your master password');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await context.read<VaultProvider>().unlock(_password.text);
      if (!ok && mounted) {
        setState(() {
          _error = 'Incorrect master password';
          _password.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't unlock. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgot() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _EraseVaultDialog(),
    );
    if (confirmed != true || !mounted) return;
    SnackBarHelper.showInfo(
      context,
      'Vault erased. Create a new master password.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = context.select<VaultProvider, String?>((v) => v.profile?.name);
    final first = (name ?? '').trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: AppLogo(size: 104, glow: AppTheme.gold),
                    ),
                    const SizedBox(height: 22),
                    const Center(child: BrandName(size: 30)),
                    const SizedBox(height: 10),
                    Text(
                      first.isEmpty
                          ? 'Your vault is locked'
                          : 'Welcome back, $first',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Enter your master password to unlock',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 28),
                    GlassContainer(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          CustomTextField(
                            controller: _password,
                            label: 'Master password',
                            prefixIcon: Icons.key_rounded,
                            obscureText: _obscure,
                            autofocus: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _unlock(),
                            onChanged: (_) {
                              if (_error != null) setState(() => _error = null);
                            },
                            suffixIcon: IconButton(
                              tooltip: _obscure
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: AppTheme.danger,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: AppTheme.danger,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 18),
                          CustomButton(
                            text: 'Unlock',
                            icon: Icons.lock_open_rounded,
                            isLoading: _loading,
                            onPressed: _unlock,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => context.read<AuthProvider>().signOut(),
                          child: const Text('Sign out'),
                        ),
                        TextButton(
                          onPressed: _loading ? null : _forgot,
                          child: const Text('Forgot master password?'),
                        ),
                      ],
                    ),
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

/// Erasing the vault is the only way out of a forgotten master password.
class _EraseVaultDialog extends StatefulWidget {
  const _EraseVaultDialog();

  @override
  State<_EraseVaultDialog> createState() => _EraseVaultDialogState();
}

class _EraseVaultDialogState extends State<_EraseVaultDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _erase() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final vault = context.read<VaultProvider>();
    final navigator = Navigator.of(context);
    try {
      await auth.reauthenticate(_password.text);
      await vault.eraseVault();
      navigator.pop(true);
    } on AuthFailure catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = "Couldn't erase the vault. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
          SizedBox(width: 10),
          Expanded(child: Text('Forgot your master password?')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your credentials are encrypted with your master password, so '
            'nobody can recover them without it. You can erase the vault and '
            'start again with a new master password, but everything saved in '
            'it will be permanently deleted.',
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _password,
            label: 'Account password (to confirm)',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: AppTheme.danger, fontSize: 13),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: _busy ? null : _erase,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Erase vault'),
        ),
      ],
    );
  }
}

/// For signed-in accounts that have no vault yet (e.g. created by an older
/// version): choose a master password.
class SetupVaultScreen extends StatefulWidget {
  const SetupVaultScreen({super.key});

  @override
  State<SetupVaultScreen> createState() => _SetupVaultScreenState();
}

class _SetupVaultScreenState extends State<SetupVaultScreen> {
  final _formKey = GlobalKey<FormState>();
  final _master = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _understood = false;
  bool _loading = false;

  @override
  void dispose() {
    _master.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_loading || !(_formKey.currentState?.validate() ?? false)) return;
    if (!_understood) {
      SnackBarHelper.showError(
        context,
        'Please confirm that you understand the master password cannot be recovered.',
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<VaultProvider>().createVault(_master.text);
    } catch (_) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          "Couldn't create the vault. Please try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrengthEstimator.evaluate(_master.text);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: AppLogo(size: 92, glow: AppTheme.gold),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Set up your vault',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'CredVault now encrypts everything with a master '
                        'password only you know. Credentials you saved before '
                        'are encrypted automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      GlassContainer(
                        child: Column(
                          children: [
                            CustomTextField(
                              controller: _master,
                              label: 'Master password',
                              prefixIcon: Icons.key_rounded,
                              obscureText: _obscure,
                              onChanged: (_) => setState(() {}),
                              validator: Validators.masterPassword,
                              suffixIcon: IconButton(
                                tooltip: _obscure
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            if (_master.text.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              StrengthMeter(strength: strength),
                            ],
                            const SizedBox(height: 14),
                            CustomTextField(
                              controller: _confirm,
                              label: 'Confirm master password',
                              prefixIcon: Icons.key_rounded,
                              obscureText: _obscure,
                              validator: Validators.matches(
                                () => _master.text,
                                'The master passwords do not match',
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
                          'I understand it cannot be recovered if I forget it',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomButton(
                        text: 'Create vault',
                        icon: Icons.lock_rounded,
                        isLoading: _loading,
                        onPressed: _create,
                      ),
                      TextButton(
                        onPressed: () => context.read<AuthProvider>().signOut(),
                        child: const Text('Sign out'),
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
