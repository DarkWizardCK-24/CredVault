import 'dart:convert';

import 'package:cred_vault/models/credential_category.dart';
import 'package:cred_vault/models/user_model.dart';
import 'package:cred_vault/models/vault_models.dart';
import 'package:cred_vault/providers/auth_provider.dart';
import 'package:cred_vault/providers/vault_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Lets pending stream events and futures run.
Future<void> settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const master = 'purple-Lantern-river-42';

void main() {
  late FakeVaultRepository repo;
  late VaultProvider vault;

  setUp(() {
    repo = FakeVaultRepository();
    vault = newVault(repo);
  });

  tearDown(() => vault.dispose());

  Future<void> signedInWithVault({List items = const []}) async {
    await seedVault(
      repo,
      uid: 'u1',
      master: master,
      items: [for (final c in items) c],
    );
    await vault.attach('u1');
    await vault.unlock(master);
    await settle();
  }

  group('account states', () {
    test('nobody signed in', () async {
      await vault.attach(null);
      expect(vault.status, VaultStatus.signedOut);
    });

    test('an account without a vault needs setup', () async {
      repo.profiles['u1'] = UserModel(
        uid: 'u1',
        name: 'Aarav',
        email: 'a@b.co',
        createdAt: DateTime(2026),
      );
      await vault.attach('u1');
      expect(vault.status, VaultStatus.needsSetup);
    });

    test(
      'an account with a vault starts locked, with nothing decrypted',
      () async {
        await seedVault(
          repo,
          uid: 'u1',
          master: master,
          items: [sampleCredential(id: 'a')],
        );
        await vault.attach('u1');
        expect(vault.status, VaultStatus.locked);
        expect(vault.items, isEmpty);
        expect(vault.profile?.name, 'Aarav Mehta');
      },
    );

    test('a load failure can be retried', () async {
      await seedVault(repo, uid: 'u1', master: master);
      repo.loadError = Exception('offline');
      await vault.attach('u1');
      expect(vault.status, VaultStatus.error);
      expect(vault.loadError, isNotNull);

      repo.loadError = null;
      await vault.reload();
      expect(vault.status, VaultStatus.locked);
    });

    test('signing out resets everything', () async {
      await signedInWithVault(items: [sampleCredential(id: 'a')]);
      expect(vault.items, hasLength(1));
      await vault.attach(null);
      expect(vault.status, VaultStatus.signedOut);
      expect(vault.items, isEmpty);
      expect(vault.profile, isNull);
    });
  });

  group('locking', () {
    test('the right master password unlocks and decrypts', () async {
      await signedInWithVault(
        items: [
          sampleCredential(
            id: 'a',
            platform: 'GitHub',
            password: 'Zq7#mL2\$vR9!xT4w',
          ),
        ],
      );
      expect(vault.status, VaultStatus.unlocked);
      expect(vault.items.single.password, 'Zq7#mL2\$vR9!xT4w');
      expect(vault.itemsLoaded, isTrue);
    });

    test('a wrong master password gets nothing', () async {
      await seedVault(
        repo,
        uid: 'u1',
        master: master,
        items: [sampleCredential(id: 'a')],
      );
      await vault.attach('u1');

      expect(await vault.unlock('purple-Lantern-river-43'), isFalse);
      expect(vault.status, VaultStatus.locked);
      expect(vault.items, isEmpty);
    });

    test('locking wipes the decrypted data from memory', () async {
      await signedInWithVault(items: [sampleCredential(id: 'a')]);
      vault.breachedIds.add('a');
      vault.lock();
      expect(vault.status, VaultStatus.locked);
      expect(vault.items, isEmpty);
      expect(vault.itemsLoaded, isFalse);
      expect(vault.breachedIds, isEmpty);
      // Nothing can be changed while locked.
      expect(() => vault.add(sampleCredential()), throwsStateError);

      expect(await vault.unlock(master), isTrue);
      await settle();
      expect(vault.items, hasLength(1));
    });

    test('new records appear live (e.g. added on another device)', () async {
      await signedInWithVault();
      expect(vault.items, isEmpty);

      final key = await fastCrypto.deriveKey(master, repo.metas['u1']!.kdf);
      final extra = sampleCredential(id: 'remote', platform: 'Slack');
      await repo.addRecord(
        'u1',
        await fastCrypto.encrypt(key, extra.toPayload()),
        DateTime(2026, 10, 14),
      );
      await settle();

      expect(vault.items.map((c) => c.platform), ['Slack']);
    });

    test('records that cannot be decrypted are counted, not shown', () async {
      await signedInWithVault(items: [sampleCredential(id: 'ok')]);
      await repo.addRecord(
        'u1',
        base64Encode(List.filled(40, 9)),
        DateTime(2026, 10, 14),
      );
      await settle();
      expect(vault.items.map((c) => c.id), ['ok']);
      expect(vault.undecryptableCount, 1);
    });
  });

  group('storing credentials', () {
    test('everything secret is encrypted at rest', () async {
      await signedInWithVault();
      await vault.add(
        sampleCredential(
          platform: 'GitHub',
          username: 'secret.user@example.com',
          password: 'my-very-secret-pw',
          url: 'https://private.example',
          notes: 'sensitive note',
        ),
      );

      final stored = repo.records.values.single.data!;
      for (final secret in [
        'secret.user@example.com',
        'my-very-secret-pw',
        'private.example',
        'sensitive note',
        'GitHub',
      ]) {
        expect(stored, isNot(contains(secret)));
        expect(
          utf8.decode(base64Decode(stored), allowMalformed: true),
          isNot(contains(secret)),
        );
      }
      expect(repo.owners.values.single, 'u1');
    });

    test('add, edit and favourite', () async {
      await signedInWithVault();
      final added = await vault.add(
        sampleCredential(platform: 'Netflix', password: 'old-Pass-9!x'),
      );
      expect(vault.items.single.id, added.id);
      await settle();

      await vault.toggleFavorite(vault.items.single);
      await settle();
      expect(vault.items.single.favorite, isTrue);

      await vault.update(vault.items.single.copyWith(username: 'new@user.com'));
      await settle();
      expect(vault.items.single.username, 'new@user.com');
      expect(vault.items, hasLength(1));
    });

    test(
      'the password-changed date only moves when the password does',
      () async {
        var clock = DateTime(2026, 1, 1);
        final v = VaultProvider(
          repository: repo,
          crypto: fastCrypto,
          clock: () => clock,
        );
        addTearDown(v.dispose);
        await seedVault(repo, uid: 'u1', master: master);
        await v.attach('u1');
        await v.unlock(master);

        final saved = await v.add(sampleCredential(password: 'first-Pass-1!z'));
        expect(saved.passwordChangedAt, DateTime(2026, 1, 1));

        clock = DateTime(2026, 6, 1);
        final renamed = await v.update(
          saved.copyWith(username: 'other@user.com'),
        );
        expect(renamed.passwordChangedAt, DateTime(2026, 1, 1));

        final changed = await v.update(
          renamed.copyWith(password: 'second-Pass-2@y'),
        );
        expect(changed.passwordChangedAt, DateTime(2026, 6, 1));
      },
    );

    test('delete can be undone exactly', () async {
      await signedInWithVault();
      final saved = await vault.add(
        sampleCredential(platform: 'Slack', notes: 'keep me'),
      );
      await settle();
      final original = vault.items.single;

      await vault.delete(original);
      await settle();
      expect(vault.items, isEmpty);
      expect(repo.records, isEmpty);

      await vault.restore(original);
      await settle();
      expect(vault.items.single.id, saved.id);
      expect(vault.items.single.notes, 'keep me');
      expect(vault.items.single.createdAt, original.createdAt);
    });
  });

  group('creating a vault', () {
    test('a brand-new vault starts unlocked and empty', () async {
      repo.profiles['u1'] = UserModel(
        uid: 'u1',
        name: 'A',
        email: 'a@b.co',
        createdAt: DateTime(2026),
      );
      await vault.attach('u1');
      await vault.createVault(master);
      await settle();

      expect(vault.status, VaultStatus.unlocked);
      expect(vault.items, isEmpty);
      final meta = repo.metas['u1']!;
      expect(meta.salt.length, 16);
      expect(meta.verifier, isNot(contains('credvault')));
    });

    test('registering creates the account, profile and vault', () async {
      final auth = FakeAuthProvider(initialized: true);
      await vault.registerAccount(
        auth: auth,
        name: ' Meera Iyer ',
        email: 'meera@example.com',
        accountPassword: 'acct-pass',
        masterPassword: master,
      );
      await settle();

      expect(auth.accounts, contains('meera@example.com'));
      expect(vault.status, VaultStatus.unlocked);
      final uid = auth.userId!;
      expect(repo.profiles[uid]!.name, 'Meera Iyer');
      expect(repo.metas[uid], isNotNull);
      // Attaching the new session afterwards must not undo the registration.
      await vault.attach(uid);
      expect(vault.status, VaultStatus.unlocked);
    });

    test('a failure part-way rolls the new account back', () async {
      final auth = FakeAuthProvider(initialized: true);
      repo.saveProfileError = Exception('firestore down');

      await expectLater(
        vault.registerAccount(
          auth: auth,
          name: 'Meera',
          email: 'meera@example.com',
          accountPassword: 'acct-pass',
          masterPassword: master,
        ),
        throwsA(isA<Exception>()),
      );

      expect(auth.accounts, isEmpty, reason: 'the account was removed again');
      expect(auth.userId, isNull);
      expect(vault.status, VaultStatus.signedOut);
      expect(repo.metas, isEmpty);
    });

    test('a taken email is reported and nothing is created', () async {
      final auth = FakeAuthProvider(initialized: true)
        ..accounts['meera@example.com'] = 'x';
      await expectLater(
        vault.registerAccount(
          auth: auth,
          name: 'Meera',
          email: 'meera@example.com',
          accountPassword: 'acct-pass',
          masterPassword: master,
        ),
        throwsA(isA<AuthFailure>()),
      );
      expect(repo.profiles, isEmpty);
    });
  });

  group('changing the master password', () {
    test('re-encrypts everything under the new password', () async {
      await signedInWithVault(
        items: [
          sampleCredential(id: 'a', password: 'Zq7#mL2\$vR9!xT4w'),
          sampleCredential(
            id: 'b',
            platform: 'Slack',
            password: 'Hy5@nB8&kD3^pW6e',
          ),
        ],
      );
      final before = repo.records['a']!.data;

      await vault.changeMasterPassword(
        currentPassword: master,
        newPassword: 'amber-Falcon-ocean-77',
      );
      await settle();

      expect(repo.records['a']!.data, isNot(before));
      expect(
        vault.items.map((c) => c.password),
        unorderedEquals(['Zq7#mL2\$vR9!xT4w', 'Hy5@nB8&kD3^pW6e']),
      );

      vault.lock();
      expect(
        await vault.unlock(master),
        isFalse,
        reason: 'the old password no longer works',
      );
      expect(await vault.unlock('amber-Falcon-ocean-77'), isTrue);
      await settle();
      expect(vault.items, hasLength(2));
    });

    test('needs the correct current password', () async {
      await signedInWithVault(items: [sampleCredential(id: 'a')]);
      await expectLater(
        vault.changeMasterPassword(
          currentPassword: 'nope-nope-nope-1',
          newPassword: 'amber-Falcon-ocean-77',
        ),
        throwsA(isA<WrongMasterPassword>()),
      );
      vault.lock();
      expect(await vault.unlock(master), isTrue);
    });
  });

  group('migrating credentials from older versions', () {
    test('plaintext records are encrypted and re-owned', () async {
      repo.profiles['u1'] = UserModel(
        uid: 'u1',
        name: 'Old User',
        email: 'old@example.com',
        createdAt: DateTime(2025),
        legacyUserId: 'USER000007',
      );
      repo.legacy['USER000007'] = [
        EncryptedRecord(
          id: 'CRED000001',
          legacy: {
            'platform': 'Twitter',
            'username': 'oldhandle',
            'password': 'plaintext-password-1',
            'url': 'https://twitter.com',
            'userId': 'USER000007',
          },
          createdAt: DateTime(2025, 2, 1),
          updatedAt: DateTime(2025, 3, 1),
        ),
      ];

      await vault.attach('u1');
      expect(vault.status, VaultStatus.needsSetup);
      await vault.createVault(master);
      await settle();
      await settle();

      expect(repo.metas['u1']!.legacyMigrated, isTrue);
      final stored = repo.records['CRED000001']!;
      expect(stored.data, isNotNull);
      expect(stored.data, isNot(contains('plaintext-password-1')));
      expect(repo.owners['CRED000001'], 'u1');

      final c = vault.items.single;
      expect(c.password, 'plaintext-password-1');
      expect(c.platform, 'X (Twitter)', reason: 'Twitter was renamed to X');
      expect(c.category, CredentialCategory.social);
      expect(c.createdAt, DateTime(2025, 2, 1));
    });

    test('users without old data are not affected', () async {
      await signedInWithVault();
      expect(repo.metas['u1']!.legacyMigrated, isTrue);
    });
  });

  group('danger zone', () {
    test(
      'erasing the vault deletes the data and asks for a new master password',
      () async {
        await signedInWithVault(
          items: [
            sampleCredential(id: 'a'),
            sampleCredential(id: 'b'),
          ],
        );
        await vault.eraseVault();

        expect(repo.records, isEmpty);
        expect(repo.metas, isEmpty);
        expect(
          repo.profiles['u1'],
          isNotNull,
          reason: 'the account itself stays',
        );
        expect(vault.status, VaultStatus.needsSetup);
        expect(vault.items, isEmpty);
      },
    );

    test('deleting everything also removes the profile', () async {
      await signedInWithVault(items: [sampleCredential(id: 'a')]);
      await vault.deleteEverything();
      expect(repo.records, isEmpty);
      expect(repo.profiles, isEmpty);
    });

    test('the name can be changed', () async {
      await signedInWithVault();
      await vault.updateName('  New Name ');
      expect(vault.profile!.name, 'New Name');
      expect(repo.profiles['u1']!.name, 'New Name');
    });
  });

  group('breach scan', () {
    test('flags credentials whose passwords were breached', () async {
      final checker = FakeBreachChecker({'pwned-pass-1': 3});
      final v = newVault(repo, breach: checker);
      addTearDown(v.dispose);
      await seedVault(
        repo,
        uid: 'u1',
        master: master,
        items: [
          sampleCredential(id: 'bad', password: 'pwned-pass-1'),
          sampleCredential(id: 'good', password: 'Zq7#mL2\$vR9!xT4w'),
          sampleCredential(id: 'twin', password: 'pwned-pass-1'),
        ],
      );
      await v.attach('u1');
      await v.unlock(master);
      await settle();

      await v.checkAllBreaches();

      expect(v.breachedIds, {'bad', 'twin'});
      expect(v.breachCheckedAt, isNotNull);
      expect(v.report.breached, hasLength(2));
      expect(
        checker.asked.where((p) => p == 'pwned-pass-1'),
        hasLength(1),
        reason: 'identical passwords are only checked once',
      );
    });

    test('offline is reported as incomplete, not as "safe"', () async {
      final checker = FakeBreachChecker()..offline = true;
      final v = newVault(repo, breach: checker);
      addTearDown(v.dispose);
      await seedVault(
        repo,
        uid: 'u1',
        master: master,
        items: [sampleCredential(id: 'a')],
      );
      await v.attach('u1');
      await v.unlock(master);
      await settle();

      await v.checkAllBreaches();
      expect(v.breachCheckIncomplete, isTrue);
      expect(v.breachedIds, isEmpty);
    });

    test('changing a password clears its breach flag', () async {
      final checker = FakeBreachChecker({'pwned-pass-1': 5});
      final v = newVault(repo, breach: checker);
      addTearDown(v.dispose);
      await seedVault(
        repo,
        uid: 'u1',
        master: master,
        items: [sampleCredential(id: 'a', password: 'pwned-pass-1')],
      );
      await v.attach('u1');
      await v.unlock(master);
      await settle();
      await v.checkAllBreaches();
      expect(v.breachedIds, {'a'});

      await v.update(v.items.single.copyWith(password: 'Zq7#mL2\$vR9!xT4w'));
      expect(v.breachedIds, isEmpty);
    });

    test('is unavailable without a checker', () async {
      await signedInWithVault();
      expect(vault.canCheckBreaches, isFalse);
      await vault.checkAllBreaches(); // does nothing
      expect(vault.breachCheckedAt, isNull);
    });
  });
}
