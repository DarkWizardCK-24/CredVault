import 'package:cred_vault/providers/vault_provider.dart';
import 'package:cred_vault/screens/home_screen.dart';
import 'package:cred_vault/screens/lock_screen.dart';
import 'package:cred_vault/screens/login_screen.dart';
import 'package:cred_vault/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';
import 'support/fonts.dart';
import 'support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late FakeVaultRepository repo;
  late FakeAuthProvider auth;
  late VaultProvider vault;

  setUp(() {
    repo = FakeVaultRepository();
    auth = FakeAuthProvider();
    vault = newVault(repo);
  });

  Future<void> pumpGate(
    WidgetTester tester, {
    SettingsService? settings,
  }) async {
    usePhone(tester);
    await tester.pumpWidget(
      testApp(auth: auth, vault: vault, settings: settings),
    );
    await tester.pumpAndSettle();
  }

  group('Sign in', () {
    setUp(() => auth.accounts['aarav@example.com'] = 'acct-pass');

    testWidgets('shows the sign-in screen when nobody is signed in', (
      tester,
    ) async {
      await pumpGate(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Sign in to your vault'), findsOneWidget);
    });

    testWidgets('validates before signing in', (tester) async {
      await pumpGate(tester);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('explains a wrong password', (tester) async {
      await pumpGate(tester);
      await typeInto(tester, 'Email', 'aarav@example.com');
      await typeInto(tester, 'Account password', 'wrong');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets(
      'signing in leads to the lock screen, not straight into the vault',
      (tester) async {
        await seedVault(repo, uid: 'uid-aarav@example.com', master: master);
        await pumpGate(tester);
        await typeInto(tester, 'Email', 'aarav@example.com');
        await typeInto(tester, 'Account password', 'acct-pass');
        await tester.tap(find.text('Sign in'));
        await tester.pumpAndSettle();

        expect(find.byType(LockScreen), findsOneWidget);
        expect(find.text('Welcome back, Aarav'), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
      },
    );

    testWidgets('an account without a vault is asked to create one', (
      tester,
    ) async {
      repo.profiles['uid-aarav@example.com'] = sampleProfile(
        'uid-aarav@example.com',
      );
      await pumpGate(tester);
      await typeInto(tester, 'Email', 'aarav@example.com');
      await typeInto(tester, 'Account password', 'acct-pass');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(SetupVaultScreen), findsOneWidget);
      expect(find.text('Set up your vault'), findsOneWidget);
    });

    testWidgets('forgot password sends a reset email', (tester) async {
      await pumpGate(tester);
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        'aarav@example.com',
      );
      await tester.tap(find.text('Send link'));
      await tester.pumpAndSettle();

      expect(auth.resetEmails, ['aarav@example.com']);
      expect(find.textContaining('reset link'), findsOneWidget);
    });
  });

  group('Creating an account', () {
    Future<void> openRegister(WidgetTester tester) async {
      await pumpGate(tester);
      await tester.tap(find.text('Create a vault'));
      await tester.pumpAndSettle();
    }

    Future<void> fillAll(
      WidgetTester tester, {
      String email = 'meera@example.com',
      String masterPw = master,
      String confirm = master,
    }) async {
      await typeInto(tester, 'Full name', 'Meera Iyer');
      await typeInto(tester, 'Email', email);
      await typeInto(tester, 'Account password', 'acct-pass-1');
      await typeInto(tester, 'Master password', masterPw);
      await typeInto(tester, 'Confirm master password', confirm);
      await tester.pump();
    }

    Future<void> submit(WidgetTester tester) async {
      final button = find.text('Create vault').last;
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    Future<void> acknowledge(WidgetTester tester) async {
      final box = find.byType(CheckboxListTile);
      await tester.ensureVisible(box);
      await tester.tap(box);
      await tester.pump();
    }

    testWidgets(
      'creates the account, profile and vault, then opens the vault',
      (tester) async {
        await openRegister(tester);
        await fillAll(tester);
        await acknowledge(tester);
        await submit(tester);

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text('Your vault'), findsOneWidget);
        expect(auth.accounts, contains('meera@example.com'));
        expect(repo.profiles.values.single.name, 'Meera Iyer');
        expect(repo.metas, hasLength(1));
      },
    );

    testWidgets('a weak master password is rejected', (tester) async {
      await openRegister(tester);
      await fillAll(tester, masterPw: 'password123', confirm: 'password123');
      await acknowledge(tester);
      await submit(tester);

      expect(find.textContaining('too easy to guess'), findsOneWidget);
      expect(auth.accounts, isEmpty);
    });

    testWidgets('the two master passwords must match', (tester) async {
      await openRegister(tester);
      await fillAll(tester, confirm: 'purple-Lantern-river-43');
      await acknowledge(tester);
      await submit(tester);

      expect(find.text('The master passwords do not match'), findsOneWidget);
      expect(auth.accounts, isEmpty);
    });

    testWidgets('the "cannot be recovered" box must be ticked', (tester) async {
      await openRegister(tester);
      await fillAll(tester);
      await submit(tester);

      expect(find.textContaining('cannot be recovered'), findsWidgets);
      expect(auth.accounts, isEmpty);
    });

    testWidgets('a taken email is reported', (tester) async {
      auth.accounts['meera@example.com'] = 'x';
      await openRegister(tester);
      await fillAll(tester);
      await acknowledge(tester);
      await submit(tester);

      expect(
        find.text('An account with this email already exists.'),
        findsOneWidget,
      );
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('rolls the account back when the profile cannot be saved', (
      tester,
    ) async {
      repo.saveProfileError = Exception('firestore down');
      await openRegister(tester);
      await fillAll(tester);
      await acknowledge(tester);
      await submit(tester);

      expect(
        find.textContaining("couldn't finish creating your vault"),
        findsOneWidget,
      );
      expect(
        auth.accounts,
        isEmpty,
        reason: 'so the user can simply try again',
      );
      expect(find.byType(HomeScreen), findsNothing);
    });
  });

  group('Lock screen', () {
    setUp(() async {
      auth = FakeAuthProvider(signedInUid: 'u1', email: 'aarav@example.com');
      await seedVault(repo, uid: 'u1', master: master, items: sampleItems());
    });

    testWidgets('a wrong master password is refused', (tester) async {
      await pumpGate(tester);
      expect(find.byType(LockScreen), findsOneWidget);

      await typeInto(tester, 'Master password', 'purple-Lantern-river-43');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect master password'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(vault.items, isEmpty);
    });

    testWidgets('the right master password opens the vault', (tester) async {
      await pumpGate(tester);
      await typeInto(tester, 'Master password', master);
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('6 logins'), findsOneWidget);
    });

    testWidgets('submitting with the keyboard also unlocks', (tester) async {
      await pumpGate(tester);
      await typeInto(tester, 'Master password', master);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('forgetting the master password means erasing the vault', (
      tester,
    ) async {
      auth.accounts['aarav@example.com'] = 'acct-pass';
      await pumpGate(tester);

      await tester.tap(find.text('Forgot master password?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('permanently deleted'), findsOneWidget);

      // Wrong account password: nothing is erased.
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        'wrong',
      );
      await tester.tap(find.text('Erase vault'));
      await tester.pumpAndSettle();
      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(repo.records, isNotEmpty);

      // Right one: the vault is erased and a new master password is requested.
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        'acct-pass',
      );
      await tester.tap(find.text('Erase vault'));
      await tester.pumpAndSettle();

      expect(repo.records, isEmpty);
      expect(find.byType(SetupVaultScreen), findsOneWidget);
    });

    testWidgets('signing out returns to the sign-in screen', (tester) async {
      await pumpGate(tester);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('Setting up a vault for an existing account', () {
    testWidgets('creates the vault and opens it', (tester) async {
      auth = FakeAuthProvider(signedInUid: 'u1', email: 'aarav@example.com');
      repo.profiles['u1'] = sampleProfile('u1');
      await pumpGate(tester);
      expect(find.byType(SetupVaultScreen), findsOneWidget);

      await typeInto(tester, 'Master password', master);
      await typeInto(tester, 'Confirm master password', master);
      final box = find.byType(CheckboxListTile);
      await tester.ensureVisible(box);
      await tester.tap(box);
      await tester.pump();
      final create = find.text('Create vault');
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(repo.metas['u1'], isNotNull);
    });
  });

  // Real apps move resumed -> inactive -> hidden -> paused and back again; the
  // framework asserts if a test skips steps.
  void goToBackground(WidgetTester tester) {
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
  }

  void comeBack(WidgetTester tester) {
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
  }

  group('Auto-lock', () {
    setUp(() async {
      auth = FakeAuthProvider(signedInUid: 'u1', email: 'aarav@example.com');
      await seedVault(repo, uid: 'u1', master: master, items: sampleItems());
    });

    Future<void> unlockViaUi(
      WidgetTester tester,
      SettingsService settings,
    ) async {
      await pumpGate(tester, settings: settings);
      await typeInto(tester, 'Master password', master);
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    }

    testWidgets('locks at once when the app goes to the background', (
      tester,
    ) async {
      await unlockViaUi(
        tester,
        settingsWith(autoLock: AutoLockDelay.immediately),
      );

      goToBackground(tester);
      await tester.pumpAndSettle();

      expect(vault.status, VaultStatus.locked);
      expect(
        vault.items,
        isEmpty,
        reason: 'decrypted data is dropped from memory',
      );
      comeBack(tester);
      await tester.pumpAndSettle();
      expect(find.byType(LockScreen), findsOneWidget);
    });

    testWidgets('stays unlocked after a short trip away', (tester) async {
      await unlockViaUi(
        tester,
        settingsWith(autoLock: AutoLockDelay.fifteenMinutes),
      );

      goToBackground(tester);
      comeBack(tester);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(vault.status, VaultStatus.unlocked);
    });

    testWidgets(
      'locking closes any open screen so secrets are never left showing',
      (tester) async {
        await unlockViaUi(tester, settingsWith());
        await tester.tap(find.text('GitHub'));
        await tester.pumpAndSettle();
        expect(find.text('aarav-dev'), findsOneWidget);

        vault.lock();
        await tester.pumpAndSettle();

        expect(find.byType(LockScreen), findsOneWidget);
        expect(find.text('aarav-dev'), findsNothing);
      },
    );
  });
}
