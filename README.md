# Month-Day

<p align="center">
  <img src="docs/icon.png" alt="M-D app icon" width="160">
</p>

**M-D** (Month-Day) is a tiny Apple Watch app that puts today's date on your watch face as plain numbers, in a retro digital-watch style: month first like `10/01/2026`, or day first like `01/10/2026`.

![M-D complications on a watch face](docs/complications.png)

## Features

### Complications

| Slot | What it shows |
|---|---|
| **Circular** | `10/01` (or `01/10`) with `2026` underneath |
| **Rectangular** | Day of the week, then `10/01/2026` in big digits |
| **Corner** | `10/01`, with the year on the curved label |
| **Inline** | `10/01/2026` |

When you add the complication, pick the style you like. Examples are for October 1, 2026:

| Style | Month first | Day first |
|---|---|---|
| Slash | `10/01/2026` | `01/10/2026` |
| Dash | `10-01-2026` | `01-10-2026` |
| Dot | `10.01.2026` | `01.10.2026` |
| Dot, short year | `10.01.26` | `01.10.26` |
| No leading zeros | `10/1/2026` | `1/10/2026` |

- **Flips at your local midnight, anywhere.** The complication checks in every 15 minutes and always uses the watch's *current* time zone. Every time zone on Earth is a multiple of 15 minutes from UTC, so the date changes at exactly 12:00 AM local time, even right after you fly to another country, including half-hour zones like India and Nepal's +5:45.
- **Always month/day/year.** It uses the regular (Gregorian) calendar even if your watch is set to a different calendar system, so the numbers are never confusing.
- **Retro look.** Monospaced digits tinted LCD green, which follows your watch face's color when the face is tinted.

### Watch app

A retro LCD-style screen showing today's date and day of the week, with quick steps for adding the complication. Tap the date to switch between month first and day first.

## Add it to your watch face

1. Touch and hold your watch face, then tap **Edit**.
2. Swipe to **Complications** and tap a slot.
3. Choose **M-D**, then pick a style: **Month first** or **Day first**.

## Requirements

- Apple Watch on **watchOS 27** or later (watch-only app, no iPhone app needed)
- **Xcode 27** or later
- Built with SwiftUI, WidgetKit and App Intents. No third-party dependencies.

## Build & run

1. Open `M-D.xcodeproj` in Xcode.
2. Under **Signing & Capabilities**, choose your own Team for both targets: **M-D Watch App** and **MDWidgetsExtension**. Change the bundle identifiers if needed.
3. Pick the **M-D Watch App** scheme and your Apple Watch (or a watch simulator), then press **▶ Run**.
4. Add the complication to a watch face (see above).

## Project structure

```
M-D Watch App/          The watch app (retro LCD date screen)
  ContentView.swift
  M_DApp.swift
  Assets.xcassets/      App icon and accent color
MDWidgets/              WidgetKit extension with the complications
  MDWidgets.swift       Date styles, timeline, complication views
  Info.plist
docs/                   Images for this README
```

## Privacy

M-D has no accounts, ads, analytics or network code, and asks for no permissions. It only reads the watch's own date and time zone. For the App Store privacy label, this app is **Data Not Collected**.

## Author

Created by Senalbert Rodriguez.

## License

M-D is free and open source under the [MIT License](LICENSE). You're welcome to use it, learn from it, change it and share it. Just keep the copyright notice.
