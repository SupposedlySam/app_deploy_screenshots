## 1.2.0

A whole store listing from one test: slides that aren't screenshots, layouts the top apps use, and output fastlane can upload as it is.

Everything written for 1.0 and 1.1 keeps working: the published 1.1.0+1 example test passes unchanged against this release.

### Deprecations

Each still works and is removed in 2.0; the IDE names its replacement.

- `MarketingFrame(layout: FrameLayout...)`: use `slideLayout: SlideLayout.captionTop`, `.captionBottom` or `.bleed(...)`. `FrameLayout` stays the 1.x enum, and `MarketingFrame(bleed: FrameBleed(...))` adds the new bleed layout beside it for 1.x-style code; both are deprecated.
- `MarketingFrame(tilt:)`: use `slideLayout: SlideLayout.bleed(angle: ...)`.
- `MarketingFrame(bezel:, screenCornerRadius:, shadow:)`: use `device: DeviceStyle(...)`.
- `forStores(root:)`: use `output: OutputLayout.folders(root)`.
- `encodeOpaquePng`, `TestAssetBundle` and `AppDeployScreenshots.packageLibFromConfig`: no longer needed.
- `initialize(mockPlatformChannels:)` stays `true` by default, and becomes `false` in 2.0. Pass it explicitly to be unaffected.

Output changes, for anyone comparing against 1.1 images: package text (captions, callouts, status bars) and the app's own `Roboto` text draw at real font weights; Android status bars show 9:30 unless `time:` is set (iOS stays 9:41); bezels are about a third thinner (1.1 drew them at the wrong scale); captions in right-to-left locales lay out right to left unless `textDirection:` is set.

### Slides that aren't screenshots

- feat: `StoreListing` writes a whole listing slide by slide: devices, variants, output, design, status bar and pumps are set once, each slide is numbered in the order it is added, and a slide passes just its caption words, styled like the shared caption (`Caption.styledLike` does the same for the static methods)
- feat: `widgetForStores` / `listing.widget` render any widget as a full slide at every store size, in the variant's theme, locale and direction, without touching the app under test
- feat: `posterForStores` / `listing.poster`: a slide with no device, made of a background, caption and decorations
- feat: `captureScreens` and `DeviceMockup` put captured screens inside a device as a widget, for two phones side by side or a before/after pair
- feat: `panoramaForStores` / `listing.panorama` draw one widget across several consecutive slides
- feat: `MarketingFrame.decorations`: images and widgets placed on the canvas, behind or in front of the device

### Layouts and devices

- feat: `SlideLayout.bleed` runs the device off the bottom edge, optionally tilted (`MarketingFrame(slideLayout:)`)
- feat: `DeviceStyle` groups how the device is drawn: bezel, Dynamic Island, notch or punch-hole cutout, side buttons, outline, glow, a real shadow, cropping (`ScreenCrop.belowStatusBar`, `.safeArea`) and a fade-out, with `.screenOnly()` and `.detailed()` presets
- feat: `FrameBackground.image(blur:, tint:)` and `FrameBackground.screen()`, the app's own screen enlarged and blurred behind the device
- feat: `Device.playStoreWear`, `playStoreChromebook` and `playStorePhoneTall` presets, and `Device.type`

### Captions and annotations

- feat: `Caption.emphasis` styles text between `**markers**` (`CaptionEmphasis.color`, `.style`, `.marker` highlighter and `.gradient`); markers survive translation files
- feat: `Caption.footnote` for small print
- feat: `Lift` raises a widget off the screen, larger and with a shadow
- feat: bundled Roboto weights (OFL), loaded from the package and never added to apps, so `fontWeight` renders as real Light to Black in captions, widget slides and the app's own Roboto text

### Output

- feat: `OutputLayout.fastlane()` writes where `fastlane deliver` and `supply` upload from: each store's locale folder name (`ja` and `ja-JP`, `he` and `iw-IL`), supply's phone, tablet, TV and Wear folders, and errors before capturing for anything the store would reject
- feat: the manifest records each slide's `source` (app, widget or poster)

### Fixes

- fix: captions and callouts follow the locale's text direction; they were always left to right
- fix: bezels were drawn at the canvas scale instead of the screen's, about a third too thick
- fix: captions rendered every weight as regular; they now use real Roboto weights

## 1.1.0+1

- docs: rewrite the README around store artwork, with rendered examples of every feature, accurate store requirements and a type-checked snippet for each API
- docs: add `example/`, a chat app whose screenshot test uses every feature

## 1.1.0

- fix: `byDevices` passes `deviceSetup` through to `byDevice`, which now runs it inside that device's overrides
- fix: images are waited for per device, after the pumps, and painted before capture. Previously images laid out again at a new device size (list tiles, `ResizeImage`) were captured blank
- fix: `Device.safeArea` is in logical points and is scaled by `devicePixelRatio` when applied. Previously apps saw about a ninth of the real inset (6.6pt instead of 59pt on iPhone), and the built-in insets now match the real devices
- feat: `byDevice` takes `deviceSetup` and `applyDeviceOverrides`
- feat: store-size presets `Device.appStore` (iPhone 6.9" 1320×2868, iPad 13" 2064×2752) and `Device.playStore` (phone 1080×1920, 7" 1224×2176, 10" 1620×2880), plus `AppDeployScreenshots.forStores`
- feat: every screenshot is written as a 24-bit PNG with no alpha, as the stores require
- feat: `StatusBarOverlay` draws a clean iOS or Android status bar, coloured from the app's `SystemUiOverlayStyle`
- feat: `MarketingFrame` composites the screenshot onto store artwork with a background, a caption, rounded corners and an optional bezel, in `captionTop`, `captionBottom` and `tilted` layouts; `ScreenshotFrame.builder` varies it per locale, brightness or device
- feat: annotations placed by `Finder`: `Spotlight`, `Callout` and `MagnifierInset`
- feat: `ScreenshotVariant` renders light, dark and locales in one call, with suffixed file names
- feat: `order` adds a store-order prefix (`01_home.png`)
- feat: `AppDeployScreenshots.writeReport` writes `manifest.json` and one contact sheet per device, and warns about Google Play screenshots whose caption covers more than 20% of the image
- feat: a bundled monochrome emoji font, `AppDeployScreenshots.emojiFontFamily`, loaded by `initialize()` and never bundled into apps
- feat: `byDevice`, `byDevices` and `byPlatform` return `ScreenshotRecord`s
- fix: captures draw real elevation shadows instead of flutter_test's solid black outlines
- fix: after a brightness change, chained theme animations finish before capture, even with a fixed `customPump`
- fix: a `finder` below the root is captured at the device pixel ratio, not at 1×
- fix: `Device.meetsPlayStoreRequirements` checks pixel size and Play's 2:1 aspect limit

## 1.0.1

- fix: pass all args through from `byPlatform` to `byDevices`

## 1.0.0

- feat: Initial Release
