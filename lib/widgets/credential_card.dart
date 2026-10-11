import 'package:cred_vault/core/security_report.dart';
import 'package:cred_vault/models/credential_model.dart';
import 'package:cred_vault/theme/app_theme.dart';
import 'package:cred_vault/widgets/glass_container.dart';
import 'package:cred_vault/widgets/platform_data.dart';
import 'package:flutter/material.dart';

/// One credential in the vault list.
class CredentialCard extends StatelessWidget {
  final Credential credential;

  /// Problems found for this credential (weak, reused, ...).
  final List<IssueKind> issues;
  final VoidCallback onTap;
  final VoidCallback onCopyPassword;
  final VoidCallback onToggleFavorite;

  const CredentialCard({
    super.key,
    required this.credential,
    required this.onTap,
    required this.onCopyPassword,
    required this.onToggleFavorite,
    this.issues = const [],
  });

  @override
  Widget build(BuildContext context) {
    final c = credential;
    return GlassContainer(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
      radius: 22,
      child: Row(
        children: [
          PlatformAvatar(platform: c.platform),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (issues.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final issue in issues.take(2)) _IssueChip(issue),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: c.favorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: onToggleFavorite,
            icon: Icon(
              c.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: c.favorite ? AppTheme.gold : AppTheme.textMuted,
            ),
          ),
          IconButton(
            tooltip: 'Copy password',
            onPressed: onCopyPassword,
            icon: const Icon(Icons.copy_rounded, size: 20),
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _IssueChip extends StatelessWidget {
  final IssueKind issue;

  const _IssueChip(this.issue);

  @override
  Widget build(BuildContext context) {
    final color = issue == IssueKind.old ? AppTheme.warning : AppTheme.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        issue.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
