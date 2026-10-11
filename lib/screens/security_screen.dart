import 'package:cred_vault/core/security_report.dart';
import 'package:cred_vault/models/credential_model.dart';
import 'package:cred_vault/providers/vault_provider.dart';
import 'package:cred_vault/screens/credential_detail_screen.dart';
import 'package:cred_vault/theme/app_theme.dart';
import 'package:cred_vault/widgets/credential_card.dart';
import 'package:cred_vault/widgets/custom_button.dart';
import 'package:cred_vault/widgets/glass_container.dart';
import 'package:cred_vault/widgets/strength_meter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// The security tab: a health score for the whole vault and what to fix.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  IssueKind? _selected;

  static Color _colorOf(IssueKind k) => switch (k) {
    IssueKind.breached => AppTheme.danger,
    IssueKind.weak => AppTheme.danger,
    IssueKind.reused => AppTheme.warning,
    IssueKind.old => AppTheme.gold,
  };

  static IconData _iconOf(IssueKind k) => switch (k) {
    IssueKind.breached => Icons.gpp_bad_rounded,
    IssueKind.weak => Icons.warning_amber_rounded,
    IssueKind.reused => Icons.content_copy_rounded,
    IssueKind.old => Icons.history_rounded,
  };

  static String _titleOf(IssueKind k) => switch (k) {
    IssueKind.breached => 'Breached',
    IssueKind.weak => 'Weak',
    IssueKind.reused => 'Reused',
    IssueKind.old => 'Old',
  };

  List<Credential> _listFor(SecurityReport r, IssueKind k) => switch (k) {
    IssueKind.breached => r.breached,
    IssueKind.weak => r.weak,
    IssueKind.reused => r.reused,
    IssueKind.old => r.old,
  };

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final report = vault.report;

    // Default to the first category that actually has something in it.
    final selected =
        _selected ??
        IssueKind.values.firstWhere(
          (k) => _listFor(report, k).isNotEmpty,
          orElse: () => IssueKind.weak,
        );
    final selectedItems = _listFor(report, selected);

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              const Text(
                'Security',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'How healthy are your passwords?',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              GlassContainer(
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: [
                    SecurityRing(score: report.score, size: 118),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Security score',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            report.verdict,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            report.total == 0
                                ? 'Nothing to check yet'
                                : '${report.total} '
                                      '${report.total == 1 ? 'login' : 'logins'} checked',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (var row = 0; row < 2; row++) ...[
                if (row > 0) const SizedBox(height: 12),
                Row(
                  children: [
                    for (var col = 0; col < 2; col++) ...[
                      if (col > 0) const SizedBox(width: 12),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final kind = IssueKind.values[row * 2 + col];
                            return _StatTile(
                              title: _titleOf(kind),
                              count: _listFor(report, kind).length,
                              icon: _iconOf(kind),
                              color: _colorOf(kind),
                              selected: selected == kind,
                              onTap: () => setState(() => _selected = kind),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _BreachScanCard(vault: vault),
              const SizedBox(height: 24),
              if (report.total > 0) ...[
                Row(
                  children: [
                    Icon(
                      _iconOf(selected),
                      color: _colorOf(selected),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_titleOf(selected)} passwords',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (selectedItems.isEmpty)
                  GlassContainer(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: AppTheme.success,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selected == IssueKind.breached &&
                                    vault.breachCheckedAt == null
                                ? 'Run the breach check above to find out.'
                                : 'Nothing to fix here. Nice!',
                            style: const TextStyle(color: AppTheme.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final c in selectedItems) ...[
                    CredentialCard(
                      credential: c,
                      issues: report.issuesFor(c),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CredentialDetailScreen(credentialId: c.id),
                        ),
                      ),
                      onCopyPassword: () {},
                      onToggleFavorite: () => vault.toggleFavorite(c),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatTile({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    final tint = active ? color : AppTheme.success;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title: $count',
      excludeSemantics: true,
      child: GlassContainer(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        radius: 20,
        borderColor: selected ? tint.withValues(alpha: 0.8) : null,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: tint, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreachScanCard extends StatelessWidget {
  final VaultProvider vault;

  const _BreachScanCard({required this.vault});

  @override
  Widget build(BuildContext context) {
    final checkedAt = vault.breachCheckedAt;
    final canRun = vault.canCheckBreaches && vault.items.isNotEmpty;

    final String subtitle;
    if (vault.checkingBreaches) {
      subtitle = 'Checking your passwords...';
    } else if (checkedAt == null) {
      subtitle =
          'See if any of your passwords appeared in a data breach. '
          'Only a fragment of each hash is sent, never a password.';
    } else {
      subtitle =
          'Last checked ${DateFormat('d MMM, h:mm a').format(checkedAt)}'
          '${vault.breachCheckIncomplete ? ' - some could not be checked' : ''}.';
    }

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.travel_explore_rounded, color: AppTheme.gold),
              SizedBox(width: 10),
              Text(
                'Breach scan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          CustomButton(
            text: checkedAt == null ? 'Check my passwords' : 'Scan again',
            icon: Icons.radar_rounded,
            kind: ButtonStyleKind.secondary,
            isLoading: vault.checkingBreaches,
            onPressed: canRun ? vault.checkAllBreaches : null,
          ),
        ],
      ),
    );
  }
}
