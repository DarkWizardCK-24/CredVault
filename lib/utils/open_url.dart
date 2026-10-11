import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Adds `https://` when a saved address has no scheme.
Uri? normaliseUrl(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  if (uri == null || uri.host.isEmpty) return null;
  // Only web addresses are opened from the vault.
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return uri;
}

/// Opens [raw] in the browser. Returns `false` if it could not be opened.
Future<bool> openUrl(String raw) async {
  final uri = normaliseUrl(raw);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Could not open $uri: $e');
    return false;
  }
}
