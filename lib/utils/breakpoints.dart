import 'package:flutter/widgets.dart';

/// Screen-width rules shared by the layouts. Phones (and narrow browser
/// windows) keep the mobile layout; only wider windows get the desktop one.
class Breakpoints {
  Breakpoints._();

  /// At or above this width the app switches to its desktop layout.
  static const double wide = 840;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;
}
