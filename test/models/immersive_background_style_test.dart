import 'package:flutter_test/flutter_test.dart';

import 'package:flick/models/immersive_background_style.dart';

void main() {
  test('storage values round-trip', () {
    for (final style in ImmersiveBackgroundStyle.values) {
      expect(
        ImmersiveBackgroundStyleX.fromStorageValue(style.storageValue),
        style,
      );
    }
  });

  test('unknown or missing values fall back to the color gradient', () {
    expect(
      ImmersiveBackgroundStyleX.fromStorageValue(null),
      ImmersiveBackgroundStyle.colorGradient,
    );
    expect(
      ImmersiveBackgroundStyleX.fromStorageValue('unknown'),
      ImmersiveBackgroundStyle.colorGradient,
    );
  });
}
