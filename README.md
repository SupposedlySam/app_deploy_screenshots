Welcome to App Deploy Screenshots!

This package is meant to help you automate your app deployment process by taking screenshots of your app for upload to the Apple App Store and Google Play Store.

# How does it work?

1. Similar to an E2E test, set up your app with mock data for each scenario you want to create a screenshot for.
2. Add configuration for all device screen sizes and densities you want to upload to the app stores.
3. Run everything locally to ensure your screenshots will turn out the way you want them.
4. Create a step in your CI to do this for you so you can ensure your app store screenshots are always up to date.

# Getting Started

Write a test and use the createAllByPlatformAndDevice or appDeployScreenshot functions. Once you run your test, use the screenshots in the generated `app_deploy_screenshots` directory to upload to the app stores.

## Screenshot Generation Setup

We utilize Flutter's test framework to script your app states for consistent, repeatable screenshot generation. Here's how to set it up:

1. Create a `dart_test.yaml` file in your project root:

```yaml
tags:
  app_deploy_screenshots:
    timeout: 5x
```

2. Create an `app_deploy_screenshots_test.dart` file in your `test` directory:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:your_app/main.dart';

void main() {
  testWidgets(
    'Generate app store screenshots',
    (tester) async {
      await tester.waitForAssets();

      // Set up your widget with mock data
      await tester.pumpWidgetBuilder(const YourApp());

      await tester.pumpAndSettle();

      // Take initial state screenshot
      await captureByPlatformAndDevice(
        tester,
        'initial_state',
      );

      // Navigate, interact, or modify your app state
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Take another screenshot in the new state
      await captureByPlatformAndDevice(
        tester,
        'incremented_state',
      );
    },
    tags: ['app_deploy_screenshots'], // Required tag for CI integration
  );
}
```

3. Optionally, create a `flutter_test_config.dart` file in your `test` directory to load app fonts:

```dart
import 'dart:async';

import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return AppDeployToolkit.runWithConfiguration(
    () async {
      await loadAppFonts();
      await testMain();
    },
    config: AppDeployToolkitConfiguration(
      enableRealShadows: true,
    ),
  );
}
```

This ensures your screenshots will render with the correct fonts and shadows. Without this, text in your screenshots might not appear as expected.

4. Run the screenshot generation locally:

```bash
flutter test --tags app_deploy_screenshots
```

Screenshots will be generated in the `app_deploy_screenshots` directory, organized by platform and device:

```
app_deploy_screenshots/
├── ios/
│   ├── 6.9"_iphone16_pro_max/
│   │   ├── initial_state.png
│   │   └── incremented_state.png
│   └── [other_ios_devices]/
└── android/
    ├── android_phone_16_9/
    │   ├── initial_state.png
    │   └── incremented_state.png
    └── [other_android_devices]/
```

You can also use `createAllByPlatformAndDevice` to generate screenshots for all configured devices at once:

```dart
await createAllByPlatformAndDevice(
  'initial_state',
  tester,
  // Optional: filter by platform
  // platform: DevicePlatform.ios,
);
```

## Build Into Your CI (optional)

To get started, add these workflows to your GitHub Actions:

```yaml
# Generate app store screenshots
uses: your-username/app-deploy-screenshots/.github/workflows/app_deploy_screenshots.yml@v1

# Upload screenshots to app stores
uses: your-username/app-deploy-screenshots/.github/workflows/upload_screenshots.yml@v1
```

### Prerequisites

This workflow utilizes [Fastlane](https://fastlane.tools/) for uploading screenshots. Before proceeding, ensure you have:

- Set up Fastlane for [iOS](https://docs.fastlane.tools/getting-started/ios/setup/)
- Set up Fastlane for [Android](https://docs.fastlane.tools/getting-started/android/setup/)

1. Set up the following secrets in your GitHub repository:

   **For iOS (App Store Connect)**

   ```yaml
   APP_STORE_CONNECT_API_KEY_KEY_ID: Your App Store Connect API key ID
   APP_STORE_CONNECT_API_KEY_ISSUER_ID: Your App Store Connect API key issuer ID
   APP_STORE_CONNECT_API_KEY_KEY: Your App Store Connect API key content
   IOS_P12_CERTIFICATE: Your iOS distribution certificate (base64 encoded)
   IOS_P12_PASSWORD: Password for your P12 certificate
   ```

   **For Android (Google Play Store)**

   ```yaml
   GOOGLE_PLAY_JSON_KEY: Your Google Play service account JSON key file content
   ```

2. Create a `Gemfile` in your repository root:
   ```ruby
   source "https://rubygems.org"
   gem "fastlane"
   ```

For configuration details, check out the workflow files directly.

### Setup Instructions

1. Install GitHub CLI (gh):

   ```bash
   # Install gh CLI
   brew install gh

   # Authenticate with GitHub
   gh auth login
   ```

2. Install Ruby and Bundler:

   ```bash
   # Install Ruby (if not already installed)
   brew install ruby

   # Install Bundler
   gem install bundler
   ```

3. Create a `Gemfile` in your repository root:

   ```ruby
   source "https://rubygems.org"
   gem "fastlane"
   ```

4. Run `bundle install` to generate the `Gemfile.lock`
