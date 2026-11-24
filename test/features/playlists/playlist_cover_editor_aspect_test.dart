import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/playlists/screens/playlist_cover_editor_screen.dart';
import 'package:flick/features/playlists/utils/playlist_cover_edit.dart';
import 'package:flick/l10n/l10n.dart';

Widget _host(String sourcePath, Widget editor) => MaterialApp(
  theme: AppTheme.darkTheme,
  locale: kFallbackLocale,
  supportedLocales: kSupportedLocales,
  localizationsDelegates: kAppLocalizationsDelegates,
  localeResolutionCallback: resolveAppLocale,
  builder: (context, child) {
    LocaleController.instance.bind(AppLocalizations.of(context));
    return child!;
  },
  home: editor,
);

Future<void> _waitForText(WidgetTester tester, String text) async {
  for (var i = 0; i < 50; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (find.text(text).evaluate().isNotEmpty) {
      return;
    }
  }
  fail('the cover editor did not finish preparing: $text');
}

void main() {
  late Directory temporaryDirectory;
  late String sourcePath;
  final en = lookupFlickLocalizations(kFallbackLocale);

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'flick_cover_editor_aspect_',
    );
    final image = img.Image(width: 16, height: 16);
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        image.setPixelRgb(x, y, x * 10, y * 10, 80);
      }
    }
    sourcePath = '${temporaryDirectory.path}/cover.png';
    File(sourcePath).writeAsBytesSync(img.encodePng(image));
  });

  tearDown(() {
    LocaleController.instance.bindLocale(kFallbackLocale);
    if (temporaryDirectory.existsSync()) {
      temporaryDirectory.deleteSync(recursive: true);
    }
  });

  testWidgets('4:5 editor uses a portrait viewport and restores the crop', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _host(
        sourcePath,
        PlaylistCoverEditorScreen(
          sourcePath: sourcePath,
          aspectRatio: 4 / 5,
          initialEdit: const PlaylistCoverEdit(quarterTurns: 1),
          initialCrop: const Rect.fromLTWH(0, 0, 8, 10),
        ),
      ),
    );
    await _waitForText(tester, en.crop);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(InteractiveViewer).evaluate().isNotEmpty) break;
    }

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final viewport = tester.getSize(find.byType(InteractiveViewer));
    expect(viewport.width / viewport.height, closeTo(4 / 5, 0.001));

    final transform = viewer.transformationController!.value;
    expect(transform.getMaxScaleOnAxis(), closeTo(1.6, 0.001));
    expect(transform.getTranslation().x, closeTo(0, 0.001));
    expect(transform.getTranslation().y, closeTo(0, 0.001));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
