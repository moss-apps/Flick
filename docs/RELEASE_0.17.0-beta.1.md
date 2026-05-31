# Flick 0.17.0-beta.1

0.17.0-beta.1 brings player layout customization, a BitPerfect status indicator, a reworked paged equalizer layout, and improved folder filtering and sorting controls.

## Overview

This beta adds four headline features:

1. **BitPerfect capsule/indicator** — visual status capsule in the player UI showing when bit-perfect audio is active
2. **Player layout settings** — configurable player layout options accessible from settings
3. **Equalizer paged layout** — 31-band equalizer redesigned with a paged navigation layout for smoother band browsing
4. **Folder filter/sort controls** — dedicated filtering and sorting controls for folder listings

## Highlights

- **BitPerfect indicator**: A status capsule displayed in the player UI when the bit-perfect audio path is engaged. Provides at-a-glance confirmation that audio is bypassing Android's resampler.
- **Player layout settings**: New settings screen for customizing the player layout. Choose how playback information and controls are arranged.
- **Paged equalizer**: The 31-band equalizer now uses a paged layout, making it easier to navigate across the full frequency range without excessive scrolling. Each page presents a group of bands for adjustment.
- **Folder filter/sort**: Enhanced folder browsing with dedicated filter and sort controls. Narrow down folder listings and sort by multiple criteria with persistent preferences.

## What's New

### BitPerfect Capsule/Indicator

- BitPerfect status capsule widget displayed in the player UI
- Visual indicator showing when bit-perfect mode is active
- Updates in real-time as the audio path changes

### Player Layout Settings

- New player layout configuration screen
- Options for customizing the player arrangement
- Persistent layout preferences across sessions

### Equalizer Paged Layout

- 31-band equalizer redesigned with paged navigation
- Each page displays a subset of bands for focused adjustment
- Smoother browsing across the full 20 Hz – 20 kHz frequency range
- Preserves existing per-band gain and Q controls

### Folder Filter/Sort Controls

- Dedicated filter controls for narrowing folder listings
- Enhanced sort options with multiple criteria
- Persistent filter and sort preferences
- Improved folder browsing workflow

## Files Changed

| Area | Key Paths |
| --- | --- |
| BitPerfect | Player UI capsule/indicator widgets |
| Player Layout | Player layout settings screen |
| Equalizer | Paged equalizer layout |
| Folders | Folder filter and sort controls |

## Upgrading

1. BitPerfect indicator appears automatically when bit-perfect mode is active
2. Player layout settings are accessible from the settings screen
3. Equalizer paged layout replaces the previous scrollable layout
4. Folder filter/sort controls are available in the folder browser
