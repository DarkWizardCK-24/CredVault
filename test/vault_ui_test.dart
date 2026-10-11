import 'dart:convert';

import 'package:cred_vault/providers/vault_provider.dart';
import 'package:cred_vault/screens/add_credential_screen.dart';
import 'package:cred_vault/screens/credential_detail_screen.dart';
import 'package:cred_vault/screens/home_screen.dart';
import 'package:cred_vault/screens/lock_screen.dart';
import 'package:cred_vault/screens/login_screen.dart';
import 'package:cred_vault/services/settings_service.dart';
import 'package:cred_vault/widgets/credential_card.dart';
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
  late SettingsService settings;
  final clipboard = ClipboardSpy();

  setUp(() {
    repo = FakeVaultRepository();
    auth = FakeAuthProvider(signedInUid: 'u1', email: 'aarav@example.com')
      ..accounts['aarav@example.com'] = 'acct-pass';
    settings = settingsWith();
    clipboard.text = null;
  });

  /// Opens the unlocked app on [tab] (0 Vault, 1 Generator, 2 Security, 3 Profile).
  Future<void> pumpHome(
    WidgetTester tester, {
    int tab = 0,
    List? items,
    FakeBreachChecker? breach,
  }) async {
    usePhone(tester);
    clipboard.install(tester);
    vault = (await tester.runAsync(
      () => unlockedVault(
        repo,
        items: items == null ? null : [for (final i in items) i],
        breach: breach,
      ),
    ))!;
    addTearDown(vault.dispose);
    await tester.pumpWidget(
      testApp(
        auth: auth,
        vault: vault,
        settings: settings,
        home: HomeScreen(initialTab: tab),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The category chips scroll sideways. They are built a little beyond the
  /// screen edge, so "found" doesn't mean "on screen": drag until it is.
  Future<void> showChip(WidgetTester tester, String label) async {
    final chipRow = find.byType(ListView).first; // the first list on the page
    final chip = find.text(label);
    bool onScreen() {
      if (chip.evaluate().isEmpty) return false;
      final x = tester.getCenter(chip).dx;
      return x > 0 && x < 430 - 40;
    }

    // Try scrolling right first, then back to the left.
    for (final step in [-160.0, 160.0]) {
      for (var i = 0; i < 12 && !onScreen(); i++) {
        await tester.drag(chipRow, Offset(step, 0));
        await tester.pumpAndSettle();
      }
      if (onScreen()) return;
    }
  }

  Finder cardOf(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(CredentialCard));

  group('Vault tab', () {
    testWidgets('lists the logins, favourites first, with a health summary', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('Your vault'), findsOneWidget);
      expect(find.text('6 logins'), findsOneWidget);
      expect(find.text('4 need attention'), findsOneWidget);

      final order = [
        for (final name in [
          'GitHub',
          'Gmail',
          'Netflix',
          'Spotify',
          'Amazon',
          'PayPal',
        ])
          tester.getTopLeft(find.text(name)).dy,
      ];
      expect(order, orderedEquals([...order]..sort()), reason: 'list order');
    });

    testWidgets('shows what is wrong with each weak login', (tester) async {
      await pumpHome(tester);
      expect(
        find.descendant(
          of: cardOf('Gmail'),
          matching: find.text('Weak password'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardOf('Netflix'),
          matching: find.text('Reused password'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardOf('Amazon'),
          matching: find.text('Old password'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cardOf('PayPal'), matching: find.byType(Chip)),
        findsNothing,
      );
    });

    testWidgets('searches by name, username and notes', (tester) async {
      await pumpHome(tester);

      await tester.enterText(find.byType(TextField).first, 'spot');
      await tester.pumpAndSettle();
      expect(find.text('Spotify'), findsOneWidget);
      expect(find.text('Netflix'), findsNothing);

      await tester.enterText(find.byType(TextField).first, '4821');
      await tester.pumpAndSettle();
      expect(
        find.text('Gmail'),
        findsOneWidget,
        reason: 'matched on its notes',
      );

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('Nothing found'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('GitHub'), findsOneWidget);
    });

    testWidgets('filters by category and by favourites', (tester) async {
      await pumpHome(tester);

      await showChip(tester, 'Entertainment');
      await tester.tap(find.text('Entertainment'));
      await tester.pumpAndSettle();
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('Spotify'), findsOneWidget);
      expect(find.text('GitHub'), findsNothing);

      await showChip(tester, 'Favorites');
      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('Netflix'), findsNothing);

      await showChip(tester, 'All');
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('Netflix'), findsOneWidget);
    });

    testWidgets('can be sorted', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.byTooltip('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name (A-Z)'));
      await tester.pumpAndSettle();

      final amazon = tester.getTopLeft(find.text('Amazon')).dy;
      final netflix = tester.getTopLeft(find.text('Netflix')).dy;
      final github = tester.getTopLeft(find.text('GitHub')).dy;
      expect(github, lessThan(amazon), reason: 'the favourite stays on top');
      expect(amazon, lessThan(netflix));
    });

    testWidgets('a favourite can be toggled from the list', (tester) async {
      await pumpHome(tester);
      await tester.tap(
        find.descendant(
          of: cardOf('Gmail'),
          matching: find.byTooltip('Add to favorites'),
        ),
      );
      await tester.pumpAndSettle();

      expect(vault.items.firstWhere((c) => c.id == 'gm').favorite, isTrue);
      // Favourites first: Gmail (edited most recently) now follows GitHub.
      expect(
        tester.getTopLeft(find.text('Gmail')).dy,
        lessThan(tester.getTopLeft(find.text('Netflix')).dy),
      );
    });

    testWidgets('copies a password to the clipboard', (tester) async {
      await pumpHome(tester);
      await tester.tap(
        find.descendant(
          of: cardOf('GitHub'),
          matching: find.byTooltip('Copy password'),
        ),
      );
      await tester.pumpAndSettle();

      expect(clipboard.text, 'Zq7#mL2\$vR9!xT4w');
      expect(find.textContaining('Password for GitHub copied'), findsOneWidget);
    });

    testWidgets('an empty vault invites you to add the first login', (
      tester,
    ) async {
      await pumpHome(tester, items: const []);
      expect(find.text('Your vault is empty'), findsOneWidget);

      await tester.tap(find.text('Add a credential'));
      await tester.pumpAndSettle();
      expect(find.byType(AddCredentialScreen), findsOneWidget);
    });

    testWidgets('the lock button locks the vault', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byTooltip('Lock vault'));
      await tester.pump(); // (the real app now swaps in the lock screen)
      expect(vault.status, VaultStatus.locked);
      expect(vault.items, isEmpty);
    });
  });

  group('Credential details', () {
    testWidgets('hides the password until asked, and re-hides it', (
      tester,
    ) async {
      await pumpHome(tester);
      await tester.tap(find.text('GitHub'));
      await tester.pumpAndSettle();

      expect(find.byType(CredentialDetailScreen), findsOneWidget);
      expect(find.text('aarav-dev'), findsOneWidget);
      expect(find.text('Zq7#mL2\$vR9!xT4w'), findsNothing);

      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(find.text('Zq7#mL2\$vR9!xT4w'), findsOneWidget);

      await tester.pump(const Duration(seconds: 21));
      expect(
        find.text('Zq7#mL2\$vR9!xT4w'),
        findsNothing,
        reason: 'hides itself after 20 s',
      );
    });

    testWidgets('copies the username and the password', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('GitHub'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Copy username'));
      await tester.pumpAndSettle();
      expect(clipboard.text, 'aarav-dev');

      await tester.tap(find.byTooltip('Copy password'));
      await tester.pumpAndSettle();
      expect(clipboard.text, 'Zq7#mL2\$vR9!xT4w');
    });

    testWidgets('warns about a weak, reused or old password', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('Gmail'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Weak password'), findsWidgets);
      expect(
        find.textContaining('Consider changing this password'),
        findsOneWidget,
      );
      expect(find.text('Very weak'), findsOneWidget);
    });

    testWidgets('shows notes and dates', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('Gmail'));
      await tester.pumpAndSettle();
      expect(find.text('Recovery phone ends in 4821'), findsOneWidget);
      expect(find.text('Added'), findsOneWidget);
      expect(find.text('Password changed'), findsOneWidget);
    });

    testWidgets('delete asks first, and can be undone', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('GitHub'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Delete'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete GitHub?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(CredentialDetailScreen), findsNothing);
      expect(find.text('GitHub'), findsNothing);
      expect(repo.records.containsKey('gh'), isFalse);

      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();
      expect(find.text('GitHub'), findsOneWidget);
      expect(repo.records.containsKey('gh'), isTrue);
    });

    testWidgets('cancelling the delete dialog keeps the login', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('GitHub'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Delete'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(vault.items.any((c) => c.id == 'gh'), isTrue);
    });

    testWidgets('checks one password against known breaches', (tester) async {
      await pumpHome(tester, breach: FakeBreachChecker({'password1': 9012}));
      await tester.tap(find.text('Gmail'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check now'));
      await tester.pumpAndSettle();
      expect(find.text('Found in 9012 breaches'), findsOneWidget);
    });

    testWidgets('reports a clean password and an offline check', (
      tester,
    ) async {
      final checker = FakeBreachChecker();
      await pumpHome(tester, breach: checker);
      await tester.tap(find.text('GitHub'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check now'));
      await tester.pumpAndSettle();
      expect(find.text('Not found in known breaches'), findsOneWidget);

      checker.offline = true;
      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't check"), findsOneWidget);
    });
  });

  group('Adding and editing', () {
    Future<void> openAdd(WidgetTester tester) async {
      await tester.tap(find.text('Add login'));
      await tester.pumpAndSettle();
      expect(find.byType(AddCredentialScreen), findsOneWidget);
    }

    Future<void> tapSave(WidgetTester tester) async {
      final save = find.text('Save to vault');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
    }

    testWidgets('requires a username and a password', (tester) async {
      await pumpHome(tester);
      await openAdd(tester);
      await tapSave(tester);

      expect(find.text('Enter the username or email'), findsOneWidget);
      expect(find.text('Enter the password'), findsOneWidget);
      expect(find.byType(AddCredentialScreen), findsOneWidget);
    });

    testWidgets('saves a new login, encrypted', (tester) async {
      await pumpHome(tester);
      await openAdd(tester);

      await tester.tap(find.text('Service'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search services'),
        'slack',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Slack'));
      await tester.pumpAndSettle();

      await typeInto(tester, 'Username or email', 'team@acme.io');
      await typeInto(tester, 'Password', 'Rt8^wQ3!zN6#hY1k');
      await typeInto(tester, 'Website (optional)', 'acme.slack.com');
      await tapSave(tester);

      expect(find.byType(AddCredentialScreen), findsNothing);
      expect(vault.items, hasLength(7));
      final saved = vault.items.firstWhere((c) => c.platform == 'Slack');
      expect(saved.username, 'team@acme.io');
      expect(
        saved.category.label,
        'Work',
        reason: 'category follows the service',
      );

      final raw = repo.records[saved.id]!.data!;
      expect(raw, isNot(contains('Rt8^wQ3!zN6#hY1k')));
      expect(raw, isNot(contains('team@acme.io')));
      expect(
        utf8.decode(base64Decode(raw), allowMalformed: true),
        isNot(contains('acme')),
      );
    });

    testWidgets('"Other" needs a name of its own', (tester) async {
      await pumpHome(tester);
      await openAdd(tester);
      await tester.tap(find.text('Service'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search services'),
        'other',
      );
      await tester.pumpAndSettle();
      // "Other" is also a category chip on the page underneath the sheet.
      await tester.tap(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text('Other'),
        ),
      );
      await tester.pumpAndSettle();

      await typeInto(tester, 'Username or email', 'meter-123');
      await typeInto(tester, 'Password', 'Rt8^wQ3!zN6#hY1k');
      await tapSave(tester);
      expect(find.text('Give this login a name'), findsOneWidget);

      await typeInto(tester, 'Name', 'Electricity portal');
      await tapSave(tester);
      expect(
        vault.items.any((c) => c.displayName == 'Electricity portal'),
        isTrue,
      );
    });

    testWidgets('rejects a malformed website', (tester) async {
      await pumpHome(tester);
      await openAdd(tester);
      await typeInto(tester, 'Username or email', 'me');
      await typeInto(tester, 'Password', 'Rt8^wQ3!zN6#hY1k');
      await typeInto(tester, 'Website (optional)', 'not a url');
      await tapSave(tester);
      expect(find.text('Enter a valid web address'), findsOneWidget);
    });

    testWidgets('the generator fills in a strong password', (tester) async {
      await pumpHome(tester);
      await openAdd(tester);
      await typeInto(tester, 'Username or email', 'me@example.com');

      await tester.tap(find.byTooltip('Generate a password'));
      await tester.pumpAndSettle();
      expect(find.text('Generate a password'), findsOneWidget);
      await tester.tap(find.text('Use this password'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Password'),
      );
      expect(field.controller!.text.length, 20);
      expect(find.text('Excellent'), findsOneWidget);
    });

    testWidgets('editing keeps the id and saves the changes', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('GitHub'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit credential'), findsOneWidget);
      await typeInto(tester, 'Username or email', 'renamed-user');
      final save = find.text('Save changes');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        vault.items.where((c) => c.id == 'gh').single.username,
        'renamed-user',
      );
      expect(vault.items, hasLength(6));
      expect(
        find.text('renamed-user'),
        findsOneWidget,
        reason: 'the detail page updates',
      );
    });
  });

  group('Generator tab', () {
    testWidgets('makes a new password each time', (tester) async {
      await pumpHome(tester, tab: 1);
      expect(find.text('Generator'), findsWidgets);

      String current() =>
          tester.widget<SelectableText>(find.byType(SelectableText)).data!;
      final first = current();
      expect(first.length, 20);

      await tester.tap(find.text('Regenerate'));
      await tester.pump();
      expect(current(), isNot(first));
    });

    testWidgets('options change what is generated', (tester) async {
      await pumpHome(tester, tab: 1);
      String current() =>
          tester.widget<SelectableText>(find.byType(SelectableText)).data!;

      // Turn off symbols, numbers and uppercase: only lowercase remains.
      for (final label in ['Symbols', 'Numbers', 'Uppercase']) {
        await tester.tap(find.text(label));
        await tester.pump();
      }
      expect(current(), matches(RegExp(r'^[a-z]{20}$')));

      // The last remaining kind can't be switched off.
      await tester.tap(find.text('Lowercase'));
      await tester.pump();
      expect(current(), matches(RegExp(r'^[a-z]{20}$')));
    });

    testWidgets('the length slider is respected', (tester) async {
      await pumpHome(tester, tab: 1);
      String current() =>
          tester.widget<SelectableText>(find.byType(SelectableText)).data!;

      await tester.drag(find.byType(Slider), const Offset(-400, 0));
      await tester.pump();
      expect(current().length, 8);
      await tester.drag(find.byType(Slider), const Offset(600, 0));
      await tester.pump();
      expect(current().length, 64);
    });

    testWidgets('copies the password', (tester) async {
      await pumpHome(tester, tab: 1);
      final shown = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(clipboard.text, shown);
    });

    testWidgets('can be saved straight into a new login', (tester) async {
      await pumpHome(tester, tab: 1);
      final shown = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      final save = find.text('Save as a new login');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.byType(AddCredentialScreen), findsOneWidget);
      final field = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Password'),
      );
      expect(field.controller!.text, shown);
    });
  });

  group('Security tab', () {
    testWidgets('scores the vault and lists the problems', (tester) async {
      await pumpHome(tester, tab: 2);

      expect(find.text('Security score'), findsOneWidget);
      expect(find.text('6 logins checked'), findsOneWidget);
      expect(vault.report.score, inInclusiveRange(60, 90));
      expect(
        find.text('Weak passwords'),
        findsOneWidget,
        reason: 'first non-empty group',
      );
      expect(find.text('Gmail'), findsOneWidget);

      await tester.tap(find.text('Reused'));
      await tester.pumpAndSettle();
      expect(find.text('Reused passwords'), findsOneWidget);
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('Spotify'), findsOneWidget);

      await tester.tap(find.text('Old'));
      await tester.pumpAndSettle();
      expect(find.text('Amazon'), findsOneWidget);
    });

    testWidgets('a healthy vault says so', (tester) async {
      await pumpHome(
        tester,
        tab: 2,
        items: [
          sampleCredential(id: 'a', password: 'Zq7#mL2\$vR9!xT4w'),
          sampleCredential(
            id: 'b',
            platform: 'Slack',
            password: 'Hy5@nB8&kD3^pW6e',
          ),
        ],
      );
      expect(find.text('100'), findsOneWidget);
      expect(find.textContaining('Excellent'), findsOneWidget);
      expect(find.text('Nothing to fix here. Nice!'), findsOneWidget);
    });

    testWidgets('the breach scan flags compromised logins', (tester) async {
      final checker = FakeBreachChecker({'Hy5@nB8&kD3^pW6e': 42});
      await pumpHome(tester, tab: 2, breach: checker);

      await tester.tap(find.text('Check my passwords'));
      await tester.pumpAndSettle();

      expect(vault.breachedIds, {'nf', 'sp'});
      expect(find.textContaining('Last checked'), findsOneWidget);
      expect(find.text('Scan again'), findsOneWidget);
      // Breached logins are listed first from now on.
      await tester.tap(find.text('Breached'));
      await tester.pumpAndSettle();
      expect(find.text('Breached passwords'), findsOneWidget);
      expect(find.text('Netflix'), findsOneWidget);
    });

    testWidgets('tapping a problem opens that login', (tester) async {
      await pumpHome(tester, tab: 2);
      await tester.tap(find.text('Gmail'));
      await tester.pumpAndSettle();
      expect(find.byType(CredentialDetailScreen), findsOneWidget);
    });
  });

  group('Profile tab', () {
    testWidgets('shows the account and the vault summary', (tester) async {
      await pumpHome(tester, tab: 3);
      expect(find.text('Aarav Mehta'), findsOneWidget);
      expect(find.text('aarav@example.com'), findsOneWidget);
      expect(find.text('Member since Mar 2026'), findsOneWidget);
      expect(find.text('6'), findsWidgets);
    });

    testWidgets('auto-lock and clipboard settings are saved', (tester) async {
      await pumpHome(tester, tab: 3);

      await tester.tap(find.text('Auto-lock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('After 5 minutes'));
      await tester.pumpAndSettle();
      expect(settings.autoLock, AutoLockDelay.fiveMinutes);

      await tester.tap(find.text('Clear clipboard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('After 15 seconds'));
      await tester.pumpAndSettle();
      expect(settings.clipboardClear, ClipboardClear.fifteen);
    });

    testWidgets('the name can be changed', (tester) async {
      await pumpHome(tester, tab: 3);
      await tester.tap(find.byTooltip('Edit name'));
      await tester.pumpAndSettle();
      await typeInto(tester, 'Full name', 'Aarav M.');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(vault.profile!.name, 'Aarav M.');
      expect(repo.profiles['u1']!.name, 'Aarav M.');
      expect(find.text('Aarav M.'), findsOneWidget);
    });

    testWidgets('changing the master password re-encrypts the vault', (
      tester,
    ) async {
      await pumpHome(tester, tab: 3);
      await tester.tap(find.text('Change master password'));
      await tester.pumpAndSettle();

      Future<void> fill(String current, String next, String confirm) async {
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Current master password'),
          current,
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'New master password'),
          next,
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm new master password'),
          confirm,
        );
        await tester.pump();
      }

      // Wrong current password.
      await fill(
        'wrong-wrong-wrong-1',
        'amber-Falcon-ocean-77',
        'amber-Falcon-ocean-77',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Change'));
      await tester.pumpAndSettle();
      expect(
        find.text('Your current master password is incorrect'),
        findsOneWidget,
      );

      // A weak new password.
      await fill(master, 'password123', 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Change'));
      await tester.pumpAndSettle();
      expect(find.textContaining('too easy to guess'), findsOneWidget);

      // Success.
      final before = repo.records['gh']!.data;
      await fill(master, 'amber-Falcon-ocean-77', 'amber-Falcon-ocean-77');
      await tester.tap(find.widgetWithText(FilledButton, 'Change'));
      await tester.pumpAndSettle();
      expect(find.text('Master password changed'), findsOneWidget);
      expect(repo.records['gh']!.data, isNot(before));

      vault.lock();
      await tester.pump(); // (the real app swaps in the lock screen here)
      expect(await vault.unlock(master), isFalse);
      expect(await vault.unlock('amber-Falcon-ocean-77'), isTrue);
    });

    testWidgets('"Lock vault now" locks it', (tester) async {
      await pumpHome(tester, tab: 3);
      await tester.tap(find.text('Lock vault now'));
      await tester.pump();
      expect(vault.status, VaultStatus.locked);
    });

    testWidgets('sending a password-reset email', (tester) async {
      await pumpHome(tester, tab: 3);
      await tester.scrollUntilVisible(
        find.text('Reset account password'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Reset account password'));
      await tester.pumpAndSettle();
      expect(auth.resetEmails, ['aarav@example.com']);
    });

    testWidgets('explains how data is protected', (tester) async {
      await pumpHome(tester, tab: 3);
      await tester.scrollUntilVisible(
        find.text('How your data is protected'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('How your data is protected'));
      await tester.pumpAndSettle();
      expect(find.textContaining('AES-256-GCM'), findsOneWidget);
      expect(find.textContaining('cannot be recovered'), findsOneWidget);
    });

    testWidgets(
      'deleting the account needs the right password, then removes everything',
      (tester) async {
        await pumpHome(tester, tab: 3);
        await tester.scrollUntilVisible(
          find.text('Delete account'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Delete account'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'nope');
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(find.text('Incorrect email or password.'), findsOneWidget);
        expect(auth.accountDeleted, isFalse);
        expect(repo.records, isNotEmpty);
      },
    );

    testWidgets('deleting the account removes the data and signs out', (
      tester,
    ) async {
      // Run through the real gate so the sign-out is visible.
      usePhone(tester);
      clipboard.install(tester);
      await seedVault(repo, uid: 'u1', master: master, items: sampleItems());
      vault = newVault(repo);
      addTearDown(vault.dispose);
      await tester.pumpWidget(
        testApp(auth: auth, vault: vault, settings: settings),
      );
      await tester.pumpAndSettle();
      await typeInto(tester, 'Master password', master);
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.byType(LockScreen), findsNothing);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Delete account'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'acct-pass');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(auth.accountDeleted, isTrue);
      expect(repo.records, isEmpty);
      expect(repo.profiles, isEmpty);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('Navigation', () {
    testWidgets('moves between the four tabs', (tester) async {
      await pumpHome(tester);
      for (final tab in ['Generator', 'Security', 'Profile', 'Vault']) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(tab),
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('Your vault'), findsOneWidget);
      expect(find.text('Add login'), findsOneWidget);
    });

    testWidgets('the add button only shows on the vault tab', (tester) async {
      await pumpHome(tester, tab: 2);
      expect(find.text('Add login'), findsNothing);
    });
  });
}
