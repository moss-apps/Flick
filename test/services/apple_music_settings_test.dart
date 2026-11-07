import 'package:flick/services/apple_music/apple_music_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('page information defaults on and persists independently', () async {
    final settings = AppleMusicSettings();

    expect(await settings.pageInfoEnabled(), isTrue);
    expect(await settings.autoEnrichEnabled(), isFalse);

    await settings.setPageInfoEnabled(false);
    expect(await settings.pageInfoEnabled(), isFalse);
    expect(await settings.autoEnrichEnabled(), isFalse);

    await settings.setAutoEnrichEnabled(true);
    expect(await settings.pageInfoEnabled(), isFalse);
    expect(await settings.autoEnrichEnabled(), isTrue);
  });
}
