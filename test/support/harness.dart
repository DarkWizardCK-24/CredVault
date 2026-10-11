import 'package:cred_vault/models/credential_category.dart';
import 'package:cred_vault/models/credential_model.dart';
import 'package:cred_vault/providers/vault_provider.dart';
import 'package:cred_vault/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const master = 'purple-Lantern-river-42';

/// Phone-sized and tall enough that lists build every item.
void usePhone(WidgetTester tester, {Size size = const Size(430, 1500)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Records what the app copies to the clipboard.
class ClipboardSpy {
  String? text;

  void install(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          text = (call.arguments as Map)['text'] as String?;
        } else if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': text};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }
}

/// A realistic vault: one favourite, one weak, a reused pair, an old password.
List<Credential> sampleItems() {
  final now = DateTime(2026, 10, 13, 15, 40);
  Credential c(
    String id,
    String platform,
    String user,
    String pw,
    CredentialCategory cat, {
    bool fav = false,
    int ageDays = 10,
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
    createdAt: now.subtract(Duration(days: editedDaysAgo + 30)),
    updatedAt: now.subtract(Duration(days: editedDaysAgo)),
    passwordChangedAt: now.subtract(Duration(days: ageDays)),
  );

  const strong = 'Zq7#mL2\$vR9!xT4w';
  const shared = 'Hy5@nB8&kD3^pW6e';
  return [
    c(
      'gh',
      'GitHub',
      'aarav-dev',
      strong,
      CredentialCategory.development,
      fav: true,
      url: 'https://github.com',
      editedDaysAgo: 1,
    ),
    c(
      'gm',
      'Gmail',
      'aarav@gmail.com',
      'password1',
      CredentialCategory.work,
      editedDaysAgo: 2,
      notes: 'Recovery phone ends in 4821',
    ),
    c(
      'nf',
      'Netflix',
      'family@home.com',
      shared,
      CredentialCategory.entertainment,
      editedDaysAgo: 3,
    ),
    c(
      'sp',
      'Spotify',
      'aarav.music',
      shared,
      CredentialCategory.entertainment,
      editedDaysAgo: 4,
    ),
    c(
      'az',
      'Amazon',
      'aarav.shop',
      'Fj2*uC9\$sM5!gQ7z',
      CredentialCategory.shopping,
      ageDays: 320,
      editedDaysAgo: 6,
    ),
    c(
      'pp',
      'PayPal',
      'aarav@pay.com',
      'Xb4%tN7@wE2&kH9s',
      CredentialCategory.finance,
      editedDaysAgo: 7,
    ),
  ];
}

/// Seeds a vault for `u1`, signs in and unlocks it.
Future<VaultProvider> unlockedVault(
  FakeVaultRepository repo, {
  List<Credential>? items,
  FakeBreachChecker? breach,
}) async {
  await seedVault(
    repo,
    uid: 'u1',
    master: master,
    items: items ?? sampleItems(),
  );
  final vault = newVault(repo, breach: breach);
  await vault.attach('u1');
  await vault.unlock(master);
  await Future<void>.delayed(Duration.zero);
  return vault;
}

SettingsService settingsWith({
  AutoLockDelay autoLock = AutoLockDelay.oneMinute,
  ClipboardClear clipboard = ClipboardClear.never,
}) {
  final s = SettingsService();
  s.setAutoLock(autoLock);
  s.setClipboardClear(clipboard);
  return s;
}

/// Types into the form field with the given label.
Future<void> typeInto(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
}
