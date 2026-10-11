import 'dart:async';

import 'package:cred_vault/services/settings_service.dart';
import 'package:flutter/services.dart';

/// Copies secrets to the clipboard and wipes them again after a while, so a
/// copied password doesn't linger where other apps could read it.
class ClipboardService {
  ClipboardService(this._settings);

  final SettingsService _settings;
  Timer? _timer;
  String? _lastCopied;

  /// Copies [text]. Secrets (the default) are cleared after the delay chosen
  /// in settings, but only if the clipboard still holds what we put there.
  Future<void> copy(String text, {bool secret = true}) async {
    _timer?.cancel();
    _lastCopied = null;
    await Clipboard.setData(ClipboardData(text: text));
    final delay = _settings.clipboardClear.delay;
    if (!secret || delay == null) return;
    _lastCopied = text;
    _timer = Timer(delay, clearNow);
  }

  /// Clears the clipboard now if it still contains the last secret we copied.
  Future<void> clearNow() async {
    _timer?.cancel();
    final copied = _lastCopied;
    _lastCopied = null;
    if (copied == null) return;
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    if (current?.text == copied) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  }

  void dispose() => _timer?.cancel();
}
