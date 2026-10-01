# App Deploy Screenshots

[![pub package](https://img.shields.io/pub/v/app_deploy_screenshots.svg)](https://pub.dev/packages/app_deploy_screenshots)

Your whole App Store and Google Play listing, from a Flutter widget test: framed screenshots of the real app at every store size, posters and slides built from widgets, light, dark and every locale, written where fastlane uploads them.

![Four store slides made by this package: a welcome poster, the inbox with one chat lifted off the screen, a tilted conversation, and two phones side by side](https://raw.githubusercontent.com/SupposedlySam/app_deploy_screenshots/main/doc/images/2.0/listing.png)

Every image in this README was rendered by the [example app](example/)'s tests. No simulator, no design tool.

## Features

- 🏪 **Exact store sizes**: every size App Store Connect and Google Play ask for, as 24-bit PNGs with no alpha, as the stores require
- 📚 **A whole listing in one test**: the design set once, slides numbered in the order you add them
- 🖼️ **Store artwork**: backgrounds, captions with highlighted words, devices with a Dynamic Island, side buttons and shadow, running off the edge or tilted
- 🧩 **Slides from widgets**: posters, two phones side by side, and panoramas that run across several slides, laid out with ordinary Flutter
- 🔦 **Annotations**: lift, spotlight, callout or magnify a widget, found by `Finder` so they follow it on every device
- 🌗 **Variants**: light, dark and every locale, right to left included
- 🚀 **fastlane-ready**: written straight into the folders `deliver` and `supply` upload from, checked before anything is captured
- 🗂️ **Review**: a contact sheet per device, a `manifest.json`, and a check for Google Play's 20% text guidance

## Installation

```yaml
dev_dependencies:
  app_deploy_screenshots: ^2.0.0
```

Upgrading from 1.x? See the [migration notes](CHANGELOG.md#migrating-from-1x).

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

This loads your app's fonts, so text renders in real fonts instead of the test font's black boxes.

### 2. Write a screenshot test

```dart
import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/main.dart';

void main() {
  testWidgets('store screenshots', (tester) async {
    await tester.pumpWidget(const MyApp());

    final listing = StoreListing(tester);
    await listing.screenshot('home');
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

If the test hangs, your screen has a running animation: see [Screens that never settle](#screens-that-never-settle).

## A store listing

`StoreListing` is the shortest way to a finished listing. Set the devices, variants, design, status bar and output once, then add slides in the order the store should show them. This is the [example app's test](example/test/store_screenshots_test.dart), which made the images at the top, trimmed to two slides:

```dart
/// The shared design. `shot` says which device, locale and brightness.
MarketingFrame design(ScreenshotContext shot) => MarketingFrame(
  background: FrameBackground.gradient(brandGradient(shot)),
  layout: const FrameLayout.bleed(),
  device: const DeviceStyle.detailed(),
);

testWidgets('store listing', (tester) async {
  await tester.pumpWidget(const ChatApp());

  final listing = StoreListing(
    tester,
    variants: ScreenshotVariant.matrix(
      brightnesses: [Brightness.light, Brightness.dark],
      locales: [const Locale('en', 'US'), const Locale('fr', 'FR')],
    ),
    frame: ScreenshotFrame.builder(design),
    statusBar: const StatusBarOverlay(),
    customPump: (t) => t.pump(const Duration(milliseconds: 100)),
  );

  // 01: the inbox, with one chat lifted off the screen.
  await listing.screenshot(
    'inbox',
    caption: const Caption(
      headline: 'All your chats, **one inbox**',
      emphasis: CaptionEmphasis.marker(brand, textColor: Colors.white),
    ),
    annotations: [Lift(find.byKey(ChatApp.photosKey))],
  );

  // 02: into a conversation, on a tilted device.
  await tester.tap(find.text('Priya Patel'));
  await tester.pump(const Duration(seconds: 1));
  await listing.screenshot(
    'conversation',
    captionFor: (shot) => Caption(
      headline: shot.locale.languageCode == 'fr'
          ? 'Partagez les **moments qui comptent**'
          : 'Share the **moments that matter**',
      emphasis: const CaptionEmphasis.color(Colors.orange),
    ),
    frame: ScreenshotFrame.builder(
      (shot) => design(shot).copyWith(layout: const FrameLayout.bleed(angle: -6)),
    ),
  );

  await listing.writeReport();
});
```

- Each slide is numbered as it is added (`01_inbox`, `02_conversation`), which is the order the stores show them.
- `caption:` gives a slide its words. `captionFor:` builds them per screenshot, from `shot.locale`, `shot.brightness` and `shot.device`. Either way the slide keeps the listing's design and its caption styling.
- Anything set on the listing (`frame`, `statusBar`, `customPump`, `deviceSetup`) can be passed again on one slide to change it there.
- `listing.poster`, `listing.widget` and `listing.panorama` add [slides that aren't screenshots](#slides-from-widgets), numbered the same way.

The static methods (`AppDeployScreenshots.forStores`, `widgetForStores`, `posterForStores`, `panoramaForStores`) do the same work one slide at a time, with an explicit `order:`.

## Store sizes

![The same screen at every store size: iPhone 6.9", iPad 13", Play phone, 7" and 10" tablets](https://raw.githubusercontent.com/SupposedlySam/app_deploy_screenshots/main/doc/images/2.0/store_sizes.png)

| Preset | Pixels | Store slot |
| --- | --- | --- |
| `Device.appStoreIphone69` | 1320 × 2868 | iPhone 6.9". Required for iPhone apps; App Store Connect scales it down for smaller iPhones. |
| `Device.appStoreIpad13` | 2064 × 2752 | iPad 13". Required for iPad apps; scaled down for smaller iPads. |
| `Device.playStorePhone` | 1080 × 1920 | Phone, 9:16 |
| `Device.playStoreTablet7` | 1224 × 2176 | 7" tablet, 9:16 |
| `Device.playStoreTablet10` | 1620 × 2880 | 10" tablet, 9:16 |
| `Device.playStorePhoneTall` | 1080 × 2400 | Phone, 20:9. Not in `Device.playStore`; see below. |
| `Device.playStoreWear` | 454 × 454 | Wear OS. Play asks for these unframed. |
| `Device.playStoreChromebook` | 1920 × 1080 | Chromebook, 16:9 |

`Device.appStore` and `Device.playStore` group the required sizes, and are the default devices. Pass `devices:` to choose, e.g. `devices: Device.appStore` for an iOS-only app.

Google Play's documented limit is a long side no more than twice the short side, which a native 20:9 phone (1080 × 2400) breaks. Several top apps have screenshots that tall live on Play, but `Device.playStorePhone` (9:16) is the safe choice and also qualifies for promotional placement. To show a tall phone on a 9:16 slide, capture on `Device.playStorePhoneTall` and frame it with `MarketingFrame(canvasSize: Size(1080, 1920))`.

## Store artwork

A `MarketingFrame` renders the app at the device's real logical size, so layouts are genuine, then draws the finished screen inside a device on a canvas at the exact store pixel size.

```dart
MarketingFrame(
  background: FrameBackground.gradient(myGradient),
  caption: Caption(headline: 'All your chats, **one inbox**'),
  layout: FrameLayout.bleed(),
  device: DeviceStyle.detailed(),
)
```

Pass it as `frame:`, or `ScreenshotFrame.builder((shot) => ...)` to vary it by locale, brightness or device. Return `null` from the builder to leave a screenshot unframed.

### Layouts

![Five layouts: caption on top, a device running off the bottom, the same tilted, a cropped screen with the caption below, and the app's own screen blurred as the background](https://raw.githubusercontent.com/SupposedlySam/app_deploy_screenshots/main/doc/images/2.0/layouts.png)

| `layout:` | |
| --- | --- |
| `FrameLayout.captionTop` (default) | The caption above the whole device |
| `FrameLayout.bleed()` | A large device running off the bottom edge, the layout most top listings use. `width:` sizes the device, `visible:` sets how much of it shows, `angle:` tilts it. |
| `FrameLayout.captionBottom` | The device above the caption |

### Devices

`device:` sets how the device is drawn:

| `DeviceStyle` | |
| --- | --- |
| `DeviceStyle()` (default) | A plain bezel with rounded corners and a soft shadow |
| `DeviceStyle.detailed()` | Adds the camera cutout (Dynamic Island, notch or punch-hole, from the device) and side buttons |
| `DeviceStyle.screenOnly()` | The screen alone, with no bezel |

Every option works on every preset: `bezel`, `cornerRadius`, `cutout` (`ScreenCutout.auto`, `.island`, `.notch`, `.punchHole`), `buttons`, `outline`, `glow`, `shadow: DeviceShadow(...)`, `fadeOut` (fades the bottom of the screen into the background), and `crop` to show part of the screen: `ScreenCrop.belowStatusBar`, `.safeArea` or `.points(top:, bottom:)`.

### Backgrounds

| `background:` | |
| --- | --- |
| `FrameBackground.solid(color)` | |
| `FrameBackground.gradient(gradient)` | |
| `FrameBackground.image(bytes, blur:, tint:)` | A photo, optionally blurred and tinted |
| `FrameBackground.screen()` | The app's own screen, enlarged, blurred and tinted, behind the device |
| `FrameBackground.custom((canvas, size) {...})` | Anything you can paint |

Captions pick a colour that contrasts with the background.

### Captions

![The same caption with four kinds of emphasis: coloured words, a highlighter, a gradient, and heavier italic](https://raw.githubusercontent.com/SupposedlySam/app_deploy_screenshots/main/doc/images/2.0/captions.png)

```dart
Caption(
  headline: 'All your chats, **one inbox**',
  subheadline: 'Fast, private and beautifully simple',
  emphasis: CaptionEmphasis.marker(brand, textColor: Colors.white),
)
```

- `emphasis` styles the words between `**markers**`: `CaptionEmphasis.color(color)`, `.marker(color)` (a highlighter swipe), `.gradient(gradient)` or `.style(textStyle)`. Markers survive translation files, so each language marks its own words. `\*` is a literal asterisk, and without `emphasis` asterisks are left as typed.
- `footnote` adds small print under the caption.
- `headlineStyle`, `subheadlineStyle` and `footnoteStyle` are merged over the defaults (30, 17 and 11 point Roboto). `fontWeight` renders at the real weight, from Light to Black. Set `fontFamily` to use one of your app's fonts.
- Captions are laid out in the locale's direction, right to left for Arabic or Hebrew, unless `textDirection` says otherwise.

Caption sizes are in points of a 440 × 956 canvas (the 6.9" iPhone) and scale with canvas area, so a caption takes the same share of the image on a phone and on a 13" iPad.

To style captions once with the static methods, as `StoreListing` does, give each slide its words with `Caption(...).styledLike(sharedCaption)`.

### Status bar

`StatusBarOverlay()` draws a clean iOS or Android status bar into the device's top safe area: full signal, Wi-Fi and battery, and the time Apple and Google use in their own marketing (9:41 on iOS, 9:30 on Android). A widget test otherwise has no status bar at all.

The icons are dark or light to match the `SystemUiOverlayStyle` your app publishes (an `AppBar` does this for you), as on a real phone. Override them with `iconBrightness:`, and the clock with `time:`.

### Decorations

`decorations:` places images and widgets on the canvas, in caption points: a logo, a badge, an award.

```dart
decorations: [
  FrameDecoration.image(logoBytes, width: 120, alignment: Alignment.bottomCenter),
  FrameDecoration.widget(
    const Icon(Icons.star, color: Colors.amber),
    size: Size(48, 48),
    alignment: Alignment.topRight,
  ),
],
```

`behindDevice: true` draws it behind the device. `countsAsText: true` counts it towards Google Play's [20% text check](#review).

## Annotations

![The four annotations: a lifted chat row, a spotlight on another, a callout on search, and a magnified row](https://raw.githubusercontent.com/SupposedlySam/app_deploy_screenshots/main/doc/images/2.0/annotations.png)

```dart
annotations: [Lift(find.byKey(const Key('photos-chat')))],
```

| Annotation | |
| --- | --- |
| `Lift(finder)` | Raises the widget off the screen: the same pixels, slightly larger, with a shadow. Drawn over the device's edge, and tilted with it. |
| `Spotlight(finder)` | Dims everything else |
| `Callout(finder, 'text')` | A speech bubble pointing at the widget, above or below it (`placement:`) |
| `MagnifierInset(finder, zoom: 1.4)` | An enlarged copy in an inset, rounded or `MagnifierShape.circle` |

Annotations find their widget after each device's setup and pumps, so they follow it at every screen size. A finder that matches nothing throws rather than leaving the annotation out.

## Slides from widgets

![A welcome poster, two phones overlapping on a phone slide, and the same on an iPad](https://raw.githubusercontent.com/SupposedlySam/app_deploy_screenshots/main/doc/images/2.0/widget_slides.png)

Not every slide is a screenshot. These render without touching the app under test, so they can go anywhere in the listing.

### Posters

A slide with no device, made of a frame's background, caption and decorations:

```dart
await listing.poster(
  'welcome',
  caption: const Caption(headline: 'Simple. Reliable. **Private.**'),
);
```

### Any widget

`listing.widget` renders a widget as the whole slide, on every store size:

```dart
await listing.widget(
  'stats',
  builder: (context, shot) => const MyStatsSlide(),
);
```

The widget is laid out on a canvas 440 points wide on a phone (wider on a tablet), scaled to the store's pixels, so one design keeps its proportions everywhere; use a `LayoutBuilder` to adapt to tablet shapes. It gets a `MediaQuery`, the variant's brightness and locale, its text direction, and a Material `Theme` whose text renders Roboto at real weights. Pass `theme:` for your own, and `localizationsDelegates:` (e.g. `AppLocalizations.localizationsDelegates`) for your app's strings.

### Device mockups

`captureScreens` captures the app on the listing's devices and variants without writing anything, and `DeviceMockup` draws a capture inside a device, as a widget:

```dart
final inbox = await listing.captureScreens();
await tester.tap(find.text('Priya Patel'));
await tester.pump(const Duration(seconds: 1));
final chat = await listing.captureScreens();

await listing.widget(
  'two_screens',
  builder: (context, shot) => Row(
    children: [
      Expanded(child: DeviceMockup(screen: inbox.of(shot))),
      Expanded(child: DeviceMockup(screen: chat.of(shot))),
    ],
  ),
);
```

`inbox.of(shot)` picks the capture for the slide's device and variant. A mockup takes the same `DeviceStyle` as a frame, and is as large as its constraints allow, so give it bounded ones (`Expanded`, `SizedBox`, `Positioned` with a width).

### Panoramas

![Three slides that join into one picture, with a phone straddling the second join](https://raw.githubusercontent.com/SupposedlySam/app_deploy_screenshots/main/doc/images/2.0/panorama.png)

`listing.panorama` draws one widget across several consecutive slides, which join up in the store's carousel:

```dart
await listing.panorama(
  ['plan', 'chat', 'share'],
  builder: (context, shot) => Stack(
    children: [
      const Positioned.fill(child: BrandBackground()),
      Positioned(
        left: 720, // 3 slides × 440 points: this straddles slides 2 and 3
        top: 220,
        width: 300,
        child: DeviceMockup(screen: chat.of(shot)),
      ),
    ],
  ),
);
```

## Variants

![The inbox in light and dark, English and French](https://raw.githubusercontent.com/SupposedlySam/app_deploy_screenshots/main/doc/images/2.0/variants.png)

```dart
variants: [ScreenshotVariant.light, ScreenshotVariant.dark],

// or every combination:
variants: ScreenshotVariant.matrix(
  brightnesses: [Brightness.light, Brightness.dark],
  locales: [const Locale('en', 'US'), const Locale('fr', 'FR')],
),
```

Each variant adds a suffix to the file name: `01_inbox.dark.fr_FR.png`. Brightness and locale are applied through the platform (`platformBrightness` and `locales`), as on a device, so an app that uses `ThemeMode.system` and the system locale needs nothing else. An app that keeps these in its own state can set them in `deviceSetup` from `tester.platformDispatcher`.

Read the locale where it's used, in `build` (`Localizations.localeOf(context)`). A value captured earlier, such as when a page was pushed, keeps the first variant's language in every screenshot.

## Output

### Folders

By default, files go into `app_deploy_screenshots/<platform>/<device>/`, one folder per store upload slot. `output: OutputLayout.folders('screenshots')` changes the root.

### fastlane

```dart
final listing = StoreListing(
  tester,
  output: const OutputLayout.fastlane(),
  variants: [
    ScreenshotVariant(locale: const Locale('en', 'US')),
    ScreenshotVariant(locale: const Locale('ja', 'JP')),
  ],
);
```

This writes where `fastlane deliver` and `fastlane supply` upload from:

```
fastlane/
├── screenshots/
│   ├── en-US/01_home_app_store_iphone_6_9.png
│   └── ja/01_home_app_store_iphone_6_9.png
└── metadata/android/
    ├── en-US/images/phoneScreenshots/01_home.png
    └── ja-JP/images/phoneScreenshots/01_home.png
    … and the iPad, 7" and 10" tablet files beside these
```

- Each store names the locale folder its own way (Japanese is `ja` on the App Store and `ja-JP` on Play), and the package uses the right one for each.
- Android screenshots go into supply's phone, 7", 10", TV and Wear folders, by `Device.effectiveType`.
- Both tools upload every file in a folder, in name order. So, before anything is captured, it's an error to put two variants in one folder (light and dark of one locale), two devices in one upload slot, or a locale the store doesn't list. `localeFolder:` names a folder yourself, and `defaultLocale:` is the folder for variants without a locale (it only names the folder; give the variants a locale to render in another language).
- supply has no Chromebook folder, so write Chromebook screenshots with `OutputLayout.folders()`.

## Review

![A contact sheet: every iPhone slide in one image](https://raw.githubusercontent.com/SupposedlySam/app_deploy_screenshots/main/doc/images/2.0/contact_sheet.png)

`await listing.writeReport()` (or `AppDeployScreenshots.writeReport(tester: tester)`) writes:

- `_review/<platform>__<device>.png`: one contact sheet per device folder, to check a whole listing at a glance. They live in `_review/` so upload tools don't pick them up.
- `manifest.json`: every image with its path, device, pixel size, order, locale, brightness, source (app, widget or poster) and caption coverage. Test files run in separate isolates, so each call merges with the existing manifest.

It also checks Google Play's guidance that text should cover no more than 20% of a screenshot. Every Play image whose caption covers more than `playCaptionCoverageLimit` (default `0.2`) is printed and returned. It only warns; pass `null` to skip the check.

## Capturing screens

### Screens that never settle

The default pump is `pumpAndSettle`, which never returns while an animation is running: a progress indicator, a pulsing dot, a looping video. Pass a fixed pump instead:

```dart
customPump: (tester) => tester.pump(const Duration(milliseconds: 100)),
```

Apart from that default, the package never waits for the screen to settle.

### Per-device setup

```dart
deviceSetup: (device, tester) async {
  await tester.pump();
  if (device.size.shortestSide >= 600) {
    await tester.tap(find.text('Show sidebar'));
    await tester.pump();
  }
},
```

`deviceSetup` runs for each device under its size and settings, before `customPump`. It replaces the default setup, which is two pumps, so pump at least once after the device changes.

### One widget

`finder: find.byType(BottomSheet)` captures one widget instead of the whole screen, at the device's pixel ratio.

### Images

Every capture waits for `Image` widgets and `DecoratedBox` images to finish decoding on each device, then paints one more frame, because a widget laid out again at a new size can request a new image. To prime images yourself, call `AppDeployScreenshots.primeAssets(tester)`.

### Other devices

Beyond the store sizes, `byDevices(tester, name, devices: [...])` captures any list of devices, `byPlatform(tester, name)` the 20 general-purpose presets (iPhones, iPads, Android phones and tablets, Mac, Apple TV, Vision Pro and Android TV), and `byDevice` one device to an exact path. They take the same artwork options, and are useful for previews, docs and layout checks.

A device of your own:

```dart
const tallAndroid = Device(
  name: 'android_20_9',
  size: Size(360, 780), // logical points
  devicePixelRatio: 3, // 1080 × 2340 pixels
  safeArea: EdgeInsets.only(top: 32, bottom: 24), // logical points
  platform: DevicePlatform.android,
  type: DeviceType.phone,
  screenCornerRadius: 32,
);
```

`device.pixelSize` is the capture size, `device.copyWith(...)` changes any field, and `device.meetsPlayStoreRequirements()` checks Google Play's size rules.

## Setup

### Initialisation options

```dart
await AppDeployScreenshots.initialize(
  loadFonts: true, // your pubspec's fonts, and Material icons
  loadEmojiFont: true, // AppDeployScreenshots.emojiFontFamily
  mockPlatformChannels: false, // true stubs shared_preferences and receive_sharing_intent
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

The package also ships Roboto (Light to Black, and Italic), so apps that use the default Material font render at their real weights without bundling it.

### Emoji

The test renderer can't draw colour emoji and doesn't fall back between fonts on its own, so emoji render as empty boxes. `initialize()` loads a bundled monochrome Noto Emoji font. Name it as a fallback in your theme:

```dart
ThemeData(
  fontFamilyFallback: const [AppDeployScreenshots.emojiFontFamily],
)
```

This is safe to leave in a production theme: on a device the family doesn't exist, so it's skipped. As a `dev_dependency`, the package adds none of its fonts to your app's release build.

## Troubleshooting

### Text renders as black boxes

Fonts weren't loaded. Call `AppDeployScreenshots.initialize()` in `flutter_test_config.dart` or `setUpAll`, and check the font is declared in `pubspec.yaml`.

### Icons render as empty squares

Add `uses-material-design: true` under `flutter:` in your `pubspec.yaml`.

### Emoji render as boxes

Add `fontFamilyFallback: const [AppDeployScreenshots.emojiFontFamily]` to your theme. If `initialize()` prints `emoji font not loaded`, the reason follows on the same line.

### The test times out or hangs

Your screen never settles. Pass a fixed `customPump`; see [Screens that never settle](#screens-that-never-settle).

### One language shows up in every locale

Something read the locale once and kept it. Read it in `build`; see [Variants](#variants).

### An annotation throws `StateError`

Its finder matched nothing on that device. On a smaller screen the widget may be scrolled out of view; scroll it in with `deviceSetup`.

### fastlane output throws `ArgumentError`

The message names what fastlane would have done wrong (an unknown locale folder, two files in one slot) and how to fix it. It throws before anything is captured.

## Example

[example/](example/) is a small chat app. `test/store_screenshots_test.dart` writes a whole listing, and `test/feature_gallery_test.dart` has one slide per feature. Run them from that folder:

```bash
flutter test
```

## Contributing

Issues and pull requests are welcome on [GitHub](https://github.com/SupposedlySam/app_deploy_screenshots). Run `flutter test` before opening a pull request. To regenerate the README images after a visual change, run `tool/readme_images.sh` (needs ImageMagick).

## License

This project is licensed under the BSD 3-Clause License. See [LICENSE](LICENSE). The bundled Noto Emoji and Roboto fonts are under the SIL Open Font License 1.1; see `lib/src/fonts/`.
