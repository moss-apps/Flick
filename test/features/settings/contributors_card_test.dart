import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/settings/widgets/contributors_card.dart';

void main() {
  const contributors = <FlickContributor>[
    FlickContributor('Harleythetech'),
    FlickContributor('MagosVox'),
  ];

  testWidgets('contributor portraits reveal their username on tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: ContributorsCard(contributors: contributors),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ContributorAvatar), findsNWidgets(contributors.length));

    await tester.tap(find.byType(ContributorAvatar).first);
    await tester.pump();

    expect(find.text('@Harleythetech'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Let the tooltip's show timer finish so the test does not leak a timer.
    await tester.pump(const Duration(seconds: 4));
  });
}
