import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// `flutter test` draws every glyph as a wide box unless fonts are loaded,
/// which makes layouts overflow that are fine on a device. Load the app's
/// fonts, the Material icons and the Font Awesome brand icons so tests (and
/// screenshots) look like the real thing.
Future<void> loadAppFonts() async {
  ByteData bytes(String path) =>
      ByteData.sublistView(File(path).readAsBytesSync());

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(bytes(f)));
    }
    await loader.load();
  }

  await load('BeVietnamPro', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/BeVietnamPro-$w.ttf',
  ]);
  await load('IBMPlexMono', [
    'assets/fonts/IBMPlexMono-Regular.ttf',
    'assets/fonts/IBMPlexMono-Medium.ttf',
  ]);

  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? 'C:/src/flutter';
  await load('MaterialIcons', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);

  // Font Awesome ships its fonts inside the package; find it via the package
  // config so this works wherever the pub cache lives.
  final config =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map<String, dynamic>;
  final pkg = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((p) => p['name'] == 'font_awesome_flutter');
  final root = Uri.parse(pkg['rootUri'] as String);
  var dir = root.isAbsolute
      ? root.toFilePath()
      : Directory('.dart_tool').uri.resolve(root.toString()).toFilePath();
  if (!dir.endsWith('/') && !dir.endsWith(r'\')) dir = '$dir/';
  const prefix = 'packages/font_awesome_flutter/';
  await load('${prefix}FontAwesomeBrands', [
    '${dir}lib/fonts/Font-Awesome-7-Brands-Regular-400.otf',
  ]);
  await load('${prefix}FontAwesomeSolid', [
    '${dir}lib/fonts/Font-Awesome-7-Free-Solid-900.otf',
  ]);
  await load('${prefix}FontAwesomeRegular', [
    '${dir}lib/fonts/Font-Awesome-7-Free-Regular-400.otf',
  ]);
}
