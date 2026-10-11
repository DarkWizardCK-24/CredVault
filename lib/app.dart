import 'package:cred_vault/providers/auth_provider.dart';
import 'package:cred_vault/providers/credential_provider.dart';
import 'package:cred_vault/providers/vault_provider.dart';
import 'package:cred_vault/screens/home_screen.dart';
import 'package:cred_vault/screens/lock_screen.dart';
import 'package:cred_vault/screens/login_screen.dart';
import 'package:cred_vault/screens/splash_screen.dart';
import 'package:cred_vault/services/clipboard_service.dart';
import 'package:cred_vault/services/settings_service.dart';
import 'package:cred_vault/theme/app_theme.dart';
import 'package:cred_vault/widgets/custom_button.dart';
import 'package:cred_vault/widgets/glass_container.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The whole app: providers, theme and the gate that decides which screen to
/// show. The services are passed in so tests can supply fakes.
class CredVaultApp extends StatefulWidget {
  final AuthProvider auth;
  final VaultProvider vault;
  final SettingsService settings;

  /// Starting page override for tests / screenshots (skips the gate).
  final Widget? home;

  const CredVaultApp({
    super.key,
    required this.auth,
    required this.vault,
    required this.settings,
    this.home,
  });

  @override
  State<CredVaultApp> createState() => _CredVaultAppState();
}

class _CredVaultAppState extends State<CredVaultApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final ClipboardService _clipboard = ClipboardService(widget.settings);
  final CredentialProvider _view = CredentialProvider();

  @override
  void dispose() {
    _clipboard.dispose();
    _view.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: widget.auth),
        ChangeNotifierProvider<VaultProvider>.value(value: widget.vault),
        ChangeNotifierProvider<SettingsService>.value(value: widget.settings),
        ChangeNotifierProvider<CredentialProvider>.value(value: _view),
        Provider<ClipboardService>.value(value: _clipboard),
      ],
      child: MaterialApp(
        title: 'CredVault',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        navigatorKey: _navigatorKey,
        home: widget.home ?? AppRoot(navigatorKey: _navigatorKey),
      ),
    );
  }
}

/// Decides what to show from the sign-in and vault state, and keeps the vault
/// safe: it locks when the app has been in the background for too long.
class AppRoot extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const AppRoot({super.key, required this.navigatorKey});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  late final AuthProvider _auth = context.read<AuthProvider>();
  late final VaultProvider _vault = context.read<VaultProvider>();
  VaultStatus _lastStatus = VaultStatus.signedOut;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth.addListener(_syncVault);
    _vault.addListener(_onVaultChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncVault());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth.removeListener(_syncVault);
    _vault.removeListener(_onVaultChanged);
    super.dispose();
  }

  /// Keep the vault in step with who is signed in.
  void _syncVault() {
    if (!_auth.initialized) return;
    _vault.attach(_auth.isSignedIn ? _auth.userId : null);
  }

  void _onVaultChanged() {
    final status = _vault.status;
    if (status == _lastStatus) return;
    final wasUnlocked = _lastStatus == VaultStatus.unlocked;
    _lastStatus = status;
    if (wasUnlocked && status != VaultStatus.unlocked) {
      // Close any open screens (details, editors...) so the lock screen is
      // never hidden underneath something that shows secrets.
      widget.navigatorKey.currentState?.popUntil((route) => route.isFirst);
      context.read<CredentialProvider>().clearFilters();
      context.read<ClipboardService>().clearNow();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final delay = context.read<SettingsService>().autoLock.delay;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
      if (delay == Duration.zero) _vault.lock();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since != null && DateTime.now().difference(since) >= delay) {
        _vault.lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final status = context.watch<VaultProvider>().status;

    final Widget page;
    if (!auth.initialized) {
      page = const SplashScreen();
    } else if (!auth.isSignedIn) {
      page = const LoginScreen();
    } else {
      page = switch (status) {
        VaultStatus.signedOut || VaultStatus.loading => const SplashScreen(
          message: 'Opening your vault...',
        ),
        VaultStatus.needsSetup => const SetupVaultScreen(),
        VaultStatus.locked => const LockScreen(),
        VaultStatus.unlocked => const HomeScreen(),
        VaultStatus.error => const _LoadErrorScreen(),
      };
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(key: ValueKey(page.runtimeType), child: page),
    );
  }
}

class _LoadErrorScreen extends StatelessWidget {
  const _LoadErrorScreen();

  @override
  Widget build(BuildContext context) {
    final vault = context.read<VaultProvider>();
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 56,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  vault.loadError ?? 'Something went wrong.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 220,
                  child: CustomButton(
                    text: 'Try again',
                    onPressed: vault.reload,
                  ),
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
    );
  }
}
