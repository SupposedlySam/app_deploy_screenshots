# App Deploy Screenshots 📱

[![pub package](https://img.shields.io/pub/v/app_deploy_screenshots.svg)](https://pub.dev/packages/app_deploy_screenshots)
[![License](https://img.shields.io/badge/license-BSD-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)

**Automate your app store screenshot generation with Flutter's testing framework!**

This package helps you create professional, consistent screenshots for the Apple App Store and Google Play Store by leveraging Flutter's testing capabilities. Say goodbye to manual screenshot taking and hello to automated, pixel-perfect app store images.

## ✨ Features

- 🎯 **Apple App Store Ready** - Generates screenshots in required dimensions (6.5", 6.9", iPad)
- 🤖 **Google Play Store Support** - Android phone, tablet, and Chromebook screenshots
- 🔤 **Smart Font Loading** - Automatically loads your custom fonts for accurate text rendering
- 🎨 **Screenshot-Optimized Themes** - Built-in themes that look great in app store listings
- 🔧 **Test Setup Utilities** - Comprehensive mocking and setup helpers
- 📐 **Multiple Device Support** - Generate screenshots for all required device sizes
- 🚀 **CI/CD Integration** - Perfect for GitHub Actions and other CI systems
- 🎭 **Mock Data Helpers** - Ready-to-use sample data for realistic screenshots

## 🚀 Quick Start

### 1. Installation

Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
  app_deploy_screenshots: ^1.0.0
  flutter_test:
    sdk: flutter
```

### 2. Basic Setup

Create `test/screenshot_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:your_app/main.dart';

void main() {
  testWidgets('Generate App Store screenshots', (tester) async {
    // Setup screenshot environment
    await ScreenshotTestSetup.initialize();

    // Create your app with mock data
    await tester.pumpWidget(
      MyApp().withScreenshotTheme(
        primaryColor: Colors.blue,
      ),
    );

    await tester.pumpAndSettle();

    // Capture screenshots for Apple App Store
    await tester.captureAppleStoreScreenshots('home_screen');

  }, tags: ['screenshots']);
}
```

### 3. Configure Font Loading

Create `test/flutter_test_config.dart`:

```dart
import 'dart:async';
import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return AppDeployToolkit.runWithConfiguration(() async {
    await loadAppFonts(verbose: true);
    await testMain();
  }, config: AppDeployToolkitConfiguration(enableRealShadows: true));
}
```

### 4. Generate Screenshots

```bash
flutter test --tags screenshots
```

Screenshots will be saved to `test/app_deploy_screenshots/app_store_exports/`

## 📖 Comprehensive Guide

### Apple App Store Screenshots

The `AppleStoreScreenshots` class provides specialized methods for Apple's requirements:

```dart
// Generate screenshots for required iPhone devices (6.5" and 6.9")
await AppleStoreScreenshots.captureForAppStore(
  tester,
  'main_screen',
  includeIpad: true, // Optional: include iPad screenshots
);

// Generate the essential 3 screenshots Apple requires
await AppleStoreScreenshots.captureEssentialScreenshots(
  tester,
  homeScreen: MyHomePage(),
  featureScreen: MyFeaturePage(),
  settingsScreen: MySettingsPage(),
);

// Check Apple's current requirements
final requirements = AppleStoreScreenshots.getRequirements();
print('Minimum screenshots needed: ${requirements['minimum_screenshots']}');
```

### Screenshot-Optimized Themes

Use built-in themes designed to look great in app store listings:

```dart
// iOS App Store optimized theme
final theme = ScreenshotThemes.iosAppStoreLight(
  primaryColor: Colors.blue,
  fontFamily: 'YourCustomFont',
);

// Android Play Store optimized theme
final theme = ScreenshotThemes.androidPlayStore(
  primaryColor: Colors.green,
  useMaterial3: true,
);

// Apply to your widget
Widget.withScreenshotTheme(
  theme: theme,
  localizationsDelegates: [...],
);
```

### Advanced Setup & Configuration

For complex apps, use the comprehensive setup utilities:

```dart
void main() {
  setUpAll(() async {
    // Initialize with full configuration
    await ScreenshotTestSetup.initialize(
      loadFonts: true,
      verbose: true,
      mockPlatformChannels: true,
    );
  });

  testWidgets('Advanced screenshot test', (tester) async {
    // Create mock data
    final mockData = ScreenshotTestSetup.createMockData();

    // Setup widget with optimized configuration
    final widget = ScreenshotTestSetup.createScreenshotWidget(
      MyAppWithMockData(data: mockData),
      primaryColor: Colors.purple,
      fontFamily: 'Roboto',
    );

    await tester.pumpWidget(widget);

    // Ensure everything is properly loaded
    await ScreenshotTestSetup.prepareWidgetForScreenshot(tester);

    // Capture screenshots
    await tester.captureAppleStoreScreenshots('mock_data_screen');
  });
}
```

### Multi-Device Screenshots

Generate screenshots for all platforms and devices:

```dart
// All iOS and Android devices
await captureByPlatformAndDevice(tester, 'cross_platform');

// Custom device list
await appDeployScreenshot(
  tester,
  'custom_devices',
  devices: [
    Device.iphone14Plus,
    Device.iphone16ProMax,
    Device.androidPhone,
    Device.androidTablet7,
  ],
);
```

### Font Loading Options

Enhanced font loading with error handling:

```dart
// Basic font loading
await loadAppFonts();

// Advanced font loading with options
await loadAppFonts(
  verbose: true,      // Print detailed loading info
  skipOnError: true,  // Continue if some fonts fail
);
```

### Mock Data Helpers

Use built-in mock data for realistic screenshots:

```dart
final mockData = ScreenshotTestSetup.createMockData();

// Sample user names
final users = mockData.userNames; // ['Alice Johnson', 'Bob Smith', ...]

// Sample messages for chat apps
final messages = mockData.sampleMessages; // ['Hey! How was your weekend? 😊', ...]

// Sample timestamps
final times = mockData.timestamps; // ['2:30 PM', 'Yesterday', ...]

// Sample colors for UI
final colors = mockData.accentColors; // [Colors.yellow, Colors.blue, ...]
```

### Directory Structure

Screenshots are organized for easy app store upload:

```
test/app_deploy_screenshots/app_store_exports/
├── 6.5_inch_iphone14_plus/
│   ├── home_screen.png          (1284×2778px)
│   ├── feature_screen.png
│   └── settings_screen.png
├── 6.9_inch_iphone16_pro_max/
│   ├── home_screen.png          (1290×2796px)
│   ├── feature_screen.png
│   └── settings_screen.png
└── android/
    ├── phone/
    └── tablet/
```

## 🔧 GitHub Actions Integration

### Basic Workflow

Create `.github/workflows/screenshots.yml`:

```yaml
name: Generate Screenshots

on:
  pull_request:
    paths: ["lib/**", "test/**"]
  push:
    branches: [main]

jobs:
  screenshots:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: "3.24.0"

      - name: Install dependencies
        run: flutter pub get

      - name: Generate screenshots
        run: flutter test --tags screenshots

      - name: Upload screenshot artifacts
        uses: actions/upload-artifact@v4
        with:
          name: app-store-screenshots
          path: test/app_deploy_screenshots/app_store_exports/
```

### Advanced CI Setup

For apps with special requirements:

```yaml
- name: Generate screenshots with custom setup
  run: |
    # Create dart_test.yaml for timeout configuration
    echo "tags:" > dart_test.yaml
    echo "  screenshots:" >> dart_test.yaml
    echo "    timeout: 5x" >> dart_test.yaml

    # Run screenshot generation
    flutter test \
      --tags screenshots \
      --reporter=expanded \
      --file-reporter=json:test-results.json
```

## 🐛 Troubleshooting

### Common Issues

**Fonts not rendering properly**

```dart
// Ensure flutter_test_config.dart is set up correctly
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return AppDeployToolkit.runWithConfiguration(() async {
    await loadAppFonts(verbose: true, skipOnError: true);
    await testMain();
  }, config: AppDeployToolkitConfiguration(enableRealShadows: true));
}
```

**Plugin exceptions during tests**

```dart
// Use ScreenshotTestSetup.initialize() to mock common channels
setUpAll(() async {
  await ScreenshotTestSetup.initialize(
    mockPlatformChannels: true, // This fixes most plugin issues
  );
});
```

**Screenshots are blank or contain boxes**

```dart
// Ensure proper setup and waiting
await ScreenshotTestSetup.prepareWidgetForScreenshot(tester);
await tester.pumpAndSettle(const Duration(seconds: 2));
```

**Memory issues with large tests**

```dart
// Add timeout configuration in dart_test.yaml
tags:
  screenshots:
    timeout: 5x
```

### Debug Mode

Enable verbose logging to diagnose issues:

```dart
await loadAppFonts(verbose: true);
await ScreenshotTestSetup.initialize(verbose: true);
```

## 📚 API Reference

### Core Functions

| Function                                     | Description                                 | Use Case                    |
| -------------------------------------------- | ------------------------------------------- | --------------------------- |
| `appDeployScreenshot()`                      | Generate screenshots for custom device list | Full control over devices   |
| `captureByPlatformAndDevice()`               | Generate for all iOS and Android devices    | Cross-platform apps         |
| `AppleStoreScreenshots.captureForAppStore()` | Apple App Store specific screenshots        | iOS app submission          |
| `loadAppFonts()`                             | Load custom fonts for accurate rendering    | Apps with custom typography |

### Theme Utilities

| Function                              | Description               | Use Case                |
| ------------------------------------- | ------------------------- | ----------------------- |
| `ScreenshotThemes.iosAppStoreLight()` | iOS-optimized light theme | iPhone app screenshots  |
| `ScreenshotThemes.iosAppStoreDark()`  | iOS-optimized dark theme  | Dark mode screenshots   |
| `ScreenshotThemes.androidPlayStore()` | Android-optimized theme   | Play Store screenshots  |
| `Widget.withScreenshotTheme()`        | Apply theme to any widget | Quick theme application |

### Device Support

| Device Category | Devices Included                  | Dimensions           |
| --------------- | --------------------------------- | -------------------- |
| iPhone Required | iPhone 14 Plus, iPhone 16 Pro Max | 1284×2778, 1290×2796 |
| iPhone Optional | iPhone 13 Mini, iPhone 15 Pro     | Various              |
| iPad            | iPad Pro 13"                      | 2064×2752            |
| Android Phone   | Various aspect ratios             | 16:9, 18:9, 19:9     |
| Android Tablet  | 7", 10" tablets                   | Multiple sizes       |

## 🎯 Best Practices

### 1. Consistent Mock Data

```dart
final mockData = ScreenshotTestSetup.createMockData();
// Use the same mock data across all screenshots for consistency
```

### 2. Realistic Content

```dart
// Use realistic, localized content
final messages = [
  'Welcome to our amazing app! 🎉',
  'Discover new features and improvements',
  'Connect with friends and family easily',
];
```

### 3. Brand Consistency

```dart
// Use your app's actual colors and fonts
final theme = ScreenshotThemes.iosAppStoreLight(
  primaryColor: MyAppColors.primary,
  fontFamily: 'MyAppFont',
);
```

### 4. Multiple Scenarios

```dart
// Capture different user scenarios
await captureAppleStoreScreenshots('onboarding');
await captureAppleStoreScreenshots('main_features');
await captureAppleStoreScreenshots('premium_features');
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built on top of Flutter's excellent testing framework
- Inspired by the golden_toolkit package for font loading
- Device configurations based on official Apple and Google guidelines

---

**Made with ❤️ for the Flutter community**

_Need help? [Open an issue](https://github.com/your-repo/app_deploy_screenshots/issues) or check our [documentation](https://pub.dev/packages/app_deploy_screenshots)._
