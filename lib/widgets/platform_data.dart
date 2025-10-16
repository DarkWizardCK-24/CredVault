import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PlatformData {
  final String name;
  final IconData icon;
  final Color color;

  PlatformData({
    required this.name,
    required this.icon,
    required this.color,
  });
}

class PlatformHelper {
  static final Map<String, PlatformData> platforms = {
    'Instagram': PlatformData(
      name: 'Instagram',
      icon: FontAwesomeIcons.instagram,
      color: const Color(0xFFE4405F),
    ),
    'LinkedIn': PlatformData(
      name: 'LinkedIn',
      icon: FontAwesomeIcons.linkedin,
      color: const Color(0xFF0A66C2),
    ),
    'GitHub': PlatformData(
      name: 'GitHub',
      icon: FontAwesomeIcons.github,
      color: const Color(0xFF181717),
    ),
    'Gmail': PlatformData(
      name: 'Gmail',
      icon: FontAwesomeIcons.google,
      color: const Color(0xFFEA4335),
    ),
    'Linktree': PlatformData(
      name: 'Linktree',
      icon: FontAwesomeIcons.link,
      color: const Color(0xFF43E55E),
    ),
    'Facebook': PlatformData(
      name: 'Facebook',
      icon: FontAwesomeIcons.facebook,
      color: const Color(0xFF1877F2),
    ),
    'Twitter': PlatformData(
      name: 'Twitter',
      icon: FontAwesomeIcons.twitter,
      color: const Color(0xFF1DA1F2),
    ),
    'Discord': PlatformData(
      name: 'Discord',
      icon: FontAwesomeIcons.discord,
      color: const Color(0xFF5865F2),
    ),
    'Spotify': PlatformData(
      name: 'Spotify',
      icon: FontAwesomeIcons.spotify,
      color: const Color(0xFF1DB954),
    ),
    'Netflix': PlatformData(
      name: 'Netflix',
      icon: FontAwesomeIcons.film,
      color: const Color(0xFFE50914),
    ),
    'Amazon': PlatformData(
      name: 'Amazon',
      icon: FontAwesomeIcons.amazon,
      color: const Color(0xFFFF9900),
    ),
    'YouTube': PlatformData(
      name: 'YouTube',
      icon: FontAwesomeIcons.youtube,
      color: const Color(0xFFFF0000),
    ),
    'TikTok': PlatformData(
      name: 'TikTok',
      icon: FontAwesomeIcons.tiktok,
      color: const Color(0xFF000000),
    ),
    'Snapchat': PlatformData(
      name: 'Snapchat',
      icon: FontAwesomeIcons.snapchat,
      color: const Color(0xFFFFFC00),
    ),
    'Reddit': PlatformData(
      name: 'Reddit',
      icon: FontAwesomeIcons.reddit,
      color: const Color(0xFFFF4500),
    ),
    'Pinterest': PlatformData(
      name: 'Pinterest',
      icon: FontAwesomeIcons.pinterest,
      color: const Color(0xFFE60023),
    ),
    'WhatsApp': PlatformData(
      name: 'WhatsApp',
      icon: FontAwesomeIcons.whatsapp,
      color: const Color(0xFF25D366),
    ),
    'Telegram': PlatformData(
      name: 'Telegram',
      icon: FontAwesomeIcons.telegram,
      color: const Color(0xFF26A5E4),
    ),
    'Slack': PlatformData(
      name: 'Slack',
      icon: FontAwesomeIcons.slack,
      color: const Color(0xFF4A154B),
    ),
    'Zoom': PlatformData(
      name: 'Zoom',
      icon: FontAwesomeIcons.video,
      color: const Color(0xFF2D8CFF),
    ),
    'Dropbox': PlatformData(
      name: 'Dropbox',
      icon: FontAwesomeIcons.dropbox,
      color: const Color(0xFF0061FF),
    ),
    'Google Drive': PlatformData(
      name: 'Google Drive',
      icon: FontAwesomeIcons.googleDrive,
      color: const Color(0xFF4285F4),
    ),
    'Microsoft': PlatformData(
      name: 'Microsoft',
      icon: FontAwesomeIcons.microsoft,
      color: const Color(0xFF00A4EF),
    ),
    'Apple': PlatformData(
      name: 'Apple',
      icon: FontAwesomeIcons.apple,
      color: const Color(0xFF000000),
    ),
    'PayPal': PlatformData(
      name: 'PayPal',
      icon: FontAwesomeIcons.paypal,
      color: const Color(0xFF00457C),
    ),
    'Stripe': PlatformData(
      name: 'Stripe',
      icon: FontAwesomeIcons.stripe,
      color: const Color(0xFF635BFF),
    ),
    'Steam': PlatformData(
      name: 'Steam',
      icon: FontAwesomeIcons.steam,
      color: const Color(0xFF000000),
    ),
    'PlayStation': PlatformData(
      name: 'PlayStation',
      icon: FontAwesomeIcons.playstation,
      color: const Color(0xFF003791),
    ),
    'Xbox': PlatformData(
      name: 'Xbox',
      icon: FontAwesomeIcons.xbox,
      color: const Color(0xFF107C10),
    ),
    'Twitch': PlatformData(
      name: 'Twitch',
      icon: FontAwesomeIcons.twitch,
      color: const Color(0xFF9146FF),
    ),
    'GitLab': PlatformData(
      name: 'GitLab',
      icon: FontAwesomeIcons.gitlab,
      color: const Color(0xFFFC6D26),
    ),
    'Skype': PlatformData(
      name: 'Skype',
      icon: FontAwesomeIcons.skype,
      color: const Color(0xFF00AFF0),
    ),
    'Other': PlatformData(
      name: 'Other',
      icon: FontAwesomeIcons.lock,
      color: const Color(0xFF6C63FF),
    ),
  };

  static List<String> getPlatformNames() {
    return platforms.keys.toList();
  }

  static PlatformData getPlatformData(String platformName) {
    return platforms[platformName] ?? platforms['Other']!;
  }

  static IconData getIcon(String platformName) {
    return platforms[platformName]?.icon ?? FontAwesomeIcons.lock;
  }

  static Color getColor(String platformName) {
    return platforms[platformName]?.color ?? const Color(0xFF6C63FF);
  }
}