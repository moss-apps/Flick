# Android Auto design — templated media app (Car API 8 and 9)

Status: design. Hardware results are recorded in section 12 as they come in.

Flick becomes a Car App Library **media** app (`androidx.car.app`, category `MEDIA`). One
`CarAppService` serves two renderings and picks by the level the host negotiates:

| Rendering | When | Built from |
|---|---|---|
| **Legacy** | host negotiates Car API 8 | `SectionedItemTemplate` with `RowSection` / `GridSection`, `SearchTemplate`, `MediaPlaybackTemplate`, `Action.MEDIA_PLAYBACK` |
| **Modern** | host negotiates Car API 9 | everything above plus chips, condensed tiles, spotlight, banners, section headers, search header, expanded header, playback style, app theme |

Both have Now Playing and Up Next. There is **no host allowlist**: any host that speaks the Car
App protocol (Android Auto, DriveDeck, others) may bind. A small classic `MediaBrowserService`
covers hosts with no template support.

Library: `androidx.car.app:app:1.9.0-alpha03`. Ships in the **`full` flavor only** (section 9).

## 1. Principles

1. **Content first, two taps to music.** Home opens on things to resume, not on a menu.
2. **The phone's own library, the phone's own queue.** The car never keeps a second copy of state.
   Dart (`PlayerService`, the repositories) stays authoritative; the car asks and listens.
3. **It looks like Flick.** Monochrome ink and silver, tinted by the playing album, acid for the
   one primary action (section 2.0). Every album and track line can carry its quality
   (`24/96 FLAC`, `DSD128`), because fidelity is what Flick is for.
4. **Never a dead end.** Empty library, engine still starting, no session yet — each has a designed
   state with one clear action.
5. **A level-9 class never reaches a level-8 host.** Enforced structurally and by tests (section 6).

## 2. Screens

### 2.0 Theme — the main app, carried into the car

Flick on the phone is monochrome glass on ink, tinted by the playing album's colour, with acid
reserved for primary actions on ink fields. The car uses the same three roles. Car API 9 lets an
app style chips, banners, icons and the player; API 8 only takes the theme colours.

| Token | Value | Source in the app | Used for |
|---|---|---|---|
| `INK` | `#0A0A0A` | `AppColors.background` | text on light fills |
| `SILVER` | `#E0E0E0` | `AppColors.accent` | default accent: theme primary, selected navigation chip, icon tint |
| `ACID` | `#E3F369` | `DESIGN.md` acid ("on ink fields the action is acid with an ink label") | the single primary action per screen (Play chip), empty-library banner |
| `ALBUM` | dynamic, else `SILVER` | the colour Flick already extracts for the notification, honouring the album-colour mode (off → `SILVER`) | player accent and progress, the hero and collection chips of the playing album, banner tint |

Rules:

- Text on a filled chip or banner is `INK` when the fill is light, white when it is dark
  (relative luminance threshold 0.5), so a dark album colour never hides its label.
- Unselected chips are outlined (`glassBorderStrong`-like: white at 20 %), no fill.
- Shapes: chips `Shape.CORNER_FULL`; banners rounded through `BannerStyle`.
- API 9: `getCarAppThemeSource()` = `THEME_SOURCE_APP`, `ChipStyle`, `BannerStyle`,
  `MediaPlaybackStyle.setMediaAccentColor(ALBUM)` with `StrokeCap.ROUND`,
  `CarIcon.createTintedIcon(icon, colour)` for library icons.
- API 8: `FlickCarTheme` (`carColorPrimary` `SILVER`, secondary white); icons use the default tint.
- `ALBUM` changes re-render only the player and the screen that shows it, at most once per track.

Stack budget is 5: Root → Collection → Collection (album from artist) → Up Next → Player.
Pushing a sixth pops to root first.

### 2.1 Root

```
Modern (API 9)                                   Legacy (API 8)
┌──────────────────────────────────────────┐    ┌──────────────────────────────────────────┐
│ ◈ Flick                    🔍   Up next  │    │ ◈ Flick                    🔍   Up next  │
│ (Home) (Albums) (Artists) (Playlists)    │    │ Jump back in                             │
│ ┌────────┐  ▶ Resume · Blue in Green     │    │ [▣][▣][▣][▣]   small grid                │
│ │  art   │  ⤮ Shuffle all · 4 812 songs  │    │ Browse                                   │
│ │ (hero) │  ≡ Up next · 14               │    │ [Albums][Artists][Playlists][Songs]      │
│ └────────┘                               │    │ [Favorites][Folders]   icon tiles        │
│ Jump back in                             │    │ Recently added                           │
│ [▣ Kind of Blue][▣ Mezzanine][▣ …]       │    │ [▣▣▣▣ large grid …]                      │
│ Recently added                 See all › │    │ Most played                              │
│ [▣▣▣▣ large grid …]                      │    │ ─ row · row · row · row · row            │
│ Most played                              │    │ Playlists                                │
│ ─ rows with cover, artist · quality      │    │ [▣▣▣ large grid …]                       │
│ Library                                  │    │                               (▶ FAB)    │
│ [♪ Songs][♥ Favorites][▤ Folders]        │    └──────────────────────────────────────────┘
└──────── host minimized player ───────────┘
```

Header (both): title "Flick", `Action.APP_ICON`, end actions **Search** and **Up next**
(Up next only when something is playing or queued).

| Section | Legacy (8) | Modern (9) |
|---|---|---|
| Destination | none in place; the **Browse** icon grid pushes collection screens | one `ChipSection`, first: Home · Albums · Artists · Playlists. Selected chip filled `SILVER` with ink text, others outlined. Tap re-renders in place; tapping the selected chip returns to Home |
| State (only when needed) | one `Row` | `BannerSection` with `Banner` (`BannerStyle` rounded), optional trailing action |
| Hero | `RowSection` "Quick play": "Resume · {title}" (when a song is loaded), "Shuffle all · {n} songs" | `SpotlightSection(cover of current or last song)` with `CondensedItem`s: Resume, Shuffle all, Up next · {n} |
| Jump back in (albums and playlists from recent plays, max 8) | `GridSection` `ITEM_SIZE_SMALL` | `CondensedSection`, `CondensedItem` with `IMAGE_TYPE_MEDIUM` cover, `INCOMPLETE_LAST_ROW_AS_IS` |
| Browse / Library | `GridSection` `ITEM_SIZE_SMALL`, tinted icons: Albums, Artists, Playlists, Songs, Favorites, Folders, with counts | `CondensedSection` "Library" at the end: Songs, Favorites, Folders (the chips already cover the rest), `SILVER`-tinted icons via `CarIcon.createTintedIcon(icon, SILVER)` |
| Recently added (albums, max 12) | `GridSection` `ITEM_SIZE_LARGE`, title, text "Artist · quality" | same grid plus `SectionHeader` with "See all" click target, `INCOMPLETE_LAST_ROW_AS_IS` |
| Most played (tracks, max 5) | `RowSection`, cover `Row.IMAGE_TYPE_LARGE`, "Artist · quality" | same plus `SectionHeader` "See all" |
| Playlists (max 12) | `GridSection` `ITEM_SIZE_LARGE` | same plus `SectionHeader` "See all" |
| Now playing entry | `template.addAction(Action.MEDIA_PLAYBACK)` | nothing — at 9 the host draws its minimized control panel and ignores the action |

Sections with no data are omitted. Modern chip destinations render in place below the chips:
Albums = large grid, Artists = circle grid (`ITEM_IMAGE_SHAPE_CIRCLE`), Playlists = large grid,
each capped at 300 with a closing row "Search to find more" when truncated.

State section content:

| Condition | Text | Action |
|---|---|---|
| Flick engine still starting | template `setLoading(true)`; after 12 s a message "Flick is still starting" | Retry |
| Library empty | "Your library is empty — add music in Flick on your phone" | – |
| Bridge call failed | cached content plus "Couldn't refresh" | Retry |

### 2.2 Collection (album, playlist, artist, folder, Songs, Favorites, "See all" lists)

```
Modern                                           Legacy
┌──────────────────────────────────────────┐    ┌──────────────────────────────────────────┐
│ ‹ ▣ Kind of Blue           ⤮    Up next  │    │ ‹ Kind of Blue             ⤮    Up next  │
│     Miles Davis · 5 songs · 24/192 FLAC  │    │ ▶ Play                                   │
│ (▶ Play) (⤮ Shuffle) (＋ Add to Up next) │    │ ＋ Add to Up next                        │
│ 1  So What                    9:22       │    │ So What            1 · 9:22              │
│ 2  Freddie Freeloader         9:46       │    │ Freddie Freeloader 2 · 9:46              │
└──────────────────────────────────────────┘    └──────────────────────────────────────────┘
```

| Element | Legacy (8) | Modern (9) |
|---|---|---|
| Header | title, `Action.BACK`, end actions Shuffle and Up next | plus `setSubtitle("{artist} · {n} songs · {quality}")`, `setStartHeaderImage(cover)` |
| Actions | `RowSection`: "Play", "Add to Up next" | `ChipSection`: Play (filled `ACID`, ink label), Shuffle, Add to Up next (outlined) |
| Tracks | `RowSection`. Album: no per-row cover, text "{track no} · {duration}". Other lists: cover `IMAGE_TYPE_LARGE`, text "{artist} · {duration}" | same |
| Artist | "Albums" large grid, then "Songs" rows | `SpotlightSection(artist image)` with Play and Shuffle on top |
| Album and playlist grids ("See all", Albums, Playlists) | `GridSection` `ITEM_SIZE_LARGE` | same |
| Long track lists (Songs, Favorites, Folders) | alphabetical indexing `ALPHABETICAL_INDEXING_TITLE_IGNORE_ARTICLES_AND_SYMBOLS`, rows `setIndexable(true)`, `SCROLL_STATE_PRESERVE_INDEX` | same |

Caps: 300 items per list. When truncated, the first row is "Shuffle all {n} songs" (plays the
complete list on the Dart side) and the last is "Search to find more". Tapping a track plays the
whole collection from that track, like the phone. Rows inside sections cannot carry actions, so
queueing is per collection.

### 2.3 Up Next

```
┌──────────────────────────────────────────┐
│ ‹ Up next                       Clear    │   Clear: only when the driver queued something
│ (⤮ Shuffle on) (↻ Repeat all)            │   9: chips, selected = ALBUM.   8: two rows "Playback"
│ Now playing                              │
│ ▣ Blue in Green · Miles Davis            │   not clickable
│ Next from you                            │   manual queue; tap jumps there
│ ▣ Teardrop · Massive Attack              │
│ Next from Kind of Blue                   │   rest of the playing context; tap jumps there
│ ▣ All Blues · Miles Davis                │
└──────────────────────────────────────────┘
```

Order shown is the order played; never sorted. 100 rows at most. Modern uses `SectionHeader`
(with `setHeadline`) for the two boundaries, legacy uses section titles. "Clear" empties only the
driver's manual queue. Empty state: "Nothing queued — pick an album to start". The screen
re-renders on queue and mode changes only, never on position ticks.

### 2.4 Now Playing

`MediaPlaybackTemplate`: header `Action.BACK` and end action "Up next". Transport, artwork,
progress and custom actions (shuffle, repeat, favourite) come from Flick's `MediaSession`.
Modern adds `MediaPlaybackStyle` (accent `ALBUM`, `StrokeCap.ROUND`).

The template is only sent once a session token is registered. Before that:
`MessageTemplate` "Nothing playing yet" with a "Browse" action back to root.

Opened by: the Up next / FAB / host panel, or the host's `SHOW_MEDIA_PLAYBACK` intent. On that
intent in `onCreateScreen` the root is pushed first and the player on top, so Back works.

### 2.5 Search

| | Legacy (8) | Modern (9) |
|---|---|---|
| Template | `SearchTemplate` with an `ItemList` cut to `ConstraintManager.CONTENT_LIMIT_TYPE_LIST` | `SectionedItemTemplate` with `SearchHeader`; results as sections: Songs rows, Albums grid, Artists circle grid, Playlists grid |
| Behaviour | 300 ms debounce, stale answers dropped | same |

Voice ("play … on Flick") goes through the session's `onPlayFromSearch`.

## 3. Classic browse tree

For hosts without templates. Same library, shallow tree, all lists cut to the requested page size:

```
root ─ Recently played (playable) · Albums · Artists · Playlists · Favorites · Songs
```

The session also publishes the upcoming queue (`setQueue`, `onSkipToQueueItem`), so classic
hosts get their own Up Next.

## 4. Architecture

```
            Dart (authoritative)                      Kotlin
 PlayerService ─┐                         ┌─ FlickCarAppService ─ FlickCarSession ─ screens
 repositories ──┼─ CarBridge ══ channel ══┼─ CarLink (requests, cache, change fan-out)
 FavoritesSvc ──┘  com.mossapps.flick/car ├─ FlickMediaBrowserService (classic)
                                          ├─ CarArtProvider (content:// covers)
 NotificationService ══ …/player ═════════╧─ MusicNotificationService (owns MediaSession)
```

### 4.1 Engine without an activity

Today the Flutter engine is created only by `MainActivity`. A car can connect with the app closed,
so engine creation moves to `FlickEngine.ensure(context)` (main source set): create, register
plugins, register the *context-only* channel handlers, run the default entrypoint, cache as
`main_engine`. `MainActivity.provideFlutterEngine` calls the same function, so there is still
exactly one engine.

Context-only handlers move out of `MainActivity` into `FlickEngine`: the `…/player` handler
(show / update / hide notification — it only starts or stops `MusicNotificationService`) and the
new `…/car` channel. Everything that needs an activity stays where it is; in a headless start
those channels have no handler until the user opens the app.

Dart changes for a headless start:

- `ExternalPlaybackService.initialize` must also survive `MissingPluginException` (today it aborts
  `main()` before `runApp`).
- `CarBridge.init()` runs in `main()` right after `Database.init()`, before anything that can fail.
- The first car request awaits `PlayerService().prepareForAppLaunch()` (idempotent), because
  post-frame callbacks may never fire without a view.

`MusicNotificationService.onTaskRemoved` must not kill the process while a car session is bound.

### 4.2 Session token

`MusicNotificationService` keeps owning the `MediaSessionCompat`. A main-source-set object
`FlickSessionHub` publishes the current token (set in `setupMediaSession`, cleared in
`onDestroy`) and the current album colour (the notification `color` argument) to listeners. The car session registers it with
`MediaPlaybackManager.registerMediaPlaybackToken` whenever it appears or changes; the classic
browser calls `setSessionToken` on the first one.

Session additions (all in `MusicNotificationService`): `METADATA_KEY_ALBUM`, `MEDIA_ID`,
`ALBUM_ART_URI` / `DISPLAY_ICON_URI` (provider URI); custom actions always present, plus repeat;
`setRepeatMode`; `setQueue` / `setQueueTitle`; callbacks `onSkipToQueueItem`,
`onPlayFromMediaId`, `onPlayFromSearch`, `onSetRepeatMode`.

### 4.3 Channel contract — `com.mossapps.flick/car`

All values are plain maps and lists. Any failure returns an error, never a partial map.

```
Track      {id, title, artist, album, art?, durationMs, quality?, trackNo?}
Collection {kind, id, title, subtitle?, art?, count?}
kind       album | artist | playlist | folder | songs | favorites
           | recentlyAdded | mostPlayed | recentlyPlayed | search
```

Kotlin → Dart:

| Method | Arguments | Result |
|---|---|---|
| `status` | – | `{ready, songCount}` |
| `home` | – | `{resume: Track?, jumpBackIn: [Collection], recentlyAdded: [Collection], mostPlayed: [Track], playlists: [Collection], counts: {songs, albums, artists, playlists, favorites, folders}, queueCount}` |
| `list` | `{kind: albums\|artists\|playlists\|folders\|recentlyAdded, limit}` | `{items: [Collection], total}` |
| `collection` | `{kind, id, limit}` | `{title, subtitle?, art?, quality?, tracks: [Track], albums: [Collection], total}` |
| `search` | `{query, limit}` | `{tracks, albums, artists, playlists}` |
| `play` | `{kind, id, trackId?, shuffle?}` | – (plays the complete collection, from `trackId` when given) |
| `enqueue` | `{kind, id}` | `{added}` (max 50) |
| `queue` | `{limit}` | `{current: Track?, fromYou: [Track], fromContext: [Track], contextName?, shuffle, loop: off\|all\|one}` |
| `jump` | `{section: you\|context, index}` | – |
| `clearQueue`, `toggleShuffle`, `cycleLoop`, `toggleFavorite`, `resume` | – | – |
| `playSearch` | `{query}` | – (voice) |

Dart → Kotlin: `changed {what: queue | modes | library | track}`, coalesced to one call per 150 ms.

`quality` is a short label built in Dart: `DSD64`…`DSD512` for DSD, otherwise
`"{bitDepth}/{kHz} {fileType}"` when bit depth and sample rate are known, else the file type.

Dart keeps one library snapshot (album groups, artist map) and drops it on library change, so a
browse request never rescans the database per tile.

### 4.4 Artwork

Covers are files in app-private storage. `CarArtProvider` (exported, read-only, authority
`${applicationId}.carart`) serves `content://…/art/{base64url(path)}`:

- the canonical path must be inside the app's own data or external-files directories;
- the file must decode as a bitmap; the provider returns only a **re-encoded** JPEG, at most
  512 px, cached in `cacheDir/car_art/`. Raw private files are never streamed;
- anything else → `FileNotFoundException`; the UI falls back to a bundled placeholder.

Icons are `CarIcon.Builder(IconCompat.createWithContentUri(uri))`; no bitmaps cross the binder.

### 4.5 Refresh

`CarLink` receives `changed`, drops the affected cache entries and tells the top screen. A screen
invalidates only when its own view model actually changed. Every async answer carries a
generation number and is dropped after `onDestroy` or when a newer request exists. Late taps on
covered screens are ignored.

## 5. Files

```
lib/services/car/car_bridge.dart            channel handler, change fan-out
lib/services/car/car_library.dart           snapshot, list / collection / search / home queries
lib/services/car/car_models.dart            Track / Collection maps, quality label
test/services/car/*                         Dart tests

android/app/src/main/kotlin/com/mossapps/flick/
  FlickEngine.kt  FlickSessionHub.kt  CarArtProvider.kt  CarChannel.kt
android/app/src/full/kotlin/com/mossapps/flick/car/
  FlickCarAppService.kt  FlickCarSession.kt  CarLink.kt  CarNav.kt
  model/CarModels.kt                        parse channel maps
  ui/Specs.kt                               level-independent description of a page
  ui/Pages.kt                               view model → specs, per level (pure Kotlin)
  ui/Render.kt  ui/Render9.kt               specs → car templates; API 9 classes only in Render9
  ui/CarStyle.kt                            accent, icons, placeholder
  screens/RootScreen.kt CollectionScreen.kt QueueScreen.kt PlayerScreen.kt SearchScreen.kt
  FlickMediaBrowserService.kt
android/app/src/full/AndroidManifest.xml    permission, services, meta-data, queries
android/app/src/full/res/xml/automotive_app_desc.xml, values/car_styles.xml, drawable/ic_car_*.xml
android/app/src/testFull/kotlin/…           JVM tests
```

## 6. Level rules

- `CarStyle.api9(carContext)` = `carAppApiLevel >= CarAppApiLevels.LEVEL_9` is the only level read.
- `Pages` is pure Kotlin: `(viewModel, api9) → List<SectionSpec>`. Specs that need level 9
  implement the marker `Api9Spec`. A JUnit test builds every page at level 8 over rich fixtures
  and asserts no `Api9Spec` appears, plus caps, ordering and the single-first-`ChipSection` rule.
- `Render9.kt` is the only file that imports API 9 classes and is only called for `Api9Spec`s.
- `IMAGE_TYPE_ICON` is deprecated in 1.9; use `IMAGE_TYPE_SMALL` / `MEDIUM` / `LARGE`.

## 7. Manifest (full flavor)

```xml
<uses-permission android:name="androidx.car.app.MEDIA_TEMPLATES"/>
<queries> <package android:name="com.google.android.projection.gearhead"/>
          <package android:name="com.google.android.apps.automotive.templates.host"/>
          <package android:name="app.johninnl.drivedeck"/> </queries>
<application>
  <meta-data android:name="androidx.car.app.minCarApiLevel" android:value="8"/>
  <meta-data android:name="androidx.car.app.theme" android:resource="@style/FlickCarTheme"/>
  <meta-data android:name="com.google.android.gms.car.application"
             android:resource="@xml/automotive_app_desc"/>      <!-- media + template -->
  <service android:name=".car.FlickCarAppService" android:exported="true">
    <intent-filter>
      <action android:name="androidx.car.app.CarAppService"/>
      <action android:name="androidx.car.app.media.action.SHOW_MEDIA_PLAYBACK"/>
      <category android:name="androidx.car.app.category.MEDIA"/>
    </intent-filter>
  </service>
  <service android:name=".car.FlickMediaBrowserService" android:exported="true">
    <intent-filter><action android:name="android.media.browse.MediaBrowserService"/></intent-filter>
  </service>
  <provider android:name=".CarArtProvider" android:authorities="${applicationId}.carart"
            android:exported="true"/>
</application>
```

`createHostValidator()` returns `HostValidator.ALLOW_ALL_HOSTS_VALIDATOR`;
`getCarAppThemeSource()` returns `THEME_SOURCE_APP`. `FlickCarTheme`: `carColorPrimary` and
`carColorPrimaryDark` `#E0E0E0`, secondary white. The classic browser's `onGetRoot` accepts any
caller.

## 8. Limits and rules carried over from Eclipse Music and Aurora

- 300 items per list, 100 queue rows, 30 per search type: thousands of cover requests each hold a
  host binder thread and froze Android Auto.
- One `ChipSection` per template and it must be first.
- Main thread only for car callbacks; bridge answers are posted to main.
- No invalidation on position updates.
- Reject nothing by package; trust nothing from a caller: media ids are parsed, never executed.

## 9. Scope decisions

| Decision | Reason |
|---|---|
| `full` flavor only | an alpha library plus allow-all-hosts would put the `play` flavor through Google's car review and can block Play releases. Moving the `car` folder and manifest block to `main` enables it for both |
| No `Badge`, `CarProgressBar`, `Header.setBackground`, row end images | never seen rendering on any host we own; quality goes in the text line instead. Easy to add once seen on DriveDeck |
| Quality label instead of a badge | works identically at 8 and 9 |
| Scrobbling in a headless start | lives in the widget tree; may not run until the app is opened. Not changed here |

## 10. Verification

| Layer | Check |
|---|---|
| Dart | `flutter analyze`; tests for quality labels, model maps, queue split, list caps |
| Kotlin JVM | page specs at both levels, level-8 purity, caps, media-id parsing, art path guard |
| Build | `flutter build apk --debug --flavor full`; the APK contains `car-app-api.level` |
| Hardware (owner) | DriveDeck at 9 and at 8, Android Auto, one classic host; cold start with Flick closed |

## 11. Open risks

| # | Risk | Fallback |
|---|---|---|
| R1 | Headless engine start: playback started from the car with the app never opened uses audio paths that were only ever exercised with an activity | "Open Flick on your phone" state already designed; USB DAC paths are out of scope in the car |
| R2 | API 9 classes are experimental and may change in later alphas | all isolated in `Render9.kt` |
| R3 | Whether Android Auto lists a templated media app without the classic service is unverified | the classic service ships |
| R4 | Rapid chip switching may hit the host's refresh quota | a switch only changes the selected key; one invalidate per data answer |

## 12. As built

Status: implemented and verified off-device. Nothing here has run on a car host yet; section 12.4
lists what only hardware can settle.

### 12.1 What exists

`full` flavor only (`play` compiles and contains no car class, manifest entry or resource).

```
android/app/build.gradle.kts            "fullImplementation"("androidx.car.app:app:1.9.0-alpha03"), androidx.media not excluded
android/app/src/full/AndroidManifest.xml          MEDIA_TEMPLATES, queries, minCarApiLevel 8, theme, automotive_app_desc,
                                                  FlickCarAppService (CarAppService + SHOW_MEDIA_PLAYBACK, category MEDIA),
                                                  FlickMediaBrowserService
android/app/src/full/res/                         xml/automotive_app_desc.xml (media + template), values/car_styles.xml,
                                                  drawable/ic_car_{albums,artists,playlists,songs,favorites,folders,search,
                                                  queue,shuffle,repeat,repeat_one,play,add_queue,placeholder}.xml
android/app/src/full/kotlin/com/mossapps/flick/car/
  FlickCarAppService.kt  FlickCarSession.kt  CarLink.kt  CarNav.kt (stack limit, Fence)  CarStrings.kt  EngineGate.kt
  ClassicTree.kt  FlickMediaBrowserService.kt
  model/CarModels.kt
  ui/Specs.kt  ui/ViewModels.kt  ui/CarPalette.kt  ui/Pages.kt   pure Kotlin, no androidx or android import
  ui/Render.kt  ui/Render9.kt  ui/CarStyle.kt                      the renderers; Render9 is the only API 9 importer
  screens/FlickScreen.kt  RootScreen.kt  CollectionScreen.kt  QueueScreen.kt  PlayerScreen.kt  SearchScreen.kt
android/app/src/testFull/kotlin/com/mossapps/flick/car/           9 test classes, 93 tests
```

How the level rule is enforced: `Pages` returns plain specs; every spec that needs level 9 implements
`Api9Spec`; `Render` (no API 9 import) draws everything else and drops and logs an `Api9Spec` it is handed
at level 8; `Render9` builds the rest. `CarStyle.api9` is the only reader of the negotiated level.
`StructureTest` checks this on the compiled classes (a class file names every class and method it uses),
including that the section builders in `Render9` return the level 8 type `Section<*>`, so no level 9 class
appears in a method descriptor either.

### 12.2 Verified off-device

| Check | Result |
|---|---|
| `./gradlew :app:compileFullDebugKotlin :app:compilePlayDebugKotlin` | both succeed, no warnings from the car code |
| `./gradlew :app:testFullDebugUnitTest` | 189 tests, 0 failures: 93 car tests in 9 classes plus the 96 existing ones |
| `./gradlew :app:testPlayDebugUnitTest` | 96 tests, 0 failures, no car test in it |
| Level safety | `PagesLevelTest`: 65 pages (every state of root, chip tabs, 5 collection kinds, 5 lists, queue, search, player) built at level 8 contain no `Api9Spec`, found by a reflection walker; at level 9 the same walk finds all 10 `Api9Spec` types, so it is not vacuous; the ChipSection is single and first on every level 9 page |
| Mutation check | making `Pages.root` build the chips at level 8 fails 5 tests, as it should |
| Caps and ordering | home 8 / 12 / 5 / 12, lists 300, queue 100 (the driver's own first), search 30 per type, level 8 search list cut to the host limit; section order at both levels; empty sections omitted; queue split now playing / from you / from context; Clear only when `fromYou` is non-empty; truncated lists open with "Shuffle all N songs" and close with "Search to find more" |
| Models | Int and Long, missing and odd-typed fields, dropped entries, ids as numbers, an ARGB colour arriving as a Long, non-map answers as `CarModelException` |
| Contrast | ink on light fills (silver, acid, white), white on dark ones and on mid grey (threshold 0.5), alpha ignored, ALBUM opaque with silver fallback |
| Classic tree | root nodes and ids, ids parse back to what they open, strangers' ids rejected, track ids `kind|id|trackId` round-trip through `CarMediaId`, page size default 100 / `EXTRA_PAGE_SIZE` / page offset / cap 300 |
| Cold start | `EngineGate`: `notImplemented`, `timeout` and `ready: false` wait; other failures do not; 700 ms poll, 12 s give-up |
| Merged manifest (`:app:processFullDebugMainManifest`) | full: both services, `androidx.car.app.MEDIA_TEMPLATES`, `minCarApiLevel` 8, theme and `automotive_app_desc` meta-data, the three `queries`; play: none of them (only the shared `CarArtProvider`) |
| `car-app-api.level` | present (content `9`) in the full variant's merged Java resources, absent from play's. The full APK itself was not built, see 12.3 |

### 12.3 Deviations from the design, and why

- **No full APK.** `flutter build apk --debug --flavor full` (all ABIs, and again with
  `--target-platform android-arm64`) stops in the Rust crate `wavpack-sys`: its bindgen step cannot find
  `sys/types.h` for the Android target on this machine. That is the native build, not the car code, and
  the Kotlin compile, manifest merge and Java-resource merge tasks of `assembleFullDebug` succeed. `car-app-api.level` was therefore checked
  in the merged resources (`:app:mergeFullDebugJavaResource`), which is what the APK root is made from.
- **Banner tint.** The design lets ALBUM tint banners. `BannerStyle` has a shape and a background but no
  content colour, so a text colour that is readable on any album colour cannot be guaranteed. Only the
  empty-library banner is filled (acid, as designed); state banners keep the host's colours. ALBUM still
  tints the player accent, the hero and Up next icons, the active Up next mode chips, and the outline of
  the chips of the playing collection.
- **Grid image types.** In alpha03 `GridItem` has only `IMAGE_TYPE_ICON` and `IMAGE_TYPE_LARGE`, both
  deprecated, and no small or medium type. Covers use `setImage(icon)` (no constant); the level 8 Browse
  icon tiles use the deprecated `IMAGE_TYPE_ICON` once, suppressed, because a vector stretched into the
  cover slot looks wrong. Rows and condensed items use `SMALL` / `MEDIUM` / `LARGE`.
- **Deprecated builder calls avoided.** `SectionedItemTemplate.Builder.setAlphabeticalIndexingAllowed` is
  deprecated and redundant (the strategy alone switches indexing on); `MessageTemplate` uses `setHeader`
  instead of the deprecated `setTitle` / `setHeaderAction`.
- **Section headers.** At level 9 the Up next boundaries are `SectionHeader(title).setHeadline("{n} songs")`:
  headline and subtitle exclude each other (the builder throws, and `SectionHeaderSpec` refuses the pair).
  "See all" headers use the subtitle slot as in the reference apps.
- **Unselected chips** have a fully transparent background and the 20 % white outline. Whether the host
  honours alpha in a chip colour is a hardware question.
- **Small additions.** A "Starting playback..." state on the player between a play command and the session
  appearing (the player would otherwise say "Nothing playing yet" for a second or two); collection screens
  ask `queue {limit: 1}` once, to offer Up next and to know whether the playing song is in them; a search
  result plays through `play {kind: search, id: query, trackId}`, which is what the Dart side resolves;
  `FlickMediaBrowserService` retries a browse for up to 12 s while the engine starts.
- **Structural folders** of the classic tree use ids that are not media ids on purpose (`flick:albums`...);
  every playable or openable collection uses a `CarMediaId`.
- **Alphabetical indexing** is on for every Songs, Favorites and Folder track list, with no minimum length.
- **Files beyond the design list:** `CarStrings`, `EngineGate`, `ClassicTree`, `ui/ViewModels`,
  `ui/CarPalette`, `screens/FlickScreen`, and `Fence` inside `CarNav.kt`.

Nothing the design relies on is missing from 1.9.0-alpha03. Every builder call was checked with `javap`
against the AAR; the `@RequiresCarApi(9)` annotations in it are the list `StructureTest` guards.
`CarIcon.createTintedIcon(IconCompat, CarColor)` is not marked level 9 in the AAR; it is still only used
at level 9, as designed.

### 12.4 Hardware only (owner)

1. A host lists Flick at all (R3), with and without the classic service; DriveDeck at 9 and at 8.
2. Cold start with Flick closed: the loading template, the 12 s "still starting" state, and playback
   started from the car with the app never opened (R1), including the session token appearing late.
3. Rendering that cannot be judged from the specs: chip outlines and selected fill, acid and album
   colours, the empty-library banner's text colour, `SectionHeader` headline, spotlight and condensed
   tiles, the header subtitle and start image, alphabetical indexing, the level 8 icon tiles, art through
   the content provider, `MediaPlaybackStyle` accent and round progress, the absence of a second
   control panel at 9.
4. The player's custom actions (shuffle, repeat, favourite), `onSkipToQueueItem`, Up next jumps, voice
   search through `onPlayFromSearch`.
5. The classic service: browsing every folder with the app closed, paging, playing from a track, search,
   and the session token. `setSessionToken` is one-shot, so a media session that is recreated later keeps
   the first token; if that shows up on a classic host, the service needs recreating instead.
6. Level 8 search (`SearchTemplate`) and level 9 search (`SearchHeader`), debounce and stale answers.
7. The stack limit (a sixth push pops to the root) and `popTo` for `SHOW_MEDIA_PLAYBACK` while the player
   is already open.
8. A full `flutter build apk --debug --flavor full` on a machine where the `wavpack-sys` bindgen step
   works, then `unzip -l` for `car-app-api.level`.
