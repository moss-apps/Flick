---
version: 1
slug: "onboarding-screens-onboarding-screen-dart-eb866e34"
primary_target: "lib/features/onboarding/screens/onboarding_screen.dart"
related_targets: ["lib/features/onboarding/widgets/onboarding_poster.dart","lib/features/onboarding/widgets/onboarding_graphics.dart"]
---

# Onboarding

Scope: `lib/features/onboarding/screens/onboarding_screen.dart` and its poster widgets.
Visitor mode: Persuade. First-time listeners should understand Flick, recognize
their local-library workflow, and enter the app without a required setup task.

Preserve the five existing steps, localized copy, swipe/Next/Skip controls,
completion preference, and tutorial auto-start handoff. Support Android safe
insets, small/landscape/tablet windows, scalable text, and reduced motion.
No fabricated library, playback telemetry, new dependencies, or audio changes.
The user approved the poster direction with “Let's do it”; retain the existing
five-step story rather than treating that approval as a request to rewrite it.

## Direction contract

**THESIS:** Five working music posters, not five centered icon cards. The dotted
Flick mark and livery stripes make the first welcome unmistakably Flick.

**OWN-WORLD:** Inherit Replay's ink, acid, paper, and signal roles. Flat fields,
bold branded type, precise rules, dot matrices, angular stripes, and authored
record geometry; no glow, glass, fake readouts, or racing-dashboard costume.

**STORY:** Welcome → build a library → browse → playback → enter Flick.
Each page changes composition; stable native controls keep the route obvious.

**FIRST VIEWPORT:** Acid fills the phone. An oversized left-aligned welcome
heads a large dotted mark assembling at the right of a black-striped graphic.
The existing body remains readable below. A ruled footer holds real five-step
progress and an unmistakable black Next button; Skip stays top-right.
Short windows scroll the poster, never the pinned action.

**FORM:** User-pinned utilitarian music-poster / motorsport-livery direction;
code-led native screen. No concept roll was needed for the approved direction.
seed: none (user-pinned). One-shot dot assembly and stripe travel replace the
old endlessly breathing glow; reduced motion presents the finished artwork.

**FINISH:** unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
