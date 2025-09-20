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
│   ├── 6.9"_iphone16_pro_max/
│   │   ├── home_screen.png
│   │   └── settings_screen.png
│   └── 13.0"_ipad_pro_m4/
│       ├── home_screen.png
│       └── settings_screen.png
└── android/
    ├── 6.5"_android_phone_20_9/
    │   ├── home_screen.png
    │   └── settings_screen.png
    └── 10.5"_android_tablet/
        ├── home_screen.png
        └── settings_screen.png
```

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

- `byPlatform()` and `byDevices()` automatically call `primeAssets()` to load images
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
// byPlatform and byDevices automatically handle asset loading
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

### Custom fonts not appearing

- Verify fonts are declared in `pubspec.yaml`
- Ensure font files are in the correct location
- Check that `loadFonts: true` is set in initialization

### Tests timing out

- Use `customPump` to control animation timing
- Increase test timeout if needed
- Consider using `waitForImages: false` for faster tests

## Contributing

Contributions are welcome! Please read our contributing guide and submit pull requests to our repository.

## License

This project is licensed under the BSD 3-Clause License - see the LICENSE file for details.
