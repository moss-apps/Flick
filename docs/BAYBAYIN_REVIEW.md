# Filipino and Baybayin review

**Draft, not linguistically verified.** The Filipino reviewer decides whether
the wording is natural and the Baybayin spelling is correct. Passing tests does
not approve a translation. The 2,355-message Latin resource, eleven curated
Baybayin labels, fifteen native-speaker-supplied Taglish hooks and six streak
greetings remain drafts for review. The latest corrections are screen-specific,
not a global replacement of Filipino with English.

## Try it

1. Open Settings → Interface → Language and select **Taglish**.
2. **English** remains an always-Latin escape option.
3. Enable **Baybayin labels** in the same language card if desired.
4. Check the Browse shortcut carousel, named screen/navigation labels and player
   status. The four original library headings retain smaller Filipino captions;
   the added compact labels do not show duplicate Latin text. Turn the switch off
   to restore their Latin fallbacks immediately.

New installations default to the switch **off**. A Filipino/Tagalog phone locale
selects Taglish, never Baybayin. The switch is remembered independently of the
language and only takes effect while the interface is Taglish. The earlier
explicit `tl_Tglg` app selection migrates once to Taglish with headings on;
subsequently turning them off survives a restart.

## Script policy

**Script and language are chosen by screen role.** With Taglish selected:

- Home greetings use the reviewer's verbatim Taglish hooks. The summary shows
  real counts on three lines: `902 na kanta`, `18 mga paborito mo`, `1 playlist`
  are examples, not hardcoded values.
- The Browse shortcut row uses Baybayin for Library, Albums, Folders, Queue and
  Artists when enabled. The **Flick Replay** shortcut stays in English. Smart
  mixes and original playlist names are not the requested carousel and are not
  converted.
- Home's current-playback heading uses **Kasalukuyang tumutugtog** in Baybayin;
  both player layouts use only **Tumutugtog** in Baybayin, with no visible caption.
- Favorites, Artists, Queue, Folders and the main Settings headings use Baybayin.
  The Artists/Favorites/Folders/Settings navigation labels also use it. Individual
  setting names remain English, not Baybayin.
- The four quick-access cards below Now Playing keep English for **Favorites**
  and **Artists**; their Baybayin versions appear only where those labels are the
  browse shortcut, heading or navigation item.
- Other general home copy is English. The audio-engine picker is fully English
  in Taglish: title, option names, and explanations. English and Chinese keep
  their own localized copy.
- Flick Replay is fully English in Taglish: cards, period labels and dates,
  studio controls, tooltips, empty/error states and saved posters. Downloadable
  CSV/TXT recaps are always English regardless of UI language.
- The streak popup keeps its count label and both buttons in English
  (`N day streak`, `Continue`, `Don't show again today`). Its message is one of
  six Taglish greetings chosen at random each time the popup opens.
- Settings uses English for its section names, titles, options and descriptions.
  The only Taglish line is the page tagline:
  **Dito mo ayusin mga configuration ng settings mo.**
- The home update notice says **Yun oh! May bagong update na naman!** Its other
  copy/actions remain English.
- Original server/device/preset names stay unchanged even though the surrounding
  settings copy is English.
- Support titles, categories and descriptions use English. Only Taglish shows
  **Donations will help me a lot! Hehehe. Sana masarap ulam mo lagi!** in its own
  small card immediately above the Ko-fi / Buy Me a Coffee card. Donation
  destinations are unchanged.
- Favorite add/remove toasts are the only Taglish toasts:
  **Goods, na sa favorites mo na.** and **Okay, naalis na po.** All other toasts
  use English, including settings, lyrics, artwork, queue and deletion messages.
- Search is unchanged. The remaining Filipino resource stays available to other
  screens and services; there is no global English or Baybayin override.
- Track titles, musical-artist names, album names, user playlist names and actual
  lyrics remain the original data. Translating the label **Lirika** does not
  translate a song's lyrics.
- Product names, standard units and established audio terms such as USB DAC,
  DSD and EQ retain their technical spelling; surrounding explanations are
  Filipino. The original MIT license text is retained unchanged.
- Baybayin labels have one Latin Filipino accessibility label rather than
  asking a screen reader to pronounce the script or announce both copies.

## Wording and spelling conventions

The reviewer's requested terms are **Mga kanta**, **Mga kumanta**,
**Mga talaan ng kanta**, **Susunod na kanta**, **Nakaraang kanta**, and **Lirika**.
These Latin corrections do not approve the Baybayin spellings.

The script drafts use modern vowel cancellation with **U+1714** (virama).
They share da/ra, e/i and o/u signs; they do not introduce a separate modern ra.
Review the actual sounds, syllables, final consonants and combining marks,
especially loanwords such as *album* and *polder*. The Baybayin resource proposes
**Mga polder** while the unchanged Latin/search baseline keeps **Mga folder**.
Decide whether `ᜋᜅ` for *mga* is the
preferred convention. No test can make that orthographic decision for a reader.

### Curated label drafts

Keep these rows synchronized with `lib/l10n/app_tl_Tglg.arb`. Approve a row only
after reading the Latin intent, checking its screen context, and reviewing the
Baybayin in the app or rendered screenshots. A Markdown viewer may lack the font.

| Key | English | Context | Latin Filipino draft | Baybayin draft | Status |
|---|---|---|---|---|---|
| `albums` | Albums | Albums library heading and menu browse shortcut. | Mga album | ᜋᜅ ᜀᜎ᜔ᜊᜓᜋ᜔ | draft |
| `artists` | Artists | Artists heading, menu shortcut and navigation; quick-access card and artist metadata stay English. | Mga kumanta | ᜋᜅ ᜃᜓᜋᜈ᜔ᜆ | draft |
| `favorites` | Favorites | Favorites heading, menu shortcut and navigation label; quick-access card stays English. | Mga paborito | ᜋᜅ ᜉᜊᜓᜇᜒᜆᜓ | draft |
| `folders` | Folders | Folders heading, browse shortcut and navigation; proposed polder spelling. | Mga polder | ᜋᜅ ᜉᜓᜎ᜔ᜇᜒᜇ᜔ | draft |
| `queue` | Queue | Queue screen heading and menu browse shortcut, not settings titles. | Pila | ᜉᜒᜎ | draft |
| `settings` | Settings | Main Settings heading and navigation, not individual setting titles. | Mga pagsasaayos | ᜋᜅ ᜉᜄ᜔ᜐᜐᜀᜌᜓᜐ᜔ | draft |
| `libraryLabel` | Library | Menu Library browse shortcut only. | Aklatan | ᜀᜃ᜔ᜎᜆᜈ᜔ | draft |
| `nowPlaying` | Now Playing | Menu current-playback heading; player uses the separate compact Tumutugtog label. | Kasalukuyang tumutugtog | ᜃᜐᜎᜓᜃᜓᜌᜅ᜔ ᜆᜓᜋᜓᜆᜓᜄ᜔ᜆᜓᜄ᜔ | draft |
| `playingLabel` | Playing | Player status heading only, with no visible Latin caption. | Tumutugtog | ᜆᜓᜋᜓᜆᜓᜄ᜔ᜆᜓᜄ᜔ | draft |
| `playlists` | Playlists | Main Playlists library heading only; not navigation or user-created names. | Mga talaan ng kanta | ᜋᜅ ᜆᜎᜀᜈ᜔ ᜈᜅ᜔ ᜃᜈ᜔ᜆ | draft |
| `songs14` | Songs | Main Songs library heading only; not navigation, counts or nested sections. | Mga kanta | ᜋᜅ ᜃᜈ᜔ᜆ | draft |

For the full Latin baseline, review `lib/l10n/app_tl.arb` against the English
template and each actual screen. Prioritize permissions, deletion, scan/storage
errors, playback/output descriptions and DSP warnings before cosmetic copy.
All entries are drafted; retaining an audio term is not a claim of approval.
Keep English/Chinese translations and their existing strict tests intact.

## Filipino-only home hooks

These are the native Filipino reviewer's exact replacement lines, including
English/Taglish, slang and punctuation. They are exclusive to Filipino and do not
replace English or Chinese greetings. They do not inspect listening history.

One hook is chosen deterministically per local calendar day and period: four
morning, four afternoon, **three evening**, and four late-night entries.
It stays stable on rebuild, refresh or restart and rotates daily. The period is
checked when the home greeting rebuilds, as with the existing greeting; this does
not add a background timer, network request or persisted counter.

| Local period | Original Filipino hook | Status |
|---|---|---|
| Morning, 05:00–11:59 | Uy, good morning! | draft |
| Morning, 05:00–11:59 | Kape muna. | draft |
| Morning, 05:00–11:59 | Almusal plus music? G! | draft |
| Morning, 05:00–11:59 | Good morning, sunshine. | draft |
| Afternoon, 12:00–17:59 | Break time music? | draft |
| Afternoon, 12:00–17:59 | Coffee break? After work or studies? | draft |
| Afternoon, 12:00–17:59 | Sunset na naman. | draft |
| Afternoon, 12:00–17:59 | Pahinga-pahinga rin. | draft |
| Evening, 18:00–21:59 | Dinner with music? | draft |
| Evening, 18:00–21:59 | Commuting pauwi with music? | draft |
| Evening, 18:00–21:59 | Ingat lagi! Listen well! | draft |
| Late night, 22:00–04:59 | Oh, walang magrerelapse ha? | draft |
| Late night, 22:00–04:59 | Hatinggabi na boss, itulog mo yan. | draft |
| Late night, 22:00–04:59 | Luh, puyat yarn? | draft |
| Late night, 22:00–04:59 | Listen for a bit tapos sleep na ha? | draft |

Review tone as a coherent set, not just literal correctness: warm, music-first,
brief, inclusive and not overly promotional. Edit `lib/l10n/home_greeting.dart`
and the corresponding rows together. Technical tests only check selection,
stability, locale isolation, review coverage and layout.

## Filipino-only streak greetings

The launch-day streak popup keeps its visible count label and both buttons in
English under Taglish. Its message is one of the six native-speaker-supplied
Taglish lines below, chosen at random each time the popup opens. English and
Chinese keep their existing tier-specific messages.

| Original Taglish greeting | Status |
|---|---|
| Uy oh, may nagbabalik! | draft |
| Welcome back po. Tara music jam na ulit. | draft |
| Handa mo na earphones mo ulit. Hahaha. | draft |
| Hobby mo talaga music, maem? | draft |
| Share your music with? | draft |
| Baka mamaya puro ka relapse ha? | draft |

Edit `lib/l10n/streak_greeting.dart` and the corresponding rows together.

## Implementation notes

- App locale is `tl`, the Tagalog locale supported by Flutter's stock controls;
  `fil` language tags are accepted as aliases. This is the Filipino UI choice.
- `tl_Tglg` is a **resource-only** generated subclass. It is excluded from the
  app's supported locale list. Only `BaybayinText` reads its curated overrides;
  `LibraryHeading` wraps that widget for the four captioned library headings.
- App services retain the Latin baseline with Filipino ICU formatting rules.
  `englishForFilipino` is an explicit copy-role accessor for reviewed home/support
  copy and setting titles; English and Chinese keep their own resources. There
  is no translated-string lookup, automatic transliteration or ICU-locale hack.
- The visual switch cannot change notifications or service strings into
  Baybayin. Native Android notifications/widgets do not inherit Flutter fonts;
  their Latin Filipino layout and locale refresh still require device testing.
- The existing font fallback includes the bundled Noto Sans Tagalog, so no
  network font fetch or package dependency is needed.

## Verification and release checklist

Automated localization tests cover full Filipino key parity and ICU arguments,
eleven-key script allowlisting, review-table synchronization, reviewer vocabulary,
plural counts (0, 1, 2, 101), old preference migration, locale aliases, independent
persistence, live switching, Latin accessibility labels, actual font coverage,
narrow layouts, enlarged text and all home/streak greeting variants. They **do
not certify linguistic correctness or Android/TalkBack behavior**.

```sh
flutter gen-l10n
flutter test test/l10n --no-pub
flutter test test/l10n/baybayin_layout_test.dart --no-pub --dart-define=BAYBAYIN_SCREENSHOTS=true
```

Optional review images are written to ignored `build/baybayin_shots/`. They are
host widget renders with bundled fonts, not a substitute for Android hardware.

Before removing the experimental/draft notices, the Filipino reviewer should:

- [ ] Review Latin Filipino wording, all eleven Baybayin spellings, home hooks
      and the six streak greetings.
- [ ] Test Android API 26 and a current Android version, including bold text,
      combining/final marks, narrow widths and large system font sizes.
- [ ] Switch Taglish ↔ English ↔ Chinese and enable/disable headings live.
- [ ] Force-stop/relaunch: verify both preferences, default-off behavior and the
      one-time migration; disabling migrated headings must remain disabled.
- [ ] Follow a Filipino/Tagalog phone locale: Taglish appears, headings stay off
      unless previously explicitly enabled. English escape remains reachable.
- [ ] Check the per-screen role policy above, including the English Flick Replay
      shortcut and the Baybayin Browse shortcuts, both player layouts,
      all-English settings except the Taglish tagline,
      unchanged search, and the Taglish-only support card. Technical values and
      original music/playlist metadata must not change.
- [ ] Use TalkBack: each heading announces its Latin label once as a heading;
      verify actual Filipino pronunciation rather than assuming language support.
- [ ] Check home hooks across time boundaries and day changes, including long
      hooks at enlarged text settings. Confirm the streak popup rotates through
      all six lines and fits the longest greeting.
- [ ] Check native dialogs, notifications and home-screen widgets separately for
      Latin Filipino font support, clipping and stale strings after switching.

The automated checks above run on the host; Android and TalkBack checks have not
yet been completed. Device checks and human approval remain release gates.

## Font provenance

Unmodified `assets/fonts/NotoSansTagalog-Regular.ttf`, 53,012 bytes, from
[Google Fonts / Noto Sans Tagalog](https://github.com/google/fonts/tree/main/ofl/notosanstagalog).

- Git blob: `ca69d2626661d2baf304e591bad6914574314aef`
- SHA-256: `871a66319d10d1a027eee889f75ea49be0b7d2a4e97acd6bf7f7a0ed1d741aac`
- Copyright 2022 The Noto Project Authors (https://github.com/notofonts/tagalog)
- SIL Open Font License 1.1: `assets/fonts/NotoSansTagalog-OFL.txt`, bundled and
  registered in the app's license screen. No font package dependency was added.
