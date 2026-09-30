# App Deploy Screenshots

[![pub package](https://img.shields.io/pub/v/app_deploy_screenshots.svg)](https://pub.dev/packages/app_deploy_screenshots)

A Flutter package for automatically generating app store screenshots across multiple devices and platforms. Perfect for creating deployment-ready screenshots for iOS App Store and Google Play Store submissions.

## Features

- 📱 **Multi-device Support**: Generate screenshots for iPhones, iPads, Android phones, tablets, and more
- 🎯 **App Store Guidelines Compliant**: Automatically creates screenshots meeting iOS and Android app store requirements
- 🎨 **Custom Font Loading**: Load custom fonts for better visual representation in screenshots
- ⚡ **Byte-based Screenshot Capture**: Generates actual PNG files, not just golden file comparisons
- 🔧 **Flexible Configuration**: Customize devices, finders, and screenshot capture behavior
- 🤖 **Test Integration**: Works seamlessly with Flutter widget tests
- 🏪 **Exact store sizes**: `Device.appStore` and `Device.playStore` presets, written as 24-bit PNGs with no alpha, as the stores require
- 🖼️ **Marketing frames**: background, headline, rounded screen and bezel, at the exact store pixel size
- 📶 **Clean status bar**: 9:41, full battery, full signal, coloured to match the app
- 🔦 **Annotations**: spotlights, callouts and magnifier insets placed by `Finder`, so they follow the widget on every device
- 🌗 **Variants**: light, dark and every locale in one call
- 🗂️ **Review**: store-order prefixes, a contact sheet per device, and a `manifest.json`

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dev_dependencies:
  app_deploy_screenshots: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Setup Test Configuration

Create a `test/flutter_test_config.dart` file:

```dart
import 'dart:async';
import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await AppDeployScreenshots.initialize();

  return testMain();
}
```

Alternatively, you can use the `setUpAll` method inside your test.

### 2. Create Screenshot Tests

Create a test file (e.g., `test/screenshots_test.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';

void main() {
  group('App Store Screenshots', () {
    testWidgets('Generate all platform screenshots', (tester) async {
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      // Generate for all iOS and Android devices at once
      await AppDeployScreenshots.byPlatform(tester, 'home_screen');
    });

    testWidgets('Generate specific device screenshots', (tester) async {
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      // Target specific devices for feature showcase
      await AppDeployScreenshots.byDevices(
        tester,
        'feature_showcase',
        devices: [
          Device.iphone16Pro,
          Device.ipadProM4,
          Device.androidPhone,
        ],
      );
    });

    testWidgets('Generate individual device screenshots', (tester) async {
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      // Capture single device with custom filename
      await AppDeployScreenshots.byDevice(
        tester,
        'hero_screenshot',
        device: Device.iphone16ProMax,
        fileName: 'hero_iphone_pro_max.png',
      );
    });

    testWidgets('Generate workflow screenshots', (tester) async {
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      // Onboarding flow
      await AppDeployScreenshots.byDevices(
        tester,
        'onboarding_step1',
        devices: [Device.iphone16Pro, Device.androidPhone],
      );

      // Navigate through the flow
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await AppDeployScreenshots.byDevices(
        tester,
        'onboarding_step2',
        devices: [Device.iphone16Pro, Device.androidPhone],
      );
    });
  });
}
```

### 3. Run Screenshot Generation

```bash
flutter test test/screenshots_test.dart
```

Screenshots will be generated in the `app_deploy_screenshots/` directory with the following structure:

```
app_deploy_screenshots/
├── ios/
│   ├── 6.9_iphone16_pro_max/
│   │   ├── home_screen.png
│   │   └── settings_screen.png
│   └── 13.0_ipad_pro_m4/
│       ├── home_screen.png
│       └── settings_screen.png
└── android/
    ├── 6.5_android_phone_20_9/
    │   ├── home_screen.png
    │   └── settings_screen.png
    └── 10.5_android_tablet/
        ├── home_screen.png
        └── settings_screen.png
```

## Store-ready screenshots

`forStores` renders every size App Store Connect and Google Play ask for, and each option below turns plain captures into store artwork. All of them also work with `byDevices`, `byPlatform` and `byDevice`.

```dart
const headlines = {'en': 'All your chats, one inbox', 'fr': 'Tous vos chats'};

testWidgets('store listing', (tester) async {
  await tester.pumpWidget(const MyApp());

  await AppDeployScreenshots.forStores(
    tester,
    'inbox',
    order: 1, // stores list screenshots in upload order: 01_inbox.png
    customPump: (t) => t.pump(const Duration(milliseconds: 100)),
    variants: [ScreenshotVariant.light, ScreenshotVariant.dark],
    statusBar: const StatusBarOverlay(),
    annotations: [
      Spotlight(find.byKey(const Key('compose'))),
      Callout(find.byIcon(Icons.search), 'Find any chat instantly'),
      MagnifierInset(find.byKey(const Key('first-message'))),
    ],
    frame: ScreenshotFrame.builder(
      (context) => MarketingFrame(
        background: FrameBackground.gradient(
          LinearGradient(
            colors: context.brightness == Brightness.dark
                ? const [Color(0xFF1B1464), Colors.black]
                : const [Color(0xFFE0E7FF), Colors.white],
          ),
        ),
        caption: Caption(
          headline: headlines[context.locale.languageCode]!,
          subheadline: 'Fast, private and simple',
          headlineStyle: const TextStyle(fontFamily: 'MyBrandFont'),
        ),
      ),
    ),
  );

  await AppDeployScreenshots.writeReport(tester: tester);
});
```

This writes:

```
app_deploy_screenshots/
├── ios/app_store_iphone_6_9/01_inbox.light.png      1320 × 2868
├── ios/app_store_ipad_13/01_inbox.light.png         2064 × 2752
├── android/play_store_phone/01_inbox.light.png      1080 × 1920
├── android/play_store_tablet_7/01_inbox.light.png   1224 × 2176
├── android/play_store_tablet_10/01_inbox.light.png  1620 × 2880
├── … the same again as .dark.png
├── _review/ios__app_store_iphone_6_9.png            contact sheet per device
└── manifest.json
```

### Store presets

| Preset | Pixels | Notes |
| --- | --- | --- |
| `Device.appStoreIphone69` | 1320 × 2868 | Required for iPhone; scaled down for smaller iPhones |
| `Device.appStoreIpad13` | 2064 × 2752 | Required for iPad; scaled down for smaller iPads |
| `Device.playStorePhone` | 1080 × 1920 | 9:16 |
| `Device.playStoreTablet7` | 1224 × 2176 | 9:16, 612 dp wide |
| `Device.playStoreTablet10` | 1620 × 2880 | 9:16, 810 dp wide |

`Device.appStore` and `Device.playStore` group them. Google Play rejects a screenshot whose long side is more than twice the short side, so a native 20:9 capture (1080 × 2400) is not accepted. To show a tall phone on Play, render a tall `Device` and set `MarketingFrame(canvasSize: Size(1080, 1920))`.

Every screenshot is written as a 24-bit PNG with no alpha channel. Google Play asks for this, and App Store Connect asks for flattened images.

### Status bar

`StatusBarOverlay()` draws a clean iOS or Android status bar into the device's top safe area. Its icons are dark or light to match the `SystemUiOverlayStyle` the app publishes (for example from an `AppBar`), or set `iconBrightness`. The clock text is `time:`, `'9:41'` by default.

### Marketing frames

`MarketingFrame` renders the app at the device's real logical size, then composites the finished image onto a canvas at the exact store pixel size:

- `background`: `FrameBackground.solid`, `.gradient`, `.image(bytes)` or `.custom(painter)`
- `caption`: a `Caption` with a headline and optional subheadline. Sizes are in device points; pass your app's font in `headlineStyle`.
- `layout`: `FrameLayout.captionTop`, `.captionBottom` or `.tilted`
- `bezel`: a plain rounded-rectangle `DeviceBezel` (no manufacturer artwork to license), or `null`
- `canvasSize`: the output size, by default the device's pixel size

Use `ScreenshotFrame.builder((context) => ...)` to vary the frame by `context.locale`, `context.brightness`, `context.device` or `context.order`, and return `null` to leave one screenshot unframed.

### Annotations

Annotations find their target with a `Finder` after the device's overrides and pumps, so they follow the widget at every screen size. A finder that matches nothing throws; it never silently leaves the annotation out.

- `Spotlight(finder)` dims everything except the target.
- `Callout(finder, 'text')` draws a speech bubble with an arrow pointing at the target.
- `MagnifierInset(finder, zoom: 1.4)` enlarges the target into an inset. Inside a frame, the inset can extend past the device's edges.

### Variants

```dart
variants: ScreenshotVariant.matrix(
  brightnesses: [Brightness.light, Brightness.dark],
  locales: [Locale('en'), Locale('fr')],
),
```

Each variant adds a suffix: `01_home.dark.fr.png`. Brightness and locale are applied through the platform (`platformBrightness`, `locales`), as on a device, so apps that use `ThemeMode.system` and the system locale need nothing else. An app that keeps these in its own state can read them in `deviceSetup` from `tester.platformDispatcher`.

When the brightness changes between captures, the package steps through 600 ms of frames so chained theme animations finish. A screen that never settles still works.

### Review: contact sheets and manifest

`AppDeployScreenshots.writeReport()` writes `manifest.json` (every screenshot with its device, size, order, locale and brightness) and one contact sheet per device folder into `_review/`, where upload tools that take every PNG in a device folder will not pick them up. Call it at the end of a test, passing `tester:`, or in `tearDownAll`.

### Emoji

The test renderer cannot draw colour emoji, and it does not fall back between fonts on its own, so emoji render as empty boxes. `initialize()` loads a bundled monochrome Noto Emoji font (SIL Open Font License 1.1). To use it, name it as a fallback in your theme:

```dart
ThemeData(
  fontFamilyFallback: const [AppDeployScreenshots.emojiFontFamily],
)
```

This is safe in a production theme: on a device the family does not exist and the system emoji font is used. The font is read from the package at test time and is not declared as a Flutter font, so it adds nothing to your app's release build.

### Real shadows

`flutter_test` normally draws every elevation shadow as a solid black outline (`debugDisableShadows`), which is right for goldens but wrong for store artwork. Captures draw real shadows, and the test's setting is restored afterwards.

## API Reference

### AppDeployScreenshots.byPlatform()

Generates screenshots for all iOS and Android devices following app store guidelines.

```dart
await AppDeployScreenshots.byPlatform(
  tester,
  'screenshot_name',
  finder: find.byType(Scaffold), // Optional: custom finder
  customPump: (tester) async {   // Optional: custom pump function
    await tester.pump(Duration(milliseconds: 100));
  },
);
```

### AppDeployScreenshots.byDevices()

Generates screenshots for specific devices.

```dart
await AppDeployScreenshots.byDevices(
  tester,
  'screenshot_name',
  devices: [
    Device.iphone16Pro,
    Device.ipadProM4,
    Device.androidPhone,
  ],
  finder: find.byType(MyWidget),        // Optional
  deviceSetup: (device, tester) async { // Optional: setup per device
    // Custom setup logic
  },
);
```

### AppDeployScreenshots.byDevice()

Generates a single screenshot for a specific device.

```dart
await AppDeployScreenshots.byDevice(
  tester,
  'screenshot_name',
  device: Device.iphone16Pro,
  fileName: 'custom_screenshot.png',
  waitForImages: true,
);
```

## Device Support

### iOS Devices

- iPhone SE (4.7")
- iPhone 8 Plus (5.5")
- iPhone 11 (6.1")
- iPhone 14 (6.1")
- iPhone 14 Plus (6.5")
- iPhone 16 Pro (6.3")
- iPhone 16 Pro Max (6.9")
- iPad Pro 11" (11.0")
- iPad Pro 12.9" (12.9")
- iPad Pro M4 (13.0")
- Apple TV (13.0")
- Vision Pro (13.0")
- Mac Default (13.0")

### Android Devices

- Android Phone 16:9 (6.1")
- Android Phone 9:16 (6.1")
- Android Phone 18:9 (6.3")
- Android Phone 20:9 (6.5")
- Android Tablet (10.5")
- Android TV (13.0")

## App Store Guidelines Compliance

The package automatically generates screenshots that meet app store requirements:

### iOS App Store

- **iPhone 6.9"**: 1320×2868px or 2868×1320px, 1290×2796px or 2796×1290px
- **iPhone 6.5"**: 1242×2688px or 2688×1242px, 1284×2778px or 2778×1284px
- **iPad 13"**: 2064×2752px or 2752×2064px, 2048×2732px or 2732×2048px

### Google Play Store

- **Phone**: PNG or JPEG, up to 8 MB, 16:9 or 9:16 aspect ratio, 320px-3840px per side
- **7" Tablet**: PNG or JPEG, up to 8 MB, 16:9 or 9:16 aspect ratio, 320px-3840px per side
- **10" Tablet**: PNG or JPEG, up to 8 MB, 16:9 or 9:16 aspect ratio, 1080px-7680px per side

## Custom Font Loading

To use custom fonts in your screenshots, add them to your `pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: MyCustomFont
      fonts:
        - asset: fonts/MyCustomFont-Regular.ttf
```

The package will automatically load and use your custom fonts instead of Flutter's default test fonts.

## Advanced Configuration

### Custom Pump Functions

Control the timing and animation states:

```dart
// For animated screens
await AppDeployScreenshots.byPlatform(
  tester,
  'animated_screen',
  customPump: (tester) async {
    await tester.pump(Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  },
);

// For loading states
await AppDeployScreenshots.byDevice(
  tester,
  'loading_state',
  device: Device.iphone16Pro,
  fileName: 'loading_example.png',
  customPump: (tester) async {
    // Capture mid-animation
    await tester.pump(Duration(milliseconds: 100));
  },
);
```

### Device Setup

Perform custom setup for each device:

```dart
await AppDeployScreenshots.byDevices(
  tester,
  'responsive_layout',
  devices: [Device.iphone16Pro, Device.ipadProM4, Device.androidTablet],
  deviceSetup: (device, tester) async {
    // Platform-specific setup
    if (device.platform == DevicePlatform.ios) {
      await tester.tap(find.text('iOS Feature'));
    } else {
      await tester.tap(find.text('Android Feature'));
    }

    // Device-size specific setup
    if (device.displaySize.inches > 10) {
      await tester.tap(find.text('Tablet View'));
    }
  },
);
```

### Custom Finders

Capture specific parts of your UI:

```dart
// Capture just the main content area
await AppDeployScreenshots.byPlatform(
  tester,
  'main_content',
  finder: find.byKey(Key('main_content')),
);

// Capture a specific widget
await AppDeployScreenshots.byDevices(
  tester,
  'custom_widget',
  devices: [Device.iphone16Pro],
  finder: find.byType(CustomWidget),
);

// Capture modal or dialog
await AppDeployScreenshots.byDevice(
  tester,
  'modal_example',
  device: Device.ipadProM4,
  fileName: 'modal_ipad.png',
  finder: find.byType(Dialog),
);
```

### Complex Workflow Example

```dart
testWidgets('E-commerce app screenshots', (tester) async {
  await tester.pumpWidget(ECommerceApp());

  // Product listing page
  await AppDeployScreenshots.byDevices(
    tester,
    'product_listing',
    devices: [Device.iphone16Pro, Device.androidPhone],
  );

  // Product detail page
  await tester.tap(find.text('iPhone Case'));
  await tester.pumpAndSettle();

  await AppDeployScreenshots.byDevice(
    tester,
    'product_detail',
    device: Device.iphone16ProMax,
    fileName: 'product_detail_large.png',
  );

  // Shopping cart
  await tester.tap(find.byIcon(Icons.add_shopping_cart));
  await tester.pumpAndSettle();

  await AppDeployScreenshots.byDevices(
    tester,
    'shopping_cart',
    devices: [Device.iphone16Pro, Device.ipadProM4],
    finder: find.byType(ShoppingCartWidget),
  );

  // Checkout flow - tablet optimized
  await tester.tap(find.text('Checkout'));
  await tester.pumpAndSettle();

  await AppDeployScreenshots.byDevice(
    tester,
    'checkout_flow',
    device: Device.ipadProM4,
    fileName: 'checkout_tablet.png',
    deviceSetup: (device, tester) async {
      // Fill in some test data for better screenshots
      await tester.enterText(find.byKey(Key('email')), 'user@example.com');
      await tester.enterText(find.byKey(Key('address')), '123 Main St');
    },
  );
});
```

## Initialization Options

Customize the initialization behavior:

```dart
await AppDeployScreenshots.initialize(
  loadFonts: true,           // Load custom fonts (default: true)
  verbose: true,             // Enable verbose logging (default: false)
  mockPlatformChannels: true, // Mock platform channels (default: true)
);
```

**Asset Loading Behavior:**

- Every capture waits for images per device, after its pumps, then paints one more frame. A widget laid out again at a new device size requests a new image, so waiting once up front is not enough.
- `byDevice()` uses the `waitForImages` parameter (default: `true`) to control asset loading
- Manual `primeAssets()` calls are only needed for advanced use cases

## Tips and Best Practices

### 1. Use Meaningful Names

```dart
// Platform-wide screenshots
await AppDeployScreenshots.byPlatform(tester, 'onboarding_welcome');
await AppDeployScreenshots.byPlatform(tester, 'main_dashboard');

// Device-specific hero shots
await AppDeployScreenshots.byDevice(
  tester, 'hero_shot',
  device: Device.iphone16ProMax,
  fileName: 'app_store_hero.png'
);

// Targeted device groups
await AppDeployScreenshots.byDevices(
  tester, 'settings_profile',
  devices: [Device.iphone16Pro, Device.androidPhone]
);
```

### 2. Handle Network Images and Assets

```dart
// Every capture waits for images on each device
await AppDeployScreenshots.byPlatform(tester, 'screen_with_images');

// For byDevice, control asset loading with waitForImages parameter
await AppDeployScreenshots.byDevice(
  tester,
  'image_gallery',
  device: Device.ipadProM4,
  fileName: 'gallery_ipad.png',
  waitForImages: true, // Default is true - set to false for faster tests
);

// Only call primeAssets manually if you need fine-grained control
await AppDeployScreenshots.primeAssets(tester); // Rarely needed
await AppDeployScreenshots.byDevice(
  tester,
  'pre_loaded_images',
  device: Device.iphone16Pro,
  fileName: 'custom.png',
  waitForImages: false, // Skip automatic loading since we did it manually
);
```

### 3. Test Different States and User Flows

```dart
testWidgets('Screenshot user journey', (tester) async {
  await tester.pumpWidget(MyApp());

  // 1. Empty state - show across all devices
  await AppDeployScreenshots.byPlatform(tester, 'empty_state');

  // 2. Loading state - capture specific moment
  await triggerLoading(tester);
  await AppDeployScreenshots.byDevices(
    tester, 'loading_state',
    devices: [Device.iphone16Pro, Device.androidPhone],
    customPump: (tester) => tester.pump(Duration(milliseconds: 200)),
  );

  // 3. Success state - focus on key devices
  await addTestData(tester);
  await AppDeployScreenshots.byDevices(
    tester, 'success_state',
    devices: [Device.iphone16ProMax, Device.ipadProM4],
  );

  // 4. Error handling - single device example
  await triggerError(tester);
  await AppDeployScreenshots.byDevice(
    tester, 'error_handling',
    device: Device.iphone16Pro,
    fileName: 'error_example.png',
  );
});
```

### 4. Optimize for Different Use Cases

```dart
// Quick testing - single device
await AppDeployScreenshots.byDevice(
  tester, 'quick_test',
  device: Device.iphone16Pro,
  fileName: 'test.png',
);

// App store submission - all required sizes
await AppDeployScreenshots.byPlatform(tester, 'app_store_ready');

// Feature documentation - specific devices
await AppDeployScreenshots.byDevices(
  tester, 'feature_demo',
  devices: [Device.iphone16Pro, Device.ipadProM4, Device.androidTablet],
  finder: find.byKey(Key('feature_widget')),
);
```

### 5. Organize Screenshots

Screenshots are automatically organized by platform and device size, making it easy to upload to app stores:

- Use the `ios/` folder contents for App Store Connect
- Use the `android/` folder contents for Google Play Console

## Troubleshooting

### Screenshots are black/empty

- Ensure your widget tree is properly pumped with `await tester.pumpAndSettle()`
- Check that your widgets are actually rendered (not offstage)

### Emoji show as boxes

- Add `fontFamilyFallback: const [AppDeployScreenshots.emojiFontFamily]` to your theme (see [Emoji](#emoji))
- If `initialize()` prints `emoji font not loaded`, the reason follows on the same line

### Safe areas

`Device.safeArea` is in logical points, the same values the app reads from `MediaQuery.paddingOf`. Before 1.1.0 the insets were applied at a fraction of their real size.

### Custom fonts not appearing

- Verify fonts are declared in `pubspec.yaml`
- Ensure font files are in the correct location
- Check that `loadFonts: true` is set in initialization

### Tests timing out

- The default pump is `pumpAndSettle`, which never returns on a screen with a running animation (a spinner, a pulse). Pass `customPump: (t) => t.pump(const Duration(milliseconds: 100))`.
- Use `customPump` to control animation timing
- Increase test timeout if needed
- Consider using `waitForImages: false` for faster tests

## Contributing

Contributions are welcome! Please read our contributing guide and submit pull requests to our repository.

## License

This project is licensed under the BSD 3-Clause License - see the LICENSE file for details.
