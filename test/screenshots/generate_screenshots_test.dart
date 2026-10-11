// Generates the README screenshots from the real screens using sample data
// (no Firebase needed). Skipped during a normal `flutter test`; run with:
//
//   flutter test test/screenshots --dart-define=SCREENSHOTS=true
//
// PNGs are written to docs/screenshots/. All data below is made up.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cred_vault/core/password/password_generator.dart';
import 'package:cred_vault/models/credential_category.dart';
import 'package:cred_vault/models/credential_model.dart';
import 'package:cred_vault/providers/vault_provider.dart';
import 'package:cred_vault/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/fonts.dart';
import '../support/harness.dart';

const bool _enabled = bool.fromEnvironment('SCREENSHOTS');
final _boundaryKey = GlobalKey();

/// More logins than the tests use, so the list looks lived-in.
List<Credential> showcaseItems() {
  final now = DateTime(2026, 10, 13, 15, 40);
  Credential c(
    String id,
    String platform,
    String user,
    String pw,
    CredentialCategory cat, {
    bool fav = false,
    int ageDays = 12,
    int editedDaysAgo = 5,
    String title = '',
    String url = '',
    String notes = '',
  }) => sampleCredential(
    id: id,
    platform: platform,
    title: title,
    username: user,
    password: pw,
    url: url,
    notes: notes,
    category: cat,
    favorite: fav,
    createdAt: now.subtract(Duration(days: editedDaysAgo + 90)),
    updatedAt: now.subtract(Duration(days: editedDaysAgo)),
    passwordChangedAt: now.subtract(Duration(days: ageDays)),
  );

  const strongA = 'Zq7#mL2\$vR9!xT4w';
  const strongB = 'Xb4%tN7@wE2&kH9s';
  const strongC = 'Mv3^pK8!dZ5#qY6c';
  const shared = 'Hy5@nB8&kD3^pW6e';
  return [
    c(
      'gh',
      'GitHub',
      'aarav-dev',
      strongA,
      CredentialCategory.development,
      fav: true,
      url: 'https://github.com',
      editedDaysAgo: 1,
    ),
    c(
      'li',
      'LinkedIn',
      'aarav.mehta@gmail.com',
      strongB,
      CredentialCategory.work,
      fav: true,
      editedDaysAgo: 2,
    ),
    c(
      'gm',
      'Gmail',
      'aarav.mehta@gmail.com',
      'password1',
      CredentialCategory.work,
      editedDaysAgo: 3,
      notes: 'Recovery phone ends in 4821',
    ),
    c(
      'nf',
      'Netflix',
      'family@home.com',
      shared,
      CredentialCategory.entertainment,
      editedDaysAgo: 4,
    ),
    c(
      'sp',
      'Spotify',
      'aarav.music',
      shared,
      CredentialCategory.entertainment,
      editedDaysAgo: 5,
    ),
    c(
      'ig',
      'Instagram',
      'aarav.clicks',
      strongC,
      CredentialCategory.social,
      editedDaysAgo: 6,
    ),
    c(
      'az',
      'Amazon',
      'aarav.shop@gmail.com',
      'Fj2*uC9\$sM5!gQ7z',
      CredentialCategory.shopping,
      ageDays: 320,
      editedDaysAgo: 8,
    ),
    c(
      'pp',
      'PayPal',
      'aarav@pay.com',
      'Wc6&yP1@hJ8!sD4n',
      CredentialCategory.finance,
      editedDaysAgo: 9,
    ),
    c(
      'wifi',
      'Other',
      'admin',
      'Lk9^bT3#qX7!vF2m',
      CredentialCategory.other,
      title: 'Home router',
      editedDaysAgo: 20,
    ),
  ];
}

Future<VaultProvider> _pump(
  WidgetTester tester, {
  Widget? home,
  FakeAuthProvider? auth,
  FakeVaultRepository? repo,
  FakeBreachChecker? breach,
  bool unlocked = true,
  Size size = const Size(430, 932),
  double dpr = 2,
}) async {
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);

  final repository = repo ?? FakeVaultRepository();
  late final VaultProvider vault;
  if (unlocked) {
    vault = (await tester.runAsync(
      () => unlockedVault(repository, items: showcaseItems(), breach: breach),
    ))!;
  } else {
    await seedVault(
      repository,
      uid: 'u1',
      master: master,
      items: showcaseItems(),
    );
    vault = newVault(repository);
  }
  addTearDown(vault.dispose);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: testApp(
        auth:
            auth ??
            FakeAuthProvider(signedInUid: 'u1', email: 'aarav@example.com'),
        vault: vault,
        settings: settingsWith(),
        home: home,
      ),
    ),
  );
  // Images decode asynchronously, so load the logo before the first frame is
  // captured (otherwise it would be drawn as an empty box).
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage('assets/images/logo.png'),
      tester.element(find.byType(MaterialApp)),
    );
  });
  await tester.pumpAndSettle();
  return vault;
}

Future<void> _shot(WidgetTester tester, String name, {double dpr = 2}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  ScaffoldMessenger.of(
    tester.element(find.byType(Scaffold).first),
  ).clearSnackBars();
  await tester.pumpAndSettle();

  await tester.runAsync(() async {
    final boundary =
        _boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/screenshots/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path} (${image.width}x${image.height})');
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (_enabled) await loadAppFonts();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sign in and register', skip: !_enabled, (tester) async {
    await _pump(tester, auth: FakeAuthProvider(), unlocked: false);
    await _shot(tester, '01-sign-in');

    await tester.tap(find.text('Create a vault'));
    await tester.pumpAndSettle();
    await typeInto(tester, 'Full name', 'Meera Iyer');
    await typeInto(tester, 'Email', 'meera@example.com');
    await typeInto(tester, 'Account password', 'acct-pass-1');
    await typeInto(tester, 'Master password', 'purple-Lantern-river-42');
    await typeInto(
      tester,
      'Confirm master password',
      'purple-Lantern-river-42',
    );
    await tester.pumpAndSettle();
    await _shot(tester, '02-create-vault');
  });

  testWidgets('lock screen', skip: !_enabled, (tester) async {
    await _pump(tester, unlocked: false);
    await _shot(tester, '03-locked');
  });

  testWidgets('vault', skip: !_enabled, (tester) async {
    await _pump(tester, home: const HomeScreen());
    await _shot(tester, '04-vault');

    // Open one login.
    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();
    await _shot(tester, '05-details');

    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    await _shot(tester, '06-details-revealed');
  });

  testWidgets('add credential', skip: !_enabled, (tester) async {
    await _pump(tester, home: const HomeScreen());
    await tester.tap(find.text('Add login'));
    await tester.pumpAndSettle();
    await typeInto(tester, 'Username or email', 'team@acme.io');
    await typeInto(tester, 'Password', 'Rt8^wQ3!zN6#hY1k');
    await tester.pumpAndSettle();
    // Typing scrolled the form; show it from the top.
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 900),
    );
    await tester.pumpAndSettle();
    await _shot(tester, '07-add-login');

    await tester.tap(find.text('Service'));
    await tester.pumpAndSettle();
    await _shot(tester, '08-pick-service');
  });

  testWidgets('generator', skip: !_enabled, (tester) async {
    await _pump(
      tester,
      home: HomeScreen(
        initialTab: 1,
        generator: PasswordGenerator(random: Random(11)),
      ),
    );
    await _shot(tester, '09-generator');
  });

  testWidgets('security', skip: !_enabled, (tester) async {
    await _pump(
      tester,
      home: const HomeScreen(initialTab: 2),
      breach: FakeBreachChecker({'password1': 120456}),
    );
    await _shot(tester, '10-security');

    await tester.tap(find.text('Check my passwords'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Breached'));
    await tester.pumpAndSettle();
    await _shot(tester, '11-security-scan');
  });

  testWidgets('profile', skip: !_enabled, (tester) async {
    await _pump(tester, home: const HomeScreen(initialTab: 3));
    await _shot(tester, '12-profile');
  });

  testWidgets('wide screen', skip: !_enabled, (tester) async {
    await _pump(
      tester,
      home: const HomeScreen(),
      size: const Size(1100, 900),
      dpr: 1.5,
    );
    await _shot(tester, '13-vault-wide', dpr: 1.5);
  });

  testWidgets('wide screen security', skip: !_enabled, (tester) async {
    await _pump(
      tester,
      home: const HomeScreen(initialTab: 2),
      breach: FakeBreachChecker({'password1': 120456}),
      size: const Size(1100, 900),
      dpr: 1.5,
    );
    await _shot(tester, '14-security-wide', dpr: 1.5);
  });
}
