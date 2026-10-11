import 'package:cred_vault/core/password/password_strength.dart';
import 'package:cred_vault/models/credential_model.dart';

enum IssueKind {
  breached('Found in a breach'),
  weak('Weak password'),
  reused('Reused password'),
  old('Old password');

  final String label;

  const IssueKind(this.label);
}

/// A health check of the whole vault.
class SecurityReport {
  final int total;
  final List<Credential> weak;
  final List<Credential> reused;
  final List<Credential> old;
  final List<Credential> breached;

  /// 0 - 100 (higher is better). An empty vault scores 100.
  final int score;

  const SecurityReport({
    required this.total,
    required this.weak,
    required this.reused,
    required this.old,
    required this.breached,
    required this.score,
  });

  static const int oldAfterDays = 180;

  static SecurityReport from(
    List<Credential> items, {
    required DateTime now,
    Set<String> breachedIds = const {},
  }) {
    final weak = <Credential>[];
    final old = <Credential>[];
    final breached = <Credential>[];

    final byPassword = <String, List<Credential>>{};
    for (final c in items) {
      if (c.password.isNotEmpty) {
        byPassword.putIfAbsent(c.password, () => []).add(c);
      }
    }
    final reusedIds = <String>{
      for (final group in byPassword.values)
        if (group.length > 1) ...group.map((c) => c.id),
    };

    var deductions = 0;
    for (final c in items) {
      var penalty = 0;
      if (breachedIds.contains(c.id)) {
        breached.add(c);
        penalty += 60;
      }
      if (PasswordStrengthEstimator.evaluate(c.password).level.isWeak) {
        weak.add(c);
        penalty += 40;
      }
      if (reusedIds.contains(c.id)) penalty += 30;
      if (now.difference(c.passwordChangedAt).inDays >= oldAfterDays) {
        old.add(c);
        penalty += 15;
      }
      deductions += penalty > 100 ? 100 : penalty;
    }

    final score = items.isEmpty
        ? 100
        : (100 - deductions / items.length).round().clamp(0, 100);

    return SecurityReport(
      total: items.length,
      weak: weak,
      reused: items.where((c) => reusedIds.contains(c.id)).toList(),
      old: old,
      breached: breached,
      score: score,
    );
  }

  int get issueCount =>
      {...weak, ...reused, ...old, ...breached}.map((c) => c.id).toSet().length;

  /// Issues affecting [c].
  List<IssueKind> issuesFor(Credential c) => [
    if (breached.any((x) => x.id == c.id)) IssueKind.breached,
    if (weak.any((x) => x.id == c.id)) IssueKind.weak,
    if (reused.any((x) => x.id == c.id)) IssueKind.reused,
    if (old.any((x) => x.id == c.id)) IssueKind.old,
  ];

  String get verdict {
    if (total == 0) return 'Add a credential to see your score';
    if (score >= 90) return 'Excellent - your vault is in great shape';
    if (score >= 70) return 'Good - a few things to tidy up';
    if (score >= 45) return 'Fair - some passwords need attention';
    return 'At risk - fix the issues below';
  }
}
