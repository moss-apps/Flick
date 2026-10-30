---
name: Flick Poster Visual System
description: Scoped record of the implemented onboarding system derived from Flick Replay.
colors:
  acid: "#E3F369"
  signal: "#FF5636"
  ink: "#0A0A0A"
  paper: "#F1F0EB"
typography:
  display:
    fontFamily: "GoogleSansFlex, NotoSansSC, NotoSansTagalog"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "-0.035em"
  body:
    fontFamily: "GoogleSansFlex, NotoSansSC, NotoSansTagalog"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.5
  button:
    fontFamily: "GoogleSansFlex, NotoSansSC, NotoSansTagalog"
    fontSize: "16px"
    fontWeight: 700
  skip:
    fontFamily: "GoogleSansFlex, NotoSansSC, NotoSansTagalog"
    fontSize: "15px"
  progress:
    fontFamily: "GoogleSansFlex, NotoSansSC, NotoSansTagalog"
    fontSize: "13px"
    fontWeight: 700
    letterSpacing: "1px"
  logotype:
    fontFamily: "GoogleSansFlex, NotoSansSC, NotoSansTagalog"
    fontSize: "24px"
    fontWeight: 700
    letterSpacing: "-0.7px"
rounded:
  square: "0px"
  action: "2px"
spacing:
  space-8: "8px"
  space-12: "12px"
  space-16: "16px"
  space-20: "20px"
  space-24: "24px"
  space-32: "32px"
components:
  button-ink:
    backgroundColor: "{colors.ink}"
    typography: "{typography.button}"
    rounded: "{rounded.action}"
    padding: "16px 20px"
  button-acid:
    backgroundColor: "{colors.acid}"
    textColor: "{colors.ink}"
    typography: "{typography.button}"
    rounded: "{rounded.action}"
    padding: "16px 20px"
  button-skip:
    typography: "{typography.skip}"
    rounded: "{rounded.square}"
    padding: "8px 16px"
  progress:
    typography: "{typography.progress}"
  poster-copy:
    typography: "{typography.body}"
---

# Design System: Flick Poster Visual System

## Overview

**Creative North Star: "Utilitarian music posters with motorsport livery"**

Flick's poster visual system combines Replay color fields, large branded type, black livery stripes, dot matrices, and authored record geometry. The official dotted Flick mark anchors the identity; familiar native controls remain distinct from decorative artwork. This records the approved implementation, not a new visual world.

Scope is the onboarding/Replay-derived poster visual system only. Standard player, library, and settings screens retain their existing Material dark theme in `lib/core/theme/app_theme.dart`. Onboarding page order and exact compositions belong to `.impeccable/surfaces/onboarding-screens-onboarding-screen-dart-eb866e34.md`, not universal design rules.

The frozen implementation includes the reviewed font-wrapping fix. The handoff reports 25 passing onboarding tests using bundled fonts, including English/Taglish whole-word regressions at 320 × 568 with 2x text, and a clean targeted analyzer. The full suite has an unrelated Isar binary mismatch. Review PNGs are supplementary Flutter widget renders, not device screenshots or shipping assets. Native Android sign-off remains blocked: the emulator did not boot, the user's phone was untouched, and the final native gate is not closed.

**Key Characteristics:**
- Flat Replay color fields and foreground-tinted rules.
- Large left-aligned type, livery stripes, dot matrices, and authored record geometry.
- Scrollable copy/art with stable native navigation and finite motion.

Source authority: `lib/features/onboarding/screens/onboarding_screen.dart`, `lib/features/onboarding/widgets/onboarding_poster.dart`, `lib/features/onboarding/widgets/onboarding_graphics.dart`, `lib/features/recap/widgets/replay_style.dart`, `lib/core/theme/app_theme.dart`, `pubspec.yaml`, and `assets/icons/flicklogo_svg.svg`. Frontmatter contains only primitives used by this scope, not every Replay or app-theme token. Its `px` notation transcribes native logical dimensions; font sizes are before Flutter text scaling.

## Colors

The normative values are in frontmatter; the palette is high-contrast print color, not a new app-wide color scheme.

### Primary
- **Acid:** bright poster fields, graphic accents, and primary actions on ink fields.

### Secondary
- **Signal:** warm poster fields and graphic accents; not an onboarding error-state token.

### Neutral
- **Ink:** dark fields, foreground on light/colored fields, black stripes, and filled actions.
- **Paper:** light fields and foreground on ink fields.

On acid, paper, or signal fields, the filled action is ink with its label matching the field. On ink fields, the action is acid with an ink label. Header/footer rules use foreground at 30% opacity; inactive progress dots use 25%, while the current dot is opaque. These are derived treatments, not additional palette ramps.

**The Field Contrast Rule.** Choose the foreground and action pairing for its actual field; do not use color alone to identify progress.

## Typography

Use bundled **GoogleSansFlex**, with explicit **NotoSansSC**, then **NotoSansTagalog** fallbacks from `AppTheme.fontFamilyFallback`; missing glyphs can continue to platform fallback. `pubspec.yaml` bundles Google Sans Flex regular/bold and italic/bold-italic, Noto Sans SC regular/bold, and Noto Sans Tagalog regular. No font download, new family, or runtime variable-font axis is implied.

- **Display:** bold, tight, left-aligned headings using the display primitives. Size is computed below, not a universal CSS viewport clamp.
- **Body:** readable guidance using the body primitives; preserve supplied localized line breaks and natural wrapping.
- **Controls/progress:** use the button, skip, and progress roles. Progress combines a numeric count with dots.
- **Logotype:** italic, bold `Flick`, in a 60dp-wide scale-down box. This fixed brand treatment alone uses `TextScaler.noScaling`; it is not guidance copy.

For the poster's local constrained viewport `W × H`, copy width `w` is `(W - 80) / 2` in the wide branch, otherwise `W - 48`. Enlarged text means `MediaQuery.textScalerOf(context).scale(16) > 21`:

- Normal base display size: `clamp(w × 0.17, 44, w >= 600 ? 96 : 72)`.
- Enlarged reading-tier base: `clamp(w × 0.115, 30, 44)`.
- Only enlarged headings invoke `_fitHeading`: `TextPainter` uses actual direction, locale, and the unchanged actual `TextScaler`, including nonlinear scaling. Accept the base if `minIntrinsicWidth <= w - 1`; otherwise perform eight bounded bisections between 16 and the base, keeping the largest measured fitting candidate. Intrinsic measurement respects localized word/line boundaries.
- Letter spacing is always `-0.035 × fittedFontSize` in logical pixels. The selected base is still scaled by Flutter; the fitter does not replace or cap the user's scaler.

**The Scaled Copy Rule.** Keep the actual TextScaler on guidance and controls; fit enlarged headings by measurement rather than truncating words or suppressing scaling.

## Layout

Android-only, minSdk 26. A `SafeArea` contains a stable header, an expanded horizontal `PageView`, and a ruled footer outside the poster's vertical scroll. Header, poster, and footer are centered within a maximum width of 960dp, with 24dp horizontal padding. Status/navigation icon brightness follows the current field; the status bar is transparent and the navigation bar matches the field.

- **Wide gate:** local poster `W >= 620 && W > H`, not width alone. The wide branch places copy and art in equal expanded columns with a 32dp gap and 24dp padding; art height is `clamp(H, 200, 400)`.
- **Stacked branch:** 20dp top and 24dp bottom padding, 24dp between blocks, and 20dp between a grouped heading/body. Art height is `clamp(H × 0.44, 176, W >= 620 ? 520 : 300)`. Portrait tablets retain the stacked treatment with larger art rather than switching solely at 620dp. Page-specific block order stays in the surface brief/source.
- **Footer:** 16dp top and 20dp bottom padding. Stack progress above a full-width action, separated by 12dp, when the footer's inner available width is below 320dp **or** `textScaler.scale(16) > 21`. Otherwise use a horizontal row with at least a 16dp gap. The width test is after frame padding, not the device width.

Short windows scroll the poster, never the pinned action. No heading/body ellipsis, fixed copy height, or suppressed copy scaling is used.

## Elevation & Depth

This poster world is flat: color fields, foreground-tinted rules, overlapping vector shapes, and record grooves supply structure. There are no poster shadows, glass, gradients, or glow. Decorative drawing is clipped to its art viewport; copy remains in native layout. Existing Material button feedback is retained, not replaced with ornamental lift.

**The Flat Poster Rule.** Keep this poster world free of shadows, glass, gradients, and glow; this is not a prohibition on unrelated app surfaces.

## Shapes

Use square graphic blocks, thin rules, diagonal livery stripes, circular records, and dot matrices. The primary action has only the small `action` radius; Skip is square. Footer rules are 1dp. Progress dots are 7dp with 8dp right spacing. Record grooves are strokes, not gradients; registration crosses and overlaps are decorative, not data.

The official mark has **18 dots**, preserving its **606:734** aspect. `_logoDots` holds the SVG's transformed circle centers normalized as `x / 606`, `y / 734`; the drawn radius is `bounds.width × (29.4994 / 606)`. Preserve all positions and the original silhouette from `assets/icons/flicklogo_svg.svg`, including when recoloring to the current field's foreground/background. Do not substitute a generic dotted letter. The painter centers and uniformly fits a clipped 360 × 244 artboard; the artboard is not the mark's aspect ratio.

## Components

- **Header:** fixed italic wordmark, a flexible foreground rule, and a native `TextButton` Skip target of at least 48 × 48dp. On the last page, a 48 × 48dp placeholder preserves the header geometry.
- **Primary action:** native `FilledButton`, minimum 144 × 56dp, 20dp horizontal/16dp vertical padding, a flexible localized label, a 20dp gap, and a 20dp right-arrow icon. Next advances; Get Started completes. Material supplies hover, focus, pressed, disabled, and ink feedback; there is no bespoke runtime state-color ramp.
- **Progress/footer:** the real five-step count is shown as `01 / 05` through `05 / 05`. A live-region `Semantics` value announces `1 / 5` through `5 / 5`; visual count/dots are excluded from duplicate semantics. Dots are not buttons.
- **Poster/copy:** native `Text`, with heading semantics, inside a vertical `SingleChildScrollView`. Preserve English and Simplified Chinese guidance; Taglish retains its supplied welcome title and English guidance/controls. Horizontal swiping, Next, optional Skip, completion persistence, and tutorial auto-start handoff remain intact.
- **Graphic:** authored `CustomPainter` vectors within `RepaintBoundary` and `ExcludeSemantics`. Records, matrices, stripes, and the mark are artwork, not fabricated library items, telemetry, or interactive playback controls. No newly produced shipping raster assets are involved.

**Finite motion:** the graphic reveals once per mounted graphic's first active presentation (650ms). Main geometry uses `Curves.easeOutQuart`; mark dots use `Interval(i × 0.012, 0.72 + i × 0.012, curve: Curves.easeOutQuart)`. Page advance and background-field transitions use 300ms with `Curves.easeOutCubic`. `MediaQuery.disableAnimations` or app animations being disabled (`AppConstants.animationNormal == Duration.zero`) presents finished static artwork, makes Next jump immediately, and removes the field transition. Inactive graphics are settled; returning does not restart a played reveal. Native Material tap feedback can still settle independently.

`.impeccable/design.json` contains six self-contained, `ds-`-prefixed HTML/CSS **reference translations** for the documentation panel, not a new Flutter implementation. Values are resolved literally because native tokens are not CSS variables. Panel focus outlines/state layers are accessible web equivalents, not claims about Android rendering; fonts fall back to the browser sans-serif if the bundled families are unavailable. The copy sample is a fixed native-size snapshot, not a replacement sizing algorithm. The footer's container query translates the width branch only; nonlinear text scaling and the native text-scale branch remain authoritative in Dart. Static artwork shows the final reveal pose. These references do not close the native verification gap.

## Do's and Don'ts

### Do:
- **Do** preserve Replay color roles, bundled font fallbacks, and the official 18-dot mark.
- **Do** keep actual localized copy scaling, measured enlarged-heading fitting, and reachable native actions.
- **Do** keep decoration semantic-free and progress tied to the real onboarding state.
- **Do** distinguish supplementary widget renders from outstanding native Android verification.

### Don't:
- **Don't** re-theme standard player, library, or settings screens from this scoped poster record.
- **Don't** promote onboarding page order or a page's exact composition into universal rules.
- **Don't** truncate guidance, suppress its TextScaler, or replace the fitter with a CSS viewport clamp.
- **Don't** invent listening data, audio claims, services, ads, dependencies, or fonts to decorate onboarding.
