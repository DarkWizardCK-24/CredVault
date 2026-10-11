import 'package:cred_vault/models/credential_category.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// A service the user can save a login for.
class PlatformInfo {
  final String name;
  final FaIconData icon;
  final Color color;
  final CredentialCategory category;

  /// Typical website, offered as a hint when adding a login.
  final String? site;

  const PlatformInfo(
    this.name,
    this.icon,
    this.color,
    this.category, {
    this.site,
  });
}

class PlatformCatalog {
  PlatformCatalog._();

  static const String other = 'Other';

  static const List<PlatformInfo> all = [
    PlatformInfo(
      'Gmail',
      FontAwesomeIcons.google,
      Color(0xFFEA4335),
      CredentialCategory.work,
      site: 'https://mail.google.com',
    ),
    PlatformInfo(
      'Microsoft',
      FontAwesomeIcons.microsoft,
      Color(0xFF00A4EF),
      CredentialCategory.work,
      site: 'https://account.microsoft.com',
    ),
    PlatformInfo(
      'Apple',
      FontAwesomeIcons.apple,
      Color(0xFFB8B8C0),
      CredentialCategory.other,
      site: 'https://appleid.apple.com',
    ),
    PlatformInfo(
      'Slack',
      FontAwesomeIcons.slack,
      Color(0xFFE01E5A),
      CredentialCategory.work,
      site: 'https://slack.com',
    ),
    PlatformInfo(
      'Zoom',
      FontAwesomeIcons.video,
      Color(0xFF2D8CFF),
      CredentialCategory.work,
      site: 'https://zoom.us',
    ),
    PlatformInfo(
      'Dropbox',
      FontAwesomeIcons.dropbox,
      Color(0xFF0061FF),
      CredentialCategory.work,
      site: 'https://dropbox.com',
    ),
    PlatformInfo(
      'Google Drive',
      FontAwesomeIcons.googleDrive,
      Color(0xFF4285F4),
      CredentialCategory.work,
      site: 'https://drive.google.com',
    ),
    PlatformInfo(
      'LinkedIn',
      FontAwesomeIcons.linkedin,
      Color(0xFF0A66C2),
      CredentialCategory.work,
      site: 'https://linkedin.com',
    ),
    PlatformInfo(
      'GitHub',
      FontAwesomeIcons.github,
      Color(0xFFE6EDF3),
      CredentialCategory.development,
      site: 'https://github.com',
    ),
    PlatformInfo(
      'GitLab',
      FontAwesomeIcons.gitlab,
      Color(0xFFFC6D26),
      CredentialCategory.development,
      site: 'https://gitlab.com',
    ),
    PlatformInfo(
      'Instagram',
      FontAwesomeIcons.instagram,
      Color(0xFFE4405F),
      CredentialCategory.social,
      site: 'https://instagram.com',
    ),
    PlatformInfo(
      'Facebook',
      FontAwesomeIcons.facebook,
      Color(0xFF1877F2),
      CredentialCategory.social,
      site: 'https://facebook.com',
    ),
    PlatformInfo(
      'X (Twitter)',
      FontAwesomeIcons.xTwitter,
      Color(0xFFE7E9EA),
      CredentialCategory.social,
      site: 'https://x.com',
    ),
    PlatformInfo(
      'Discord',
      FontAwesomeIcons.discord,
      Color(0xFF5865F2),
      CredentialCategory.social,
      site: 'https://discord.com',
    ),
    PlatformInfo(
      'Reddit',
      FontAwesomeIcons.reddit,
      Color(0xFFFF4500),
      CredentialCategory.social,
      site: 'https://reddit.com',
    ),
    PlatformInfo(
      'Pinterest',
      FontAwesomeIcons.pinterest,
      Color(0xFFE60023),
      CredentialCategory.social,
      site: 'https://pinterest.com',
    ),
    PlatformInfo(
      'Snapchat',
      FontAwesomeIcons.snapchat,
      Color(0xFFFFFC00),
      CredentialCategory.social,
      site: 'https://snapchat.com',
    ),
    PlatformInfo(
      'TikTok',
      FontAwesomeIcons.tiktok,
      Color(0xFF25F4EE),
      CredentialCategory.social,
      site: 'https://tiktok.com',
    ),
    PlatformInfo(
      'WhatsApp',
      FontAwesomeIcons.whatsapp,
      Color(0xFF25D366),
      CredentialCategory.social,
      site: 'https://web.whatsapp.com',
    ),
    PlatformInfo(
      'Telegram',
      FontAwesomeIcons.telegram,
      Color(0xFF26A5E4),
      CredentialCategory.social,
      site: 'https://web.telegram.org',
    ),
    PlatformInfo(
      'Skype',
      FontAwesomeIcons.skype,
      Color(0xFF00AFF0),
      CredentialCategory.social,
      site: 'https://skype.com',
    ),
    PlatformInfo(
      'Linktree',
      FontAwesomeIcons.link,
      Color(0xFF43E55E),
      CredentialCategory.social,
      site: 'https://linktr.ee',
    ),
    PlatformInfo(
      'Amazon',
      FontAwesomeIcons.amazon,
      Color(0xFFFF9900),
      CredentialCategory.shopping,
      site: 'https://amazon.com',
    ),
    PlatformInfo(
      'PayPal',
      FontAwesomeIcons.paypal,
      Color(0xFF3B9BFF),
      CredentialCategory.finance,
      site: 'https://paypal.com',
    ),
    PlatformInfo(
      'Stripe',
      FontAwesomeIcons.stripe,
      Color(0xFF8E88FF),
      CredentialCategory.finance,
      site: 'https://dashboard.stripe.com',
    ),
    PlatformInfo(
      'Netflix',
      FontAwesomeIcons.film,
      Color(0xFFE50914),
      CredentialCategory.entertainment,
      site: 'https://netflix.com',
    ),
    PlatformInfo(
      'Spotify',
      FontAwesomeIcons.spotify,
      Color(0xFF1DB954),
      CredentialCategory.entertainment,
      site: 'https://open.spotify.com',
    ),
    PlatformInfo(
      'YouTube',
      FontAwesomeIcons.youtube,
      Color(0xFFFF2D2D),
      CredentialCategory.entertainment,
      site: 'https://youtube.com',
    ),
    PlatformInfo(
      'Twitch',
      FontAwesomeIcons.twitch,
      Color(0xFF9146FF),
      CredentialCategory.entertainment,
      site: 'https://twitch.tv',
    ),
    PlatformInfo(
      'Steam',
      FontAwesomeIcons.steam,
      Color(0xFF66C0F4),
      CredentialCategory.gaming,
      site: 'https://store.steampowered.com',
    ),
    PlatformInfo(
      'PlayStation',
      FontAwesomeIcons.playstation,
      Color(0xFF2D7CFF),
      CredentialCategory.gaming,
      site: 'https://playstation.com',
    ),
    PlatformInfo(
      'Xbox',
      FontAwesomeIcons.xbox,
      Color(0xFF3DB43D),
      CredentialCategory.gaming,
      site: 'https://xbox.com',
    ),
    PlatformInfo(
      other,
      FontAwesomeIcons.key,
      Color(0xFFF5B83D),
      CredentialCategory.other,
    ),
  ];

  static final Map<String, PlatformInfo> _byName = {
    for (final p in all) p.name: p,
  };

  static List<String> get names => all.map((p) => p.name).toList();

  /// Unknown names (e.g. from older versions) fall back to "Other".
  static PlatformInfo of(String name) => _byName[name] ?? _byName[other]!;

  /// Older versions saved "Twitter" before the rename to X.
  static String normalise(String name) =>
      name == 'Twitter' ? 'X (Twitter)' : name;
}
