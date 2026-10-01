# App Deploy Screenshots

[![pub package](https://img.shields.io/pub/v/app_deploy_screenshots.svg)](https://pub.dev/packages/app_deploy_screenshots)

Store-ready App Store and Google Play screenshots from your Flutter widget tests. Render every required size, add a captioned frame, point out features, and get light, dark and every locale from one call.

![Store screenshots made by this package: a framed light English screenshot, a dark French one, a tilted Android one and an annotated one](https://raw.githubusercontent.com/SupposedlySam/app_deploy_screenshots/main/doc/images/hero.png)

Every screenshot above was rendered by the [example app](example/)'s widget test. No simulator, no design tool.

## Features

- 🏪 **Exact store sizes**: presets for every size App Store Connect and Google Play ask for, written as 24-bit PNGs with no alpha, as the stores require
- 🖼️ **Marketing frames**: background, headline, rounded screen and bezel, at the exact store pixel size
- 📶 **Clean status bar**: 9:41, full battery, full signal, coloured to match the app
- 🔦 **Annotations**: spotlights, callouts and magnifier insets placed by `Finder`, so they follow the widget on every device
- 🌗 **Variants**: light, dark and every locale in one call
- 🗂️ **Review**: store-order file names, a contact sheet per device, a `manifest.json`, and a check for Google Play's 20% text guidance
- 📱 **Any device**: 20 built-in device profiles, or define your own
- ⏱️ **Works with screens that never settle**: spinners and pulses are fine

## Installation

```yaml
dev_dependencies:
  app_deploy_screenshots: ^1.1.0
```

```bash
flutter pub get
```

## Quick start

### 1. Initialise once

Create `test/flutter_test_config.dart`. Flutter runs it before every test in the folder:

```dart
import 'dart:async';

import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await AppDeployScreenshots.initialize();
  return testMain();
}
```

This loads your app's fonts, so text renders in real fonts instead of the test font's black boxes. You can call `initialize()` in `setUpAll` instead.

### 2. Write a screenshot test

```dart
import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/main.dart';

void main() {
  testWidgets('store screenshots', (tester) async {
    await tester.pumpWidget(const MyApp());

    await AppDeployScreenshots.forStores(tester, 'home', order: 1);
  });
}
```

### 3. Run it

```bash
flutter test test/store_screenshots_test.dart
```

You get one image per store upload slot:

```
app_deploy_screenshots/
├── ios/
│   ├── app_store_iphone_6_9/01_home.png     1320 × 2868
│   └── app_store_ipad_13/01_home.png        2064 × 2752
└── android/
    ├── play_store_phone/01_home.png         1080 × 1920
    ├── play_store_tablet_7/01_home.png      1224 × 2176
    └── play_store_tablet_10/01_home.png     1620 × 2880
```

If your screen has a running animation, add `customPump`. See [Screens that never settle](#screens-that-never-settle).

## Store artwork

Every option below works with `forStores`, `byDevices`, `byPlatform` and `byDevice` (which takes a single `variant`), and they combine freely. This is the test from the [example app](example/test/store_screenshots_test.dart), trimmed:

```dart
const headlines = {
  'en': ('All your chats, one inbox', 'Fast, private and beautifully simple'),
  'fr': ('Toutes vos discussions', 'Rapide, privé et simple'),
};

testWidgets('store screenshots', (tester) async {
  await tester.pumpWidget(const ChatApp());

  await AppDeployScreenshots.forStores(
    tester,
    'inbox',
    order: 1,
    customPump: (t) => t.pump(const Duration(milliseconds: 100)),
    variants: ScreenshotVariant.matrix(
      brightnesses: [Brightness.light, Brightness.dark],
      locales: [const Locale('en'), const Locale('fr')],
    ),
    statusBar: const StatusBarOverlay(),
    annotations: [
      Callout(find.byIcon(Icons.search), 'Find any chat instantly'),
    ],
    frame: ScreenshotFrame.builder((context) {
      final (headline, subheadline) = headlines[context.locale.languageCode]!;
      return MarketingFrame(
        background: FrameBackground.gradient(
          LinearGradient(
            colors: context.brightness == Brightness.dark
                ? const [Color(0xFF1E1B4B), Color(0xFF0B0B12)]
                : const [Color(0xFFE0E7FF), Color(0xFFFDF2F8)],
          ),
        ),
        caption: Caption(headline: headline, subheadline: subheadline),
      );
    }),
  );

  await AppDeployScreenshots.writeReport(tester: tester);
});
```

### Store sizes

![The same screen at every store size: iPhone 6.9", iPad 13", Play phone, 7" and 10" tablets](https://raw.githubusercontent.com/SupposedlySam/app_deploy_screenshots/main/doc/images/store_sizes.png)

| Preset | Pixels | Store slot |
| --- | --- | --- |
| `Device.appStoreIphone69` | 1320 × 2868 | iPhone 6.9". Required for iPhone apps; App Store Connect scales it down for smaller iPhones. |
| `Device.appStoreIpad13` | 2064 × 2752 | iPad 13". Required for iPad apps; scaled down for smaller iPads. |
| `Device.playStorePhone` | 1080 × 1920 | Phone, 9:16 |
| `Device.playStoreTablet7` | 1224 × 2176 | 7" tablet, 9:16, 612 dp wide |
| `Device.playStoreTablet10` | 1620 × 2880 | 10" tablet, 9:16, 810 dp wide |

`Device.appStore` and `Device.playStore` group them, and `forStores` uses both by default. Pass `devices:` to choose, e.g. `devices: Device.appStore` for an iOS-only app.

Google Play rejects a screenshot whose long side is more than twice its short side, so a native 20:9 capture (1080 × 2400) is not accepted. To show a tall phone on Play, render a tall `Device` and set `MarketingFrame(canvasSize: Size(1080, 1920))`.

Every screenshot is written as a 24-bit PNG with no alpha channel. Google Play asks for this, and App Store Connect asks for flattened images.

### Marketing frames

`MarketingFrame` renders the app at the device's real logical size, so layouts are genuine, then composites the finished image onto a canvas at the exact store pixel size.

| Parameter | What it does |
| --- | --- |
| `background` | `FrameBackground.solid(color)`, `.gradient(gradient)`, `.image(bytes)` or `.custom((canvas, size) {...})` |
| `caption` | `Caption(headline:, subheadline:)`. Pass your app's font in `headlineStyle` / `subheadlineStyle`, and `textDirection: TextDirection.rtl` for right-to-left languages. |
| `layout` | `FrameLayout.captionTop` (default), `.captionBottom`, or `.tilted` (rotated by `tilt`, running off the bottom) |
| `bezel` | A plain rounded-rectangle `DeviceBezel()` with no manufacturer artwork to license, or `null` for rounded corners only |
| `canvasSize` | Output size in pixels. Defaults to the device's pixel size. |
| `referenceSize` | The canvas that caption sizes are designed for (default 440 × 956, the 6.9" iPhone). Caption font sizes, margins and gaps scale by canvas area, so a caption covers the same share of the image on a phone and on a 13" iPad. |

`ScreenshotFrame.builder((context) => ...)` builds a frame per screenshot from `context.locale`, `context.brightness`, `context.device`, `context.name` and `context.order`. Return `null` to leave a screenshot unframed.

### Status bar

`StatusBarOverlay()` draws a clean iOS or Android status bar into the device's top safe area: `9:41`, full signal, full Wi-Fi, full battery. A widget test otherwise has no status bar at all.

The icons are dark or light to match the `SystemUiOverlayStyle` your app publishes (an `AppBar` does this for you), as on a real phone. Override them with `iconBrightness:`, and change the clock with `time:`.

### Annotations

![Left: a spotlight on the compose button, a callout on search and a magnified chat row. Right: the plain screenshot with a status bar.](https://raw.githubusercontent.com/SupposedlySam/app_deploy_screenshots/main/doc/images/annotations.png)

```dart
annotations: [
  Spotlight(find.byKey(const Key('compose'))),
  Callout(find.byIcon(Icons.search), 'Find any chat instantly'),
  MagnifierInset(find.text('Photos from the hike')),
],
```

- `Spotlight(finder)` dims everything except the target.
- `Callout(finder, 'text')` draws a speech bubble with an arrow pointing at the target. `placement:` is `CalloutPlacement.auto` (above the target in the lower half of the screen, below it in the upper half), `.above` or `.below`.
- `MagnifierInset(finder, zoom: 1.4)` enlarges the target into an inset, with `shape: MagnifierShape.roundedRect` (the default) or `.circle`. Inside a frame the inset can extend past the device's edges.

Annotations find their target after the device's overrides and pumps, so they follow the widget at every screen size. A finder that matches nothing throws rather than silently leaving the annotation out. Spotlights are drawn first, then callouts, then magnifier insets on top, so keep a magnifier away from a callout it would cover.

### Variants

![The inbox in light and dark, English and French](https://raw.githubusercontent.com/SupposedlySam/app_deploy_screenshots/main/doc/images/variants.png)

```dart
variants: [ScreenshotVariant.light, ScreenshotVariant.dark],

// or every combination:
variants: ScreenshotVariant.matrix(
  brightnesses: [Brightness.light, Brightness.dark],
  locales: [const Locale('en'), const Locale('fr')],
),
```

Each variant adds a suffix to the file name: `01_inbox.dark.fr.png`. Brightness and locale are applied through the platform (`platformBrightness` and `locales`), as on a device, so an app that uses `ThemeMode.system` and the system locale needs nothing else. An app that keeps these in its own state can read them in `deviceSetup` from `tester.platformDispatcher`.

When the brightness changes between captures, the package steps through 600 ms of frames so chained theme animations finish. Without that, text could keep the previous theme's colour.

### Review: contact sheets, manifest and the 20% check

![A contact sheet: every iPhone screenshot in one image](https://raw.githubusercontent.com/SupposedlySam/app_deploy_screenshots/main/doc/images/contact_sheet.png)

`await AppDeployScreenshots.writeReport(tester: tester)` writes:

- `_review/<platform>__<device>.png`: one contact sheet per device folder, to check a whole listing at a glance. They live in `_review/` so upload tools that take every PNG in a device folder don't pick them up.
- `manifest.json`: every screenshot with its path, device, pixel size, order, locale, brightness and caption coverage. Test files run in separate isolates, so each call merges with the existing manifest.

It also checks Google Play's guidance that text should cover no more than 20% of a screenshot. Every Play screenshot whose caption covers more than `playCaptionCoverageLimit` (default `0.2`) is printed and returned. It only warns and never fails; pass `null` to skip the check.

Call it at the end of a test with `tester:`, or in `tearDownAll` without it.

### Emoji

The test renderer can't draw colour emoji and doesn't fall back between fonts on its own, so emoji render as empty boxes. `initialize()` loads a bundled monochrome Noto Emoji font (SIL Open Font License 1.1). Name it as a fallback in your theme:

```dart
ThemeData(
  fontFamilyFallback: const [AppDeployScreenshots.emojiFontFamily],
)
```

This is safe to leave in a production theme: on a device the family doesn't exist, so it's skipped and the system emoji font is used. The font is read from the package at test time and isn't declared as a Flutter font, so it adds nothing to your app's release build.

## Capturing screens

| Method | Captures |
| --- | --- |
| `forStores(tester, name)` | Every store preset into `app_deploy_screenshots/<platform>/<device>/`. Set `root:` to change the folder and `devices:` to choose presets. |
| `byDevices(tester, name, devices: [...])` | Any list of devices (default: iPhone 16 Pro and iPad Pro M4) into `app_deploy_screenshots/<device>.<name>.png`, or the path from `fileNameBuilder` |
| `byPlatform(tester, name)` | All 20 built-in devices, including Mac, Apple TV, Vision Pro and Android TV, into `app_deploy_screenshots/<platform>/<size>_<device>/` |
| `byDevice(tester, name, device:, fileName:)` | One device to an exact path |

All of them take the store artwork options above (`statusBar`, `annotations`, `frame`, `order`). The multi-device methods take a list of `variants`; `byDevice` takes a single `variant`. All of them also take these:

| Parameter | What it does |
| --- | --- |
| `customPump` | Replaces the default `pumpAndSettle` after setup |
| `deviceSetup` | `(device, tester) async {...}`, run for each device under its overrides, before `customPump` |
| `finder` | Captures one widget instead of the whole screen |

`byDevices` and `byPlatform` also take `fileNameBuilder: (device) => 'path/name.png'`. The order prefix and variant suffix are added to the file name for you.

Each method returns a `ScreenshotRecord` per image written (`List` for the multi-device methods), with its path, pixel size and context.

### Screens that never settle

The default pump is `pumpAndSettle`, which never returns while an animation is running: a progress indicator, a pulsing dot, a looping video. Pass a fixed pump instead:

```dart
customPump: (tester) => tester.pump(const Duration(milliseconds: 100)),
```

Apart from that default, the package never waits for the screen to settle, so a fixed pump is all a never-settling screen needs.

### Per-device setup

```dart
await AppDeployScreenshots.byDevices(
  tester,
  'responsive_layout',
  devices: [Device.iphone16Pro, Device.ipadProM4, Device.androidTablet],
  deviceSetup: (device, tester) async {
    await tester.pump();
    if (device.size.shortestSide >= 600) {
      await tester.tap(find.text('Show sidebar'));
      await tester.pump();
    }
  },
);
```

Supplying `deviceSetup` replaces the default setup, which is two pumps, so pump at least once after the device's size changes.

### Capturing one widget

```dart
await AppDeployScreenshots.byDevice(
  tester,
  'checkout_sheet',
  device: Device.iphone16Pro,
  fileName: 'app_deploy_screenshots/checkout_sheet.png',
  finder: find.byType(BottomSheet),
);
```

The widget is captured at the device's pixel ratio, through its nearest `RepaintBoundary`.

### Multi-step flows

```dart
testWidgets('onboarding', (tester) async {
  await tester.pumpWidget(const MyApp());
  await AppDeployScreenshots.forStores(tester, 'welcome', order: 1);

  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
  await AppDeployScreenshots.forStores(tester, 'pick_topics', order: 2);
});
```

### Images

Every capture waits for `Image` widgets and `DecoratedBox` images to finish decoding on each device, then paints one more frame. That's needed because a widget laid out again at a new size can request a new image. To skip the wait, pass `waitForImages: false` to `byDevice`. To prime images yourself, call `AppDeployScreenshots.primeAssets(tester)`.

## Devices

### Store presets

See [Store sizes](#store-sizes): `Device.appStore` and `Device.playStore`.

### Built-in devices

`Device.allDevices` lists the built-in devices, and `byPlatform` captures all of them.

| Device | Pixels |
| --- | --- |
| `Device.iphone16ProMax` | 1290 × 2796 |
| `Device.iphone16Pro` | 1179 × 2556 |
| `Device.iphone14Plus` | 1284 × 2778 |
| `Device.iphone14` | 1170 × 2532 |
| `Device.iphone11` | 414 × 896 |
| `Device.iphone8Plus` | 1242 × 2208 |
| `Device.iphoneSE3` | 750 × 1334 |
| `Device.phone` | 375 × 667 |
| `Device.ipadProM4` | 2064 × 2752 |
| `Device.ipadPro12_9` | 2048 × 2732 |
| `Device.ipadPro11` | 1668 × 2388 |
| `Device.androidPhone` | 1080 × 1920 |
| `Device.androidPhoneWide` | 1920 × 1080 |
| `Device.androidPhoneTall` | 2160 × 1080 |
| `Device.androidPhoneExtra` | 2400 × 1080 |
| `Device.androidTablet` | 2560 × 1600 |
| `Device.androidTV` | 1920 × 1080 |
| `Device.macDefault` | 1440 × 900 |
| `Device.appleTV` | 1920 × 1080 |
| `Device.visionPro` | 3840 × 2160 |

`Device.byPlatform(DevicePlatform.ios)` filters them by platform, and `Device.byDisplaySize(DisplaySize.sixNine)` filters the iPhones and iPads by screen size.

### Custom devices

```dart
const tallAndroid = Device(
  name: 'android_20_9',
  size: Size(360, 780), // logical points
  devicePixelRatio: 3, // 1080 × 2340 pixels
  safeArea: EdgeInsets.only(top: 32, bottom: 24), // logical points
  displaySize: DisplaySize.sixFive,
  platform: DevicePlatform.android,
  screenCornerRadius: 32, // used by MarketingFrame
);
```

At 1080 × 2340 this phone is too tall for Google Play on its own, so frame it on a Play canvas: `MarketingFrame(canvasSize: Size(1080, 1920))`.

`device.pixelSize` is the capture size in pixels. `device.copyWith(...)` changes any field, `device.dark()` returns a dark copy, and `device.meetsPlayStoreRequirements()` checks Google Play's size rules.

`safeArea` is in logical points, the same values the app reads from `MediaQuery.paddingOf`.

## Store requirements

The presets follow the stores' current specifications:

- **App Store** ([specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)): iPhone 6.9" accepts 1320 × 2868, 1290 × 2796 or 1260 × 2736 and is required for iPhone apps. 6.5" (1284 × 2778 or 1242 × 2688) is needed only without 6.9" screenshots. iPad 13" accepts 2064 × 2752 or 2048 × 2732 and is required for iPad apps. Smaller sizes are scaled from these.
- **Google Play** ([requirements](https://support.google.com/googleplay/android-developer/answer/9866151)): JPEG or 24-bit PNG with no alpha, each side 320–3840 px, and the long side no more than twice the short side. For promotion eligibility, provide at least four screenshots at 1080 px or more, 9:16 portrait or 16:9 landscape.

Only the preset devices are store sizes. The other built-in devices are for previews, docs and layout checks.

## Setup

### Initialisation options

```dart
await AppDeployScreenshots.initialize(
  loadFonts: true, // load the fonts in your pubspec, and Material icons
  loadEmojiFont: true, // load AppDeployScreenshots.emojiFontFamily
  mockPlatformChannels: true, // stub shared_preferences and receive_sharing_intent
  verbose: false, // print each step
);
```

### Fonts

Fonts declared in your `pubspec.yaml`, including those from packages you depend on, are loaded automatically:

```yaml
flutter:
  uses-material-design: true # Material icons
  fonts:
    - family: MyBrandFont
      fonts:
        - asset: fonts/MyBrandFont-Regular.ttf
```

The package also ships Roboto, so apps that use the default Material font render correctly without bundling it.

## Troubleshooting

### Text renders as black boxes

Fonts weren't loaded. Call `AppDeployScreenshots.initialize()` in `flutter_test_config.dart` or `setUpAll`, and check the font is declared in `pubspec.yaml`.

### Icons render as empty squares

Add `uses-material-design: true` under `flutter:` in your `pubspec.yaml`.

### Emoji render as boxes

Add `fontFamilyFallback: const [AppDeployScreenshots.emojiFontFamily]` to your theme. If `initialize()` prints `emoji font not loaded`, the reason follows on the same line.

### The test times out or hangs

Your screen never settles. Pass a fixed `customPump`; see [Screens that never settle](#screens-that-never-settle).

### Screenshots are blank

Make sure the app is pumped before capturing (`await tester.pumpWidget(...)`), and that a `finder` matches an on-screen widget.

### Annotation throws `StateError`

The annotation's finder matched nothing on that device. On a smaller screen the widget may be scrolled out of view; scroll it in with `deviceSetup`.

## Example

[example/](example/) is a small chat app with a screenshot test that uses every feature. Run it from that folder:

```bash
flutter test test/store_screenshots_test.dart
```

## Contributing

Issues and pull requests are welcome on [GitHub](https://github.com/SupposedlySam/app_deploy_screenshots). Run `flutter test` before opening a pull request. To regenerate the README images after a visual change, run `tool/readme_images.sh` (needs ImageMagick).

## License

This project is licensed under the BSD 3-Clause License. See [LICENSE](LICENSE). The bundled Noto Emoji font is under the SIL Open Font License 1.1; see `lib/src/fonts/NotoEmoji-OFL.txt`.
