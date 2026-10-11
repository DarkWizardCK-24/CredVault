import 'package:cred_vault/core/password/password_generator.dart';
import 'package:cred_vault/screens/add_credential_screen.dart';
import 'package:cred_vault/screens/generator_screen.dart';
import 'package:cred_vault/screens/profile_screen.dart';
import 'package:cred_vault/screens/security_screen.dart';
import 'package:cred_vault/screens/vault_screen.dart';
import 'package:cred_vault/theme/app_theme.dart';
import 'package:cred_vault/utils/breakpoints.dart';
import 'package:cred_vault/widgets/glass_container.dart';
import 'package:flutter/material.dart';

/// The unlocked app: four tabs (Vault, Generator, Security, Profile).
class HomeScreen extends StatefulWidget {
  /// The tab to start on (used by tests and screenshots).
  final int initialTab;

  /// Injectable for tests (a seeded generator gives repeatable output).
  final PasswordGenerator? generator;

  const HomeScreen({super.key, this.initialTab = 0, this.generator});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _index = widget.initialTab;

  late final List<Widget> _tabs = [
    const VaultScreen(),
    GeneratorScreen(generator: widget.generator),
    const SecurityScreen(),
    const ProfileScreen(),
  ];

  void _addLogin() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const AddCredentialScreen()),
  );

  static const _items = [
    (Icons.shield_outlined, Icons.shield_rounded, 'Vault'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'Generator'),
    (
      Icons.health_and_safety_outlined,
      Icons.health_and_safety_rounded,
      'Security',
    ),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  /// Desktop / wide web: a side rail instead of the phone's bottom bar.
  Widget _wideLayout() {
    return Scaffold(
      body: AppBackground(
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.background.withValues(alpha: 0.96),
                border: const Border(right: BorderSide(color: AppTheme.border)),
              ),
              child: SafeArea(
                child: NavigationRail(
                  backgroundColor: Colors.transparent,
                  extended: MediaQuery.sizeOf(context).width >= 1100,
                  minExtendedWidth: 200,
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: FloatingActionButton.extended(
                      onPressed: _addLogin,
                      backgroundColor: AppTheme.gold,
                      foregroundColor: AppTheme.background,
                      elevation: 0,
                      highlightElevation: 0,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text(
                        'Add login',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  destinations: [
                    for (final (icon, selected, label) in _items)
                      NavigationRailDestination(
                        icon: Icon(icon),
                        selectedIcon: Icon(selected),
                        label: Text(label),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(child: IndexedStack(index: _index, children: _tabs)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.isWide(context)) return _wideLayout();
    return Scaffold(
      extendBody: true,
      body: AppBackground(
        // Only the visible tab is kept alive in the tree's state; each tab
        // keeps its own scroll position through its own ListView.
        child: IndexedStack(index: _index, children: _tabs),
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: _addLogin,
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.background,
              elevation: 0,
              highlightElevation: 0,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add login',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.background.withValues(alpha: 0.96),
          border: const Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.shield_outlined),
                selectedIcon: Icon(Icons.shield_rounded),
                label: 'Vault',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome_rounded),
                label: 'Generator',
              ),
              NavigationDestination(
                icon: Icon(Icons.health_and_safety_outlined),
                selectedIcon: Icon(Icons.health_and_safety_rounded),
                label: 'Security',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
