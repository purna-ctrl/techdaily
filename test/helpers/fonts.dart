import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the real bundled fonts so widget tests measure text like the app
/// does (the default test font renders every glyph as a wide square).
Future<void> loadAppFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
    }
    await loader.load();
  }

  await load('Inter', [
    for (final w in [400, 500, 600, 700, 800]) 'assets/fonts/Inter-$w.ttf',
  ]);
  await load('SpaceGrotesk', [
    for (final w in [500, 600, 700]) 'assets/fonts/SpaceGrotesk-$w.ttf',
  ]);
}
