import 'package:flick/features/settings/widgets/settings_info_sheet.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  testWidgets('info banner opens a sheet with the explanation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => SettingsInfoBanner(
              icon: LucideIcons.info,
              title: 'How it works',
              subtitle: 'Tap for details',
              onTap: () => showSettingsInfoSheet(
                context,
                icon: LucideIcons.info,
                title: 'Details',
                intro: 'Intro copy.',
                sections: const [
                  SettingsInfoSection(
                    heading: 'First section',
                    body: 'First body.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('How it works'));
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('First body.'), findsOneWidget);
  });
}
