---
version: 1
slug: "tutorial-guidance"
primary_target: "lib/features/onboarding/widgets/tutorial_overlay.dart"
related_targets: ["lib/providers/tutorial_provider.dart","lib/features/onboarding/tutorial_targets.dart","lib/features/onboarding/tutorial_navigation.dart"]
---

# Interactive tutorial

Visitor mode: Operate. Help listeners find and play their own music with real
controls, without requiring playback or setup to finish the guide.

## Direction contract

Keep the five welcome posters unchanged. This is compact guidance over the
existing Material dark library, settings, and player, not another poster screen.
Use the app's bundled font stack, paper text, one acid accent, and native
48dp-minimum buttons. Bound and scroll the tooltip for short windows, large text,
safe insets, and the keyboard. No decorative animation or perpetual motion.

The invitation is optional. Adapt the core route to an empty or populated
library, the configured search destination, and existing playback. Listeners
can use the highlighted control or Continue; Back and End tour remain available.
Finish with Done, not a compulsory manual launch. Independently replayable
library, player/queue, appearance, and audio guides live in the guide picker,
also accessible from the existing Interactive Tutorial setting.

Only relevant real actions advance a step. Observe successful playback rather
than requesting playback. Never change volume, queue, output, DSP, or user
preferences for a demonstration. Missing controls, loading, permissions, picker
cancellation, and playback failure must not trap the listener. Yield to modal
routes and Android permission/folder pickers; restore guidance on return.

Anchor actual rendered controls across portrait, rail, landscape, and player
layouts. Measure relative to the overlay after layout, not fixed delays. Keep
real controls hit-testable and retain native semantics. Deep-link existing
manual sections instead of duplicating their detailed instructions.

Persist dismissed and completed states separately per stable guide ID. Preserve
legacy completion and never downgrade completion when a replay is dismissed.
English and Chinese are localized; Taglish guidance and controls remain English.

## Verification boundary

Provider and widget tests cover guide adaptation/progression, unavailable
controls, real taps, persistence/migration, route/modal handoff, large text,
keyboard bounds, Chinese, and English guidance under Taglish. The existing
onboarding and landscape mini-player handoff regressions remain in scope.

Native Android visual, TalkBack, permission-picker, and playback sign-off is
still open: the emulator did not come online. No APK was installed on the
user's A063, and no device music data was touched. Do not describe widget
coverage or a successful APK build as native-device validation.
