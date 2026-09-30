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
- feat: `AppDeployScreenshots.writeReport` writes `manifest.json` and one contact sheet per device
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
