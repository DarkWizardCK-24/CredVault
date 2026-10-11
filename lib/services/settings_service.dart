import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How long the app may sit in the background before the vault locks itself.
enum AutoLockDelay {
  immediately('Immediately', Duration.zero),
  oneMinute('After 1 minute', Duration(minutes: 1)),
  fiveMinutes('After 5 minutes', Duration(minutes: 5)),
  fifteenMinutes('After 15 minutes', Duration(minutes: 15));

  final String label;
  final Duration delay;

  const AutoLockDelay(this.label, this.delay);

  static AutoLockDelay fromName(String? name) => AutoLockDelay.values
      .firstWhere((d) => d.name == name, orElse: () => AutoLockDelay.oneMinute);
}

/// How long a copied password stays on the clipboard.
enum ClipboardClear {
  fifteen('After 15 seconds', Duration(seconds: 15)),
  thirty('After 30 seconds', Duration(seconds: 30)),
  sixty('After 1 minute', Duration(seconds: 60)),
  never('Never', null);

  final String label;
  final Duration? delay;

  const ClipboardClear(this.label, this.delay);

  static ClipboardClear fromName(String? name) => ClipboardClear.values
      .firstWhere((d) => d.name == name, orElse: () => ClipboardClear.thirty);
}

/// App preferences stored on the device.
class SettingsService extends ChangeNotifier {
  AutoLockDelay _autoLock = AutoLockDelay.oneMinute;
  ClipboardClear _clipboardClear = ClipboardClear.thirty;
  bool _loaded = false;

  static const _autoLockKey = 'settings.autoLock';
  static const _clipboardKey = 'settings.clipboardClear';

  AutoLockDelay get autoLock => _autoLock;
  ClipboardClear get clipboardClear => _clipboardClear;
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoLock = AutoLockDelay.fromName(prefs.getString(_autoLockKey));
      _clipboardClear = ClipboardClear.fromName(prefs.getString(_clipboardKey));
    } catch (e) {
      debugPrint('Could not load settings: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setAutoLock(AutoLockDelay value) async {
    _autoLock = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_autoLockKey, value.name);
  }

  Future<void> setClipboardClear(ClipboardClear value) async {
    _clipboardClear = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clipboardKey, value.name);
  }
}
