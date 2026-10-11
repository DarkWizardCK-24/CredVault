import 'package:cred_vault/core/password/password_strength.dart';
import 'package:cred_vault/core/validators.dart';
import 'package:cred_vault/providers/auth_provider.dart';
import 'package:cred_vault/providers/vault_provider.dart';
import 'package:cred_vault/screens/edit_profile_screen.dart';
import 'package:cred_vault/services/clipboard_service.dart';
import 'package:cred_vault/services/settings_service.dart';
import 'package:cred_vault/theme/app_theme.dart';
import 'package:cred_vault/widgets/custom_text_field.dart';
import 'package:cred_vault/widgets/glass_container.dart';
import 'package:cred_vault/widgets/snackbar_helper.dart';
import 'package:cred_vault/widgets/strength_meter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// The profile tab: account, security settings and about.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _pickAutoLock(BuildContext context) async {
    final settings = context.read<SettingsService>();
    final picked = await _chooseOne<AutoLockDelay>(
      context,
      title: 'Auto-lock',
      subtitle: 'Lock the vault after the app has been in the background',
      values: AutoLockDelay.values,
      selected: settings.autoLock,
      label: (v) => v.label,
    );
    if (picked != null) await settings.setAutoLock(picked);
  }

  Future<void> _pickClipboard(BuildContext context) async {
    final settings = context.read<SettingsService>();
    final picked = await _chooseOne<ClipboardClear>(
      context,
      title: 'Clear copied passwords',
      subtitle: 'Wipe the clipboard after copying a password',
      values: ClipboardClear.values,
      selected: settings.clipboardClear,
      label: (v) => v.label,
    );
    if (picked != null) await settings.setClipboardClear(picked);
  }

  Future<void> _resetPassword(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final email = auth.email;
    if (email == null) return;
    try {
      await auth.sendPasswordReset(email);
      if (context.mounted) {
        SnackBarHelper.showSuccess(context, 'Reset link sent to $email');
      }
    } on AuthFailure catch (e) {
      if (context.mounted) SnackBarHelper.showError(context, e.message);
    }
  }

  void _showHowItWorks(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_moon_outlined, color: AppTheme.gold),
            SizedBox(width: 10),
            Expanded(child: Text('How your data is protected')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Zero-knowledge: everything you save is encrypted on this '
                'device before it is sent anywhere. Our servers only ever hold '
                'scrambled data.',
              ),
              SizedBox(height: 12),
              Text(
                'Your master password is turned into a key with PBKDF2 '
                '(200,000 rounds of HMAC-SHA-256) and a random salt. Each '
                'login is then encrypted with AES-256-GCM, which also detects '
                'tampering.',
              ),
              SizedBox(height: 12),
              Text(
                'The master password is never stored or sent. That also means '
                'it cannot be recovered. The vault locks itself when you leave '
                'the app, and copied passwords are cleared from the clipboard.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (password == null || !context.mounted) return;

    final auth = context.read<AuthProvider>();
    final vault = context.read<VaultProvider>();
    try {
      // Order matters: data can only be removed while still signed in.
      await auth.reauthenticate(password);
      await vault.deleteEverything();
      await auth.deleteAccount();
    } on AuthFailure catch (e) {
      if (context.mounted) SnackBarHelper.showError(context, e.message);
    } catch (_) {
      if (context.mounted) {
        SnackBarHelper.showError(
          context,
          "Couldn't delete your account. Please try again.",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final settings = context.watch<SettingsService>();
    final profile = vault.profile;
    final report = vault.report;
    final name = profile?.name ?? '';
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 20),
              GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.goldGradient,
                      ),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.background,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Your profile' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile?.email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13.5,
                            ),
                          ),
                          if (profile != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Member since ${DateFormat('MMM yyyy').format(profile.createdAt)}',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit name',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ProfileEditScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.key_rounded,
                      label: 'Logins',
                      value: '${vault.items.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.shield_outlined,
                      label: 'Security score',
                      value: vault.items.isEmpty ? '-' : '${report.score}',
                      color: AppTheme.forScore(report.score / 100),
                    ),
                  ),
                ],
              ),
              const _Heading('Security'),
              GlassContainer(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    _Tile(
                      icon: Icons.timer_outlined,
                      title: 'Auto-lock',
                      value: settings.autoLock.label,
                      onTap: () => _pickAutoLock(context),
                    ),
                    const Divider(indent: 60),
                    _Tile(
                      icon: Icons.content_paste_off_rounded,
                      title: 'Clear clipboard',
                      value: settings.clipboardClear.label,
                      onTap: () => _pickClipboard(context),
                    ),
                    const Divider(indent: 60),
                    _Tile(
                      icon: Icons.key_rounded,
                      title: 'Change master password',
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => const _ChangeMasterDialog(),
                      ),
                    ),
                    const Divider(indent: 60),
                    _Tile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Lock vault now',
                      onTap: () {
                        context.read<ClipboardService>().clearNow();
                        vault.lock();
                      },
                    ),
                  ],
                ),
              ),
              const _Heading('Account'),
              GlassContainer(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    _Tile(
                      icon: Icons.mark_email_read_outlined,
                      title: 'Reset account password',
                      onTap: () => _resetPassword(context),
                    ),
                    const Divider(indent: 60),
                    _Tile(
                      icon: Icons.logout_rounded,
                      title: 'Sign out',
                      onTap: () => context.read<AuthProvider>().signOut(),
                    ),
                    const Divider(indent: 60),
                    _Tile(
                      icon: Icons.delete_forever_outlined,
                      title: 'Delete account',
                      color: AppTheme.danger,
                      onTap: () => _deleteAccount(context),
                    ),
                  ],
                ),
              ),
              const _Heading('About'),
              GlassContainer(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    _Tile(
                      icon: Icons.shield_moon_outlined,
                      title: 'How your data is protected',
                      onTap: () => _showHowItWorks(context),
                    ),
                    const Divider(indent: 60),
                    const _Tile(
                      icon: Icons.info_outline_rounded,
                      title: 'CredVault',
                      value: 'Version 2.0.0',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> _chooseOne<T>(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<T> values,
  required T selected,
  required String Function(T) label,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            for (final v in values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  label(v),
                  style: TextStyle(
                    color: v == selected ? AppTheme.gold : AppTheme.textPrimary,
                    fontWeight: v == selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                trailing: v == selected
                    ? const Icon(Icons.check_rounded, color: AppTheme.gold)
                    : null,
                onTap: () => Navigator.pop(context, v),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 26, 0, 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final Color? color;

  const _Tile({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppTheme.textPrimary;
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: (color ?? AppTheme.gold).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: color ?? AppTheme.gold),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: tint,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(
              value!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppTheme.gold,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Change the master password: re-encrypts the whole vault.
class _ChangeMasterDialog extends StatefulWidget {
  const _ChangeMasterDialog();

  @override
  State<_ChangeMasterDialog> createState() => _ChangeMasterDialogState();
}

class _ChangeMasterDialogState extends State<_ChangeMasterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final vault = context.read<VaultProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await vault.changeMasterPassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Master password changed')),
      );
    } on WrongMasterPassword {
      setState(() {
        _busy = false;
        _error = 'Your current master password is incorrect';
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = "Couldn't change it. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrengthEstimator.evaluate(_next.text);
    return AlertDialog(
      title: const Text('Change master password'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _current,
                label: 'Current master password',
                prefixIcon: Icons.key_rounded,
                obscureText: true,
                validator: (v) => Validators.required(
                  v,
                  'Enter your current master password',
                ),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _next,
                label: 'New master password',
                prefixIcon: Icons.key_rounded,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                validator: Validators.masterPassword,
              ),
              if (_next.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                StrengthMeter(strength: strength, showHints: false),
              ],
              const SizedBox(height: 12),
              CustomTextField(
                controller: _confirm,
                label: 'Confirm new master password',
                prefixIcon: Icons.key_rounded,
                obscureText: true,
                validator: Validators.matches(
                  () => _next.text,
                  'The passwords do not match',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
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
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _change,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Change'),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
          SizedBox(width: 10),
          Expanded(child: Text('Delete account')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently deletes your account and every login in your '
            'vault. It cannot be undone. Enter your account password to confirm.',
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _password,
            label: 'Account password',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: _password.text.isEmpty
              ? null
              : () => Navigator.pop(context, _password.text),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
