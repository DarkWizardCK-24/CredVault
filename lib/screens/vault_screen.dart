import 'package:cred_vault/core/security_report.dart';
import 'package:cred_vault/models/credential_category.dart';
import 'package:cred_vault/models/credential_model.dart';
import 'package:cred_vault/providers/credential_provider.dart';
import 'package:cred_vault/providers/vault_provider.dart';
import 'package:cred_vault/screens/add_credential_screen.dart';
import 'package:cred_vault/screens/credential_detail_screen.dart';
import 'package:cred_vault/services/clipboard_service.dart';
import 'package:cred_vault/theme/app_theme.dart';
import 'package:cred_vault/utils/breakpoints.dart';
import 'package:cred_vault/widgets/credential_card.dart';
import 'package:cred_vault/widgets/custom_button.dart';
import 'package:cred_vault/widgets/snackbar_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The vault tab: search, filter and browse saved logins.
class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  void _open(BuildContext context, Credential c) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CredentialDetailScreen(credentialId: c.id),
      ),
    );
  }

  Future<void> _copyPassword(BuildContext context, Credential c) async {
    await context.read<ClipboardService>().copy(c.password);
    if (context.mounted) {
      SnackBarHelper.showSuccess(
        context,
        'Password for ${c.displayName} copied',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final view = context.watch<CredentialProvider>();
    final report = vault.report;
    final visible = view.apply(vault.items);
    final counts = CredentialProvider.countByCategory(vault.items);

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Breakpoints.isWide(context) ? 1100 : 640,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your vault',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _Subtitle(
                            total: vault.items.length,
                            attention: report.issueCount,
                            loaded: vault.itemsLoaded,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<CredentialSort>(
                      tooltip: 'Sort',
                      icon: const Icon(Icons.sort_rounded),
                      color: AppTheme.surfaceHigh,
                      initialValue: view.sort,
                      onSelected: view.setSort,
                      itemBuilder: (_) => [
                        for (final s in CredentialSort.values)
                          PopupMenuItem(
                            value: s,
                            child: Text(
                              s.label,
                              style: TextStyle(
                                color: s == view.sort
                                    ? AppTheme.gold
                                    : AppTheme.textPrimary,
                                fontWeight: s == view.sort
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      tooltip: 'Lock vault',
                      icon: const Icon(Icons.lock_outline_rounded),
                      onPressed: vault.lock,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: TextField(
                  onChanged: view.setQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search your vault',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: view.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => view.setQuery(''),
                          ),
                  ),
                ),
              ),
              if (vault.items.isNotEmpty)
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                    children: [
                      _FilterChip(
                        label: 'All',
                        count: vault.items.length,
                        selected: view.category == null && !view.favoritesOnly,
                        onTap: () => view.clearFilters(),
                      ),
                      if (vault.items.any((c) => c.favorite))
                        _FilterChip(
                          label: 'Favorites',
                          icon: Icons.star_rounded,
                          color: AppTheme.gold,
                          count: vault.items.where((c) => c.favorite).length,
                          selected: view.favoritesOnly,
                          onTap: () =>
                              view.setFavoritesOnly(!view.favoritesOnly),
                        ),
                      for (final cat in CredentialCategory.values)
                        if ((counts[cat] ?? 0) > 0)
                          _FilterChip(
                            label: cat.label,
                            icon: cat.icon,
                            color: cat.color,
                            count: counts[cat]!,
                            selected: view.category == cat,
                            onTap: () => view.setCategory(
                              view.category == cat ? null : cat,
                            ),
                          ),
                    ],
                  ),
                ),
              if (vault.undecryptableCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _Notice(
                    '${vault.undecryptableCount} saved '
                    '${vault.undecryptableCount == 1 ? 'item' : 'items'} '
                    "couldn't be decrypted and are hidden.",
                  ),
                ),
              Expanded(child: _content(context, vault, view, visible, report)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    VaultProvider vault,
    CredentialProvider view,
    List<Credential> visible,
    SecurityReport report,
  ) {
    if (!vault.itemsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vault.items.isEmpty) {
      return _EmptyState(
        icon: Icons.shield_outlined,
        title: 'Your vault is empty',
        message:
            'Add your first login. Everything is encrypted on this '
            'device before it is saved.',
        actionLabel: 'Add a credential',
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AddCredentialScreen()),
        ),
      );
    }

    if (visible.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nothing found',
        message: 'No logins match your search or filter.',
        actionLabel: 'Clear filters',
        onAction: view.clearFilters,
      );
    }

    Widget card(Credential c) => CredentialCard(
      credential: c,
      issues: report.issuesFor(c),
      onTap: () => _open(context, c),
      onCopyPassword: () => _copyPassword(context, c),
      onToggleFavorite: () => vault.toggleFavorite(c),
    );

    // Wide screens: a grid of cards. Phones keep the single-column list.
    if (Breakpoints.isWide(context)) {
      return LayoutBuilder(
        builder: (context, box) {
          final columns = box.maxWidth >= 1000 ? 3 : 2;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 112,
            ),
            itemCount: visible.length,
            itemBuilder: (context, i) => card(visible[i]),
          );
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => card(visible[i]),
    );
  }
}

class _Subtitle extends StatelessWidget {
  final int total;
  final int attention;
  final bool loaded;

  const _Subtitle({
    required this.total,
    required this.attention,
    required this.loaded,
  });

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Text(
        'Decrypting...',
        style: TextStyle(color: AppTheme.textSecondary),
      );
    }
    final text = total == 0
        ? 'Nothing saved yet'
        : '$total ${total == 1 ? 'login' : 'logins'}';
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        if (total > 0) ...[
          const Text('  ·  ', style: TextStyle(color: AppTheme.textMuted)),
          Icon(
            attention == 0
                ? Icons.verified_rounded
                : Icons.error_outline_rounded,
            size: 15,
            color: attention == 0 ? AppTheme.success : AppTheme.warning,
          ),
          const SizedBox(width: 4),
          Text(
            attention == 0 ? 'All healthy' : '$attention need attention',
            style: TextStyle(
              color: attention == 0 ? AppTheme.success : AppTheme.warning,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color = AppTheme.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label, $count',
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: selected
                  ? AppTheme.gold
                  : AppTheme.surfaceHigh.withValues(alpha: 0.7),
              border: Border.all(
                color: selected ? AppTheme.gold : AppTheme.border,
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? AppTheme.background : color,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppTheme.background
                        : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: selected
                        ? AppTheme.background.withValues(alpha: 0.7)
                        : AppTheme.textMuted,
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

class _Notice extends StatelessWidget {
  final String text;

  const _Notice(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.gold.withValues(alpha: 0.10),
                border: Border.all(
                  color: AppTheme.gold.withValues(alpha: 0.25),
                ),
              ),
              child: Icon(icon, size: 44, color: AppTheme.gold),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 240,
              child: CustomButton(text: actionLabel, onPressed: onAction),
            ),
          ],
        ),
      ),
    );
  }
}
