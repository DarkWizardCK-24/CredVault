import 'dart:convert';
import 'dart:math';

import 'package:cred_vault/core/crypto/vault_crypto.dart';
import 'package:cred_vault/core/password/breach_checker.dart';
import 'package:cred_vault/core/password/password_generator.dart';
import 'package:cred_vault/core/password/password_strength.dart';
import 'package:cred_vault/core/security_report.dart';
import 'package:cred_vault/core/validators.dart';
import 'package:cred_vault/models/credential_category.dart';
import 'package:cred_vault/models/credential_model.dart';
import 'package:cred_vault/providers/credential_provider.dart';
import 'package:cred_vault/utils/open_url.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fakes.dart';

void main() {
  group('VaultCrypto', () {
    final kdf = KdfParams(salt: List.filled(16, 7), iterations: 1000);

    test('round-trips text of any kind', () async {
      final key = await fastCrypto.deriveKey('correct horse battery', kdf);
      for (final text in ['', 'a', 'p@ss w0rd!', 'Ünïcødé 🔐 密码', 'x' * 5000]) {
        final sealed = await fastCrypto.encrypt(key, text);
        expect(await fastCrypto.decrypt(key, sealed), text);
      }
    });

    test('never stores the plaintext and never reuses a nonce', () async {
      final key = await fastCrypto.deriveKey('pw', kdf);
      final a = await fastCrypto.encrypt(key, 'hunter2-secret');
      final b = await fastCrypto.encrypt(key, 'hunter2-secret');
      expect(a, isNot(contains('hunter2')));
      expect(
        utf8.decode(base64Decode(a), allowMalformed: true),
        isNot(contains('hunter2')),
      );
      expect(a, isNot(b), reason: 'a fresh random nonce is used every time');
    });

    test('the wrong key cannot decrypt', () async {
      final right = await fastCrypto.deriveKey('right password', kdf);
      final wrong = await fastCrypto.deriveKey('wrong password', kdf);
      final sealed = await fastCrypto.encrypt(right, 'secret');
      expect(
        () => fastCrypto.decrypt(wrong, sealed),
        throwsA(isA<VaultDecryptException>()),
      );
    });

    test('tampering is detected', () async {
      final key = await fastCrypto.deriveKey('pw', kdf);
      final bytes = base64Decode(await fastCrypto.encrypt(key, 'secret data'));
      bytes[bytes.length ~/ 2] ^= 0x01; // flip one bit
      expect(
        () => fastCrypto.decrypt(key, base64Encode(bytes)),
        throwsA(isA<VaultDecryptException>()),
      );
      expect(
        () => fastCrypto.decrypt(key, 'not base64 !!'),
        throwsA(isA<VaultDecryptException>()),
      );
      expect(
        () => fastCrypto.decrypt(key, base64Encode([1, 2, 3])),
        throwsA(isA<VaultDecryptException>()),
      );
    });

    test('key derivation depends on password, salt and iterations', () async {
      Future<List<int>> derive(String pw, KdfParams p) async =>
          (await fastCrypto.deriveKey(pw, p)).extractBytes();

      final base = await derive('pw', kdf);
      expect(base.length, 32);
      expect(await derive('pw', kdf), base, reason: 'deterministic');
      expect(await derive('PW', kdf), isNot(base));
      expect(
        await derive(
          'pw',
          KdfParams(salt: List.filled(16, 8), iterations: 1000),
        ),
        isNot(base),
      );
      expect(
        await derive(
          'pw',
          KdfParams(salt: List.filled(16, 7), iterations: 1001),
        ),
        isNot(base),
      );
    });

    test('the verifier accepts only the right master password', () async {
      final right = await fastCrypto.deriveKey('open sesame', kdf);
      final verifier = await fastCrypto.makeVerifier(right);
      expect(await fastCrypto.checkVerifier(right, verifier), isTrue);
      final wrong = await fastCrypto.deriveKey('open sesame!', kdf);
      expect(await fastCrypto.checkVerifier(wrong, verifier), isFalse);
    });

    test('new salts are random and the right size', () {
      final a = fastCrypto.newKdfParams();
      final b = fastCrypto.newKdfParams();
      expect(a.salt.length, VaultCrypto.saltLength);
      expect(a.salt, isNot(b.salt));
      expect(VaultCrypto.defaultIterations, greaterThanOrEqualTo(200000));
    });
  });

  group('PasswordGenerator', () {
    final generator = PasswordGenerator(random: Random(42));

    test('makes passwords of the requested length', () {
      for (final length in [8, 16, 20, 64]) {
        expect(
          generator.generate(GeneratorOptions(length: length)).length,
          length,
        );
      }
    });

    test('keeps the length inside the allowed range', () {
      expect(generator.generate(const GeneratorOptions(length: 2)).length, 8);
      expect(
        generator.generate(const GeneratorOptions(length: 500)).length,
        64,
      );
    });

    test('always includes every selected kind of character', () {
      for (var i = 0; i < 200; i++) {
        final p = generator.generate(const GeneratorOptions(length: 8));
        expect(p, matches(RegExp(r'[a-z]')));
        expect(p, matches(RegExp(r'[A-Z]')));
        expect(p, matches(RegExp(r'[0-9]')));
        expect(p, matches(RegExp(r'[^A-Za-z0-9]')));
      }
    });

    test('respects the selected classes', () {
      final digitsOnly = generator.generate(
        const GeneratorOptions(
          lowercase: false,
          uppercase: false,
          symbols: false,
        ),
      );
      expect(digitsOnly, matches(RegExp(r'^[0-9]+$')));

      final noSymbols = generator.generate(
        const GeneratorOptions(symbols: false),
      );
      expect(noSymbols, matches(RegExp(r'^[A-Za-z0-9]+$')));
    });

    test('can avoid look-alike characters', () {
      for (var i = 0; i < 100; i++) {
        final p = generator.generate(
          const GeneratorOptions(length: 40, avoidAmbiguous: true),
        );
        expect(p, isNot(matches(RegExp(r'[O0oIl1|]'))));
      }
    });

    test('refuses to run with nothing selected', () {
      expect(
        () => generator.generate(
          const GeneratorOptions(
            lowercase: false,
            uppercase: false,
            digits: false,
            symbols: false,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('a secure generator produces different passwords', () {
      final secure = PasswordGenerator();
      final seen = {
        for (var i = 0; i < 50; i++) secure.generate(const GeneratorOptions()),
      };
      expect(seen.length, 50);
    });
  });

  group('PasswordStrengthEstimator', () {
    StrengthLevel level(String p) =>
        PasswordStrengthEstimator.evaluate(p).level;

    test('empty and trivial passwords are very weak', () {
      expect(level(''), StrengthLevel.veryWeak);
      expect(level('abc'), StrengthLevel.veryWeak);
      expect(level('123456'), StrengthLevel.veryWeak);
      expect(level('password'), StrengthLevel.veryWeak);
      expect(level('aaaaaaaaaaaa'), StrengthLevel.veryWeak);
    });

    test('common words are not rescued by a few extra characters', () {
      expect(level('Password123!').isWeak, isTrue);
      expect(level('qwerty2024').isWeak, isTrue);
    });

    test('sequences are penalised', () {
      final plain = PasswordStrengthEstimator.evaluate('xk9Qm2Lp7Rt4').bits;
      final sequence = PasswordStrengthEstimator.evaluate('abcd1234WXyz').bits;
      expect(sequence, lessThan(plain));
    });

    test('longer and more varied is stronger', () {
      final short = PasswordStrengthEstimator.evaluate('Xk9!mQ2').bits;
      final long = PasswordStrengthEstimator.evaluate('Xk9!mQ2#vR7\$tL4@').bits;
      expect(long, greaterThan(short));
      expect(level('correct-Horse-battery-9-staple!'), StrengthLevel.excellent);
    });

    test('generated passwords are strong', () {
      final g = PasswordGenerator();
      for (var i = 0; i < 30; i++) {
        expect(
          level(g.generate(const GeneratorOptions())).score,
          greaterThanOrEqualTo(3),
        );
      }
    });

    test('gives hints for weak passwords and a readable crack time', () {
      final weak = PasswordStrengthEstimator.evaluate('abc123');
      expect(weak.hints, isNotEmpty);
      expect(weak.crackTime, 'instantly');

      final strong = PasswordStrengthEstimator.evaluate(
        'correct-Horse-battery-9-staple!',
      );
      expect(strong.hints, isEmpty);
      expect(strong.crackTime, contains('years'));
    });
  });

  group('SecurityReport', () {
    final now = DateTime(2026, 10, 13);
    Credential cred(String id, String password, {DateTime? changed}) =>
        sampleCredential(
          id: id,
          password: password,
          passwordChangedAt: changed ?? now.subtract(const Duration(days: 10)),
        );

    test('an empty vault is a clean 100', () {
      final r = SecurityReport.from(const [], now: now);
      expect(r.score, 100);
      expect(r.issueCount, 0);
      expect(r.verdict, contains('Add a credential'));
    });

    test('finds weak, reused, old and breached passwords', () {
      const strong1 = 'Zq7#mL2\$vR9!xT4w';
      const strong2 = 'Hy5@nB8&kD3^pW6e';
      final items = [
        cred('weak', 'password1'),
        cred('a', strong1),
        cred('b', strong1), // reused
        cred('old', strong2, changed: now.subtract(const Duration(days: 400))),
        cred('pwned', 'Fj2*uC9\$sM5!gQ7z'),
      ];
      final r = SecurityReport.from(items, now: now, breachedIds: {'pwned'});

      expect(r.weak.map((c) => c.id), ['weak']);
      expect(r.reused.map((c) => c.id), unorderedEquals(['a', 'b']));
      expect(r.old.map((c) => c.id), ['old']);
      expect(r.breached.map((c) => c.id), ['pwned']);
      expect(r.issueCount, 5);
      expect(r.issuesFor(items[0]), [IssueKind.weak]);
      expect(r.score, 65); // (40 + 30 + 30 + 15 + 60) / 5 = 35 points lost
    });

    test('a healthy vault scores high', () {
      final g = PasswordGenerator();
      final items = [
        for (var i = 0; i < 5; i++)
          cred('c$i', g.generate(const GeneratorOptions())),
      ];
      final r = SecurityReport.from(items, now: now);
      expect(r.score, 100);
      expect(r.verdict, startsWith('Excellent'));
    });

    test('the score falls as problems pile up', () {
      final one = SecurityReport.from([cred('a', 'password1')], now: now).score;
      final both = SecurityReport.from([
        cred('a', 'password1'),
        cred('b', 'password1'),
      ], now: now).score;
      expect(one, lessThan(100));
      expect(both, lessThanOrEqualTo(one));
      expect(
        SecurityReport.from(
          [cred('a', 'password1')],
          now: now,
          breachedIds: {'a'},
        ).score,
        0,
      );
    });
  });

  group('HibpBreachChecker', () {
    test('sends only a 5 character prefix and finds the match', () async {
      late Uri requested;
      final client = MockClient((request) async {
        requested = request.url;
        // SHA-1("password") = 5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8
        return http.Response(
          '0018A45C4D1DEF81644B54AB7F969B88D65:3\r\n'
          '1E4C9B93F3F0682250B6CF8331B7EE68FD8:3861493\r\n'
          '011053FD0102E94D6AE2F8B83D76FAF94F6:1',
          200,
        );
      });
      final checker = HibpBreachChecker(client: client);

      expect(await checker.pwnedCount('password'), 3861493);
      expect(requested.path, endsWith('/range/5BAA6'));
      expect(requested.toString(), isNot(contains('5BAA61E4C9B93F3F')));
    });

    test('returns 0 when the hash is not in the list', () async {
      final client = MockClient((_) async => http.Response('ABCDE:5', 200));
      expect(
        await HibpBreachChecker(client: client).pwnedCount('unique-pass-xyz'),
        0,
      );
    });

    test('returns null when the check cannot be completed', () async {
      final failing = MockClient((_) async => http.Response('nope', 503));
      expect(await HibpBreachChecker(client: failing).pwnedCount('x'), isNull);

      final offline = MockClient(
        (_) async => throw http.ClientException('offline'),
      );
      expect(await HibpBreachChecker(client: offline).pwnedCount('x'), isNull);
    });

    test('hashes with SHA-1 in upper case', () async {
      expect(
        await HibpBreachChecker.sha1Hex('password'),
        '5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8',
      );
    });
  });

  group('Credential', () {
    test('survives an encrypt-ready payload round trip', () {
      final original = sampleCredential(
        id: 'x1',
        title: 'Work mail',
        notes: 'line 1\nline 2 "quoted"',
        url: 'https://mail.example.com',
        favorite: true,
        category: CredentialCategory.work,
        password: 'p\$w"d\\',
      );
      final restored = Credential.fromPayload(
        'x1',
        original.toPayload(),
        createdAt: original.createdAt,
        updatedAt: original.updatedAt,
      );
      expect(restored.title, 'Work mail');
      expect(restored.notes, original.notes);
      expect(restored.password, original.password);
      expect(restored.favorite, isTrue);
      expect(restored.category, CredentialCategory.work);
      expect(restored.passwordChangedAt, original.passwordChangedAt);
    });

    test('display name falls back to the platform', () {
      expect(sampleCredential(platform: 'GitHub').displayName, 'GitHub');
      expect(
        sampleCredential(platform: 'Other', title: ' Router ').displayName,
        'Router',
      );
    });

    test('tolerates missing fields', () {
      final c = Credential.fromPayload(
        'id',
        '{}',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026, 2),
      );
      expect(c.platform, 'Other');
      expect(c.username, '');
      expect(c.category, CredentialCategory.other);
      expect(c.passwordChangedAt, DateTime(2026, 2));
    });
  });

  group('CredentialProvider (search, filter, sort)', () {
    final items = [
      sampleCredential(
        id: '1',
        platform: 'GitHub',
        username: 'dev@work.com',
        password: 'abc123',
        updatedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2025, 1, 1),
      ),
      sampleCredential(
        id: '2',
        platform: 'Netflix',
        username: 'family@home.com',
        favorite: true,
        category: CredentialCategory.entertainment,
        password: 'Zq7#mL2\$vR9!xT4w',
        updatedAt: DateTime(2026, 3, 1),
        createdAt: DateTime(2025, 6, 1),
      ),
      sampleCredential(
        id: '3',
        platform: 'Gmail',
        username: 'me@gmail.com',
        notes: 'recovery phone 555',
        category: CredentialCategory.work,
        password: 'Hy5@nB8&kD3^pW6e',
        updatedAt: DateTime(2026, 2, 1),
        createdAt: DateTime(2025, 3, 1),
      ),
    ];

    List<String> ids(CredentialProvider p) =>
        p.apply(items).map((c) => c.id).toList();

    test('searches name, username and notes', () {
      final p = CredentialProvider();
      p.setQuery('netflix');
      expect(ids(p), ['2']);
      p.setQuery('GMAIL.COM');
      expect(ids(p), ['3']);
      p.setQuery('recovery');
      expect(ids(p), ['3']);
      p.setQuery('zzz');
      expect(ids(p), isEmpty);
    });

    test('filters by category and favourites', () {
      final p = CredentialProvider()..setCategory(CredentialCategory.work);
      expect(ids(p), ['3']);
      p.setFavoritesOnly(true);
      expect(
        p.category,
        isNull,
        reason: 'favourites replaces the category filter',
      );
      expect(ids(p), ['2']);
      p.clearFilters();
      expect(ids(p).length, 3);
      expect(p.isFiltering, isFalse);
    });

    test('sorts, with favourites first by recency and name', () {
      final p = CredentialProvider();
      expect(ids(p), [
        '2',
        '3',
        '1',
      ], reason: 'favourite first, then newest edit');
      p.setSort(CredentialSort.name);
      expect(ids(p), ['2', '1', '3'], reason: 'favourite, then GitHub, Gmail');
      p.setSort(CredentialSort.oldest);
      expect(ids(p), ['1', '3', '2']);
      p.setSort(CredentialSort.weakest);
      expect(ids(p).first, '1');
    });

    test('counts items per category', () {
      final counts = CredentialProvider.countByCategory(items);
      expect(counts[CredentialCategory.work], 1);
      expect(counts[CredentialCategory.entertainment], 1);
      expect(counts[CredentialCategory.development], 1);
    });
  });

  group('Validators and URLs', () {
    test('email', () {
      expect(Validators.email('a@b.co'), isNull);
      expect(Validators.email(' a@b.co '), isNull);
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('master password must be long and not weak', () {
      expect(Validators.masterPassword(''), isNotNull);
      expect(Validators.masterPassword('short1!'), contains('10'));
      expect(Validators.masterPassword('password123'), contains('easy'));
      expect(Validators.masterPassword('purple-Lantern-river-42'), isNull);
    });

    test('url is optional but must look like an address', () {
      expect(Validators.url(''), isNull);
      expect(Validators.url('github.com'), isNull);
      expect(Validators.url('https://github.com/login'), isNull);
      expect(Validators.url('not a url'), isNotNull);
    });

    test('only web addresses are opened', () {
      expect(normaliseUrl('github.com')?.toString(), 'https://github.com');
      expect(normaliseUrl('http://example.com/x')?.scheme, 'http');
      expect(normaliseUrl('javascript:alert(1)'), isNull);
      expect(normaliseUrl('file:///etc/passwd'), isNull);
      expect(normaliseUrl(''), isNull);
    });
  });
}
