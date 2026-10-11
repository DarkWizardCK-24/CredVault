import 'package:flutter/material.dart';

/// How a credential is grouped in the vault.
enum CredentialCategory {
  social('Social', Icons.forum_rounded, Color(0xFFFF7AA8)),
  work('Work', Icons.work_rounded, Color(0xFF6FA8FF)),
  finance('Finance', Icons.account_balance_wallet_rounded, Color(0xFF3DDC97)),
  shopping('Shopping', Icons.shopping_bag_rounded, Color(0xFFFFB454)),
  entertainment('Entertainment', Icons.movie_rounded, Color(0xFFB794FF)),
  gaming('Gaming', Icons.sports_esports_rounded, Color(0xFF5EE0E0)),
  development('Development', Icons.code_rounded, Color(0xFFFFD86B)),
  other('Other', Icons.vpn_key_rounded, Color(0xFF9BA8C9));

  final String label;
  final IconData icon;
  final Color color;

  const CredentialCategory(this.label, this.icon, this.color);

  static CredentialCategory fromName(String? name) =>
      CredentialCategory.values.firstWhere(
        (c) => c.name == name,
        orElse: () => CredentialCategory.other,
      );
}
