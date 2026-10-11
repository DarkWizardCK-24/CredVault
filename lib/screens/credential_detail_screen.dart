import 'dart:async';

import 'package:cred_vault/core/password/password_strength.dart';
import 'package:cred_vault/core/security_report.dart';
import 'package:cred_vault/models/credential_model.dart';
import 'package:cred_vault/providers/vault_provider.dart';
import 'package:cred_vault/screens/add_credential_screen.dart';
import 'package:cred_vault/services/clipboard_service.dart';
import 'package:cred_vault/theme/app_theme.dart';
import 'package:cred_vault/utils/open_url.dart';
import 'package:cred_vault/widgets/custom_button.dart';
import 'package:cred_vault/widgets/glass_container.dart';
import 'package:cred_vault/widgets/platform_data.dart';
import 'package:cred_vault/widgets/snackbar_helper.dart';
import 'package:cred_vault/widgets/strength_meter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Everything about one credential, with copy / reveal / open / edit / delete.
class CredentialDetailScreen extends StatefulWidget {
  final String credentialId;

  const CredentialDetailScreen({super.key, required this.credentialId});

  @override
  State<CredentialDetailScreen> createState() => _CredentialDetailScreenState();
}

class _CredentialDetailScreenState extends State<CredentialDetailScreen> {
  static const Duration _revealFor = Duration(seconds: 20);

  bool _revealed = false;
  Timer? _hideTimer;

  // null = not checked yet
  bool _checking = false;
  int? _breachCount;
  bool _breachFailed = false;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _toggleReveal() {
    _hideTimer?.cancel();
    setState(() => _revealed = !_revealed);
    // Don't leave a password on screen forever.
    if (_revealed) {
      _hideTimer = Timer(_revealFor, () {
        if (mounted) setState(() => _revealed = false);
      });
    }
  }

  Future<void> _copy(String text, String label, {bool secret = false}) async {
    await context.read<ClipboardService>().copy(text, secret: secret);
    if (mounted) SnackBarHelper.showSuccess(context, '$label copied');
  }

  Future<void> _checkBreach(Credential c) async {
    setState(() {
      _checking = true;
      _breachFailed = false;
    });
    final count = await context.read<VaultProvider>().checkPassword(c.password);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _breachCount = count;
      _breachFailed = count == null;
    });
  }

  Future<void> _open(String url) async {
    if (!await openUrl(url) && mounted) {
      SnackBarHelper.showError(context, "Couldn't open that address.");
    }
  }

  Future<void> _delete(Credential c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${c.displayName}?'),
        content: const Text('This login will be removed from your vault.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final vault = context.read<VaultProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await vault.delete(c);
      navigator.pop();
      SnackBarHelper.showSuccessOn(
        messenger,
        '${c.displayName} deleted',
        actionLabel: 'UNDO',
        onAction: () => vault.restore(c),
      );
    } catch (_) {
      if (mounted) SnackBarHelper.showError(context, "Couldn't delete it.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final c = vault.items.where((x) => x.id == widget.credentialId).firstOrNull;

    if (c == null) {
      // Deleted (or the vault was locked): nothing left to show.
      return Scaffold(
        appBar: AppBar(),
        body: const AppBackground(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final strength = PasswordStrengthEstimator.evaluate(c.password);
    final issues = vault.report.issuesFor(c);
    final dateFormat = DateFormat('d MMM yyyy');
    final passwordAge = vault.now.difference(c.passwordChangedAt).inDays;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: c.favorite ? 'Remove from favorites' : 'Add to favorites',
            icon: Icon(
              c.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: c.favorite ? AppTheme.gold : AppTheme.textSecondary,
            ),
            onPressed: () => vault.toggleFavorite(c),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AddCredentialScreen(credential: c),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          PlatformAvatar(platform: c.platform, size: 68),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.displayName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      c.category.icon,
                                      size: 16,
                                      color: c.category.color,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      c.category.label,
                                      style: TextStyle(
                                        color: c.category.color,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (issues.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _IssueBanner(issues: issues),
                      ],
                      const SizedBox(height: 20),
                      GlassContainer(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Username',
                              value: c.username,
                              actions: [
                                _IconAction(
                                  icon: Icons.copy_rounded,
                                  tooltip: 'Copy username',
                                  onTap: () => _copy(c.username, 'Username'),
                                ),
                              ],
                            ),
                            const Divider(height: 28),
                            _FieldRow(
                              icon: Icons.lock_outline_rounded,
                              label: 'Password',
                              value: _revealed
                                  ? c.password
                                  : '•' * c.password.length.clamp(8, 18),
                              mono: true,
                              actions: [
                                _IconAction(
                                  icon: _revealed
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  tooltip: _revealed
                                      ? 'Hide password'
                                      : 'Show password',
                                  onTap: _toggleReveal,
                                ),
                                _IconAction(
                                  icon: Icons.copy_rounded,
                                  tooltip: 'Copy password',
                                  onTap: () => _copy(
                                    c.password,
                                    'Password',
                                    secret: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            StrengthMeter(strength: strength),
                            if (c.url.trim().isNotEmpty) ...[
                              const Divider(height: 28),
                              _FieldRow(
                                icon: Icons.link_rounded,
                                label: 'Website',
                                value: c.url,
                                actions: [
                                  _IconAction(
                                    icon: Icons.open_in_new_rounded,
                                    tooltip: 'Open website',
                                    onTap: () => _open(c.url),
                                  ),
                                  _IconAction(
                                    icon: Icons.copy_rounded,
                                    tooltip: 'Copy website',
                                    onTap: () => _copy(c.url, 'Website'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (vault.canCheckBreaches) ...[
                        const SizedBox(height: 14),
                        _BreachCard(
                          checking: _checking,
                          count: _breachCount,
                          failed: _breachFailed,
                          onCheck: () => _checkBreach(c),
                        ),
                      ],
                      if (c.notes.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        GlassContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.notes_rounded,
                                    size: 18,
                                    color: AppTheme.textSecondary,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Notes',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                c.notes,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      GlassContainer(
                        child: Column(
                          children: [
                            _MetaRow('Added', dateFormat.format(c.createdAt)),
                            const SizedBox(height: 10),
                            _MetaRow(
                              'Last edited',
                              dateFormat.format(c.updatedAt),
                            ),
                            const SizedBox(height: 10),
                            _MetaRow(
                              'Password changed',
                              passwordAge <= 0
                                  ? 'Today'
                                  : '${dateFormat.format(c.passwordChangedAt)}  ·  $passwordAge days ago',
                              warn: passwordAge >= SecurityReport.oldAfterDays,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      CustomButton(
                        text: 'Delete',
                        icon: Icons.delete_outline_rounded,
                        kind: ButtonStyleKind.danger,
                        onPressed: () => _delete(c),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;
  final List<Widget> actions;

  const _FieldRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.actions,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: mono ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: mono ? 15 : 15.5,
                  fontWeight: FontWeight.w500,
                  fontFamily: mono ? AppTheme.monoFamily : AppTheme.fontFamily,
                  letterSpacing: mono ? 0.4 : 0,
                ),
              ),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(icon, size: 21),
    color: AppTheme.gold,
    visualDensity: VisualDensity.compact,
  );
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final bool warn;

  const _MetaRow(this.label, this.value, {this.warn = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: warn ? AppTheme.warning : AppTheme.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _IssueBanner extends StatelessWidget {
  final List<IssueKind> issues;

  const _IssueBanner({required this.issues});

  @override
  Widget build(BuildContext context) {
    final severe = issues.any((i) => i != IssueKind.old);
    final color = severe ? AppTheme.danger : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${issues.map((i) => i.label).join(' · ')}. '
              'Consider changing this password.',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreachCard extends StatelessWidget {
  final bool checking;
  final int? count;
  final bool failed;
  final VoidCallback onCheck;

  const _BreachCard({
    required this.checking,
    required this.count,
    required this.failed,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    final String title;
    final String text;
    final Color color;
    final IconData icon;

    if (failed) {
      title = "Couldn't check";
      text = 'Check your connection and try again.';
      color = AppTheme.warning;
      icon = Icons.cloud_off_rounded;
    } else if (count == null) {
      title = 'Breach check';
      text =
          'See if this password appeared in a known data breach. Only a '
          'fragment of its hash is sent, never the password.';
      color = AppTheme.textSecondary;
      icon = Icons.travel_explore_rounded;
    } else if (count == 0) {
      title = 'Not found in known breaches';
      text = 'Good news - this password was not seen in any breach we checked.';
      color = AppTheme.success;
      icon = Icons.verified_user_rounded;
    } else {
      title = 'Found in $count breaches';
      text =
          'Attackers already know this password. Change it everywhere you use it.';
      color = AppTheme.danger;
      icon = Icons.gpp_bad_rounded;
    }

    return GlassContainer(
      borderColor: count == null && !failed
          ? null
          : color.withValues(alpha: 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: count == null && !failed
                        ? AppTheme.textPrimary
                        : color,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    onPressed: checking ? null : onCheck,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            count == null && !failed
                                ? 'Check now'
                                : 'Check again',
                          ),
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
