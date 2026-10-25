// Localization entry point for Flick.
//
// Two accessors are provided, on purpose:
//
//   * `l10n.<key>`     -- a global accessor, usable anywhere, including the
//                         service layer. A large share of this app's
//                         user-visible strings live in services that have no
//                         BuildContext (player_service.dart alone holds ~170),
//                         so a context-only API would not be practical.
//   * `context.l10n`   -- the idiomatic widget-layer accessor.
//
// The global is kept in sync by [LocaleController.bind], which is called from
// MaterialApp.builder on every build, and once from main() before the first
// frame so that strings produced during startup already use the right locale.

import 'package:flutter/widgets.dart';

import 'package:flick/l10n/generated/app_localizations.dart';
import 'package:flick/services/app_preferences_service.dart';

export 'package:flick/l10n/generated/app_localizations.dart';

// 模型层的展示扩展（label / description / menuLabel …）。
//
// 它们放在 lib/l10n/ 而不是 lib/models/，是为了让模型保持与语言无关 —— 上游
// review 明确要求 models 不得依赖 l10n（会破坏分层与可测试性）。这里 re-export，
// 调用方只要 import 本文件就能拿到，无需额外 import。
export 'package:flick/l10n/model_labels.dart';

/// Filipino uses the Tagalog locale supported by Flutter's built-in controls.
/// `fil` device/stored tags are accepted as aliases below.
const Locale kFilipinoLocale = Locale('tl');

/// Resource-only locale for curated opt-in Baybayin labels, never the UI
/// locale. Also retained to recognize preferences from the earlier pilot.
const Locale kBaybayinLocale = Locale.fromSubtags(
  languageCode: 'tl',
  scriptCode: 'Tglg',
);

/// Locales the app ships translations for. Script preference is independent.
///
/// English is listed first so that a device locale we do not translate falls
/// back to English rather than to Chinese. Chinese devices still resolve to
/// `zh` through the language-code match below.
const List<Locale> kSupportedLocales = <Locale>[
  Locale('en'),
  Locale('zh', 'CN'),
  kFilipinoLocale,
];

/// Used when nothing else matches.
const Locale kFallbackLocale = Locale('en');

const kAppLocalizationsDelegates = AppLocalizations.localizationsDelegates;

AppLocalizations lookupFlickLocalizations(Locale requested) =>
    lookupAppLocalizations(resolveSupportedLocale(requested));

/// The current localizations. Initialized to English so that reads before the
/// first frame cannot throw.
AppLocalizations _current = lookupAppLocalizations(kFallbackLocale);

/// Global accessor. Prefer `context.l10n` inside widgets.
AppLocalizations get l10n => _current;

final _englishCopy = lookupAppLocalizations(kFallbackLocale);

/// Explicit copy roles: Filipino titles/menu/support can be English without
/// changing descriptions, search, global service messages or the UI locale.
extension FilipinoCopyRoles on AppLocalizations {
  bool get isFilipino =>
      localeName == 'tl' ||
      localeName.startsWith('tl_') ||
      localeName == 'fil' ||
      localeName.startsWith('fil_');

  AppLocalizations get englishForFilipino => isFilipino ? _englishCopy : this;
}

/// Idiomatic widget-layer accessor.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Maps [requested] onto the closest locale we actually support.
Locale resolveSupportedLocale(Locale requested) {
  // A phone's language (even an explicit Tglg tag) never enables the visual
  // script preference. Only the switch or migration of an old app choice does.
  if (requested.languageCode == 'tl' || requested.languageCode == 'fil') {
    return kFilipinoLocale;
  }
  for (final supported in kSupportedLocales) {
    if (supported == requested) return supported;
  }
  if (requested.scriptCode != null) {
    for (final supported in kSupportedLocales) {
      if (supported.languageCode == requested.languageCode &&
          supported.scriptCode == requested.scriptCode) {
        return supported;
      }
    }
  }
  for (final supported in kSupportedLocales) {
    if (supported.languageCode == requested.languageCode &&
        supported.scriptCode == null) {
      return supported;
    }
  }
  return kFallbackLocale;
}

/// MaterialApp must use the same script-aware resolution as startup/services.
/// Flutter's default resolver does not treat fil and tl as aliases.
Locale resolveAppLocale(Locale? requested, Iterable<Locale> _) =>
    resolveSupportedLocale(requested ?? kFallbackLocale);

/// Holds the user's language choice and keeps the global [l10n] in sync.
///
/// A `null` [value] means "follow the device locale".
class LocaleController extends ValueNotifier<Locale?> {
  LocaleController._() : super(null);

  static final LocaleController instance = LocaleController._();

  /// Persisted marker for "follow the system locale".
  static const String systemValue = 'system';

  bool _baybayinHeadings = false;

  /// Visual preference only: it never changes controls or service messages.
  bool get baybayinHeadings => _baybayinHeadings;

  Future<void> setBaybayinHeadings(bool enabled) async {
    if (enabled == _baybayinHeadings) return;
    _baybayinHeadings = enabled;
    notifyListeners();
    await AppPreferencesService().setBaybayinHeadings(enabled);
  }

  /// True when the app follows the device locale.
  bool get followsSystem => value == null;

  /// The locale to hand to MaterialApp. Never null.
  Locale get effectiveLocale => value ?? _deviceLocale();

  /// Restores the persisted choice. Await this before the first frame.
  Future<void> load() async {
    final preferences = AppPreferencesService();
    final stored = await preferences.getAppLocale();
    _baybayinHeadings = await preferences.getBaybayinHeadings();
    // The old opt-in script locale becomes Filipino plus the visual switch.
    // Rewrite once so subsequently disabling the switch survives a restart.
    if (RegExp(
      r'^tl[_-]tglg(?:[_-](?:[a-z]{2}|[0-9]{3}))?$',
      caseSensitive: false,
    ).hasMatch(stored)) {
      _baybayinHeadings = true;
      await preferences.setBaybayinHeadings(true);
      await preferences.setAppLocale(kFilipinoLocale.toString());
    }
    final previous = value;
    value = _localeFromStored(stored);
    if (previous == value) notifyListeners();
  }

  /// Selects [locale], or `null` to follow the device locale.
  Future<void> select(Locale? locale) async {
    locale = locale == null ? null : resolveSupportedLocale(locale);
    if (locale == value) return;
    value = locale;
    await AppPreferencesService().setAppLocale(_storedFromLocale(locale));
  }

  /// Points the global accessor at [localizations]. Called from the app builder.
  void bind(AppLocalizations localizations) {
    _current = localizations;
  }

  /// Points the global accessor at [locale] without a BuildContext. Used during
  /// startup, before any Localizations widget exists.
  void bindLocale(Locale locale) {
    _current = lookupFlickLocalizations(locale);
  }

  Locale _deviceLocale() {
    final binding = WidgetsBinding.instance;
    final locales = binding.platformDispatcher.locales;
    if (locales.isEmpty) return kFallbackLocale;
    return resolveSupportedLocale(locales.first);
  }

  Locale? _localeFromStored(String? stored) {
    if (stored == null || stored.isEmpty || stored == systemValue) return null;
    // Accept both the existing en/zh_CN values and script-aware locale tags.
    final match = RegExp(
      r'^([A-Za-z]{2,3})(?:[_-]([A-Za-z]{4}))?(?:[_-]([A-Za-z]{2}|[0-9]{3}))?$',
    ).firstMatch(stored);
    if (match == null) return kFallbackLocale;
    final script = match.group(2);
    return resolveSupportedLocale(
      Locale.fromSubtags(
        languageCode: match.group(1)!.toLowerCase(),
        scriptCode: script == null
            ? null
            : '${script[0].toUpperCase()}${script.substring(1).toLowerCase()}',
        countryCode: match.group(3)?.toUpperCase(),
      ),
    );
  }

  String _storedFromLocale(Locale? locale) => locale?.toString() ?? systemValue;
}
