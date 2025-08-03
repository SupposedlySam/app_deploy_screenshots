import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_deploy_screenshots.dart';

/// Utilities specifically for Apple App Store screenshot requirements
class AppleStoreScreenshots {
  AppleStoreScreenshots._();

  /// Apple App Store required iPhone devices for screenshots
  ///
  /// According to Apple guidelines:
  /// - iPhone 6.5" (1284×2778px) - Required
  /// - iPhone 6.9" (1290×2796px) - Required for newer devices
  static List<Device> get requiredIPhoneDevices => [
        Device.iphone14Plus, // 6.5" - 1284×2778
        Device.iphone16ProMax, // 6.9" - 1290×2796
      ];

  /// Apple App Store iPad devices for screenshots (optional but recommended)
  static List<Device> get recommendedIpadDevices => [
        Device.ipadProM4, // 13" - 2064×2752
      ];

  /// All Apple devices recommended for App Store screenshots
  static List<Device> get allRecommendedDevices => [
        ...requiredIPhoneDevices,
        ...recommendedIpadDevices,
      ];

  /// Captures screenshots specifically for Apple App Store submission
  ///
  /// This ensures you have the required iPhone screenshots in the correct dimensions
  ///
  /// [tester] - The WidgetTester instance
  /// [name] - Base name for the screenshot files
  /// [finder] - Optional widget finder (defaults to entire app)
  /// [customPump] - Optional custom pump function
  /// [includeIpad] - Whether to include iPad screenshots
  /// [outputDir] - Custom output directory (defaults to app_store_exports)
  static Future<void> captureForAppStore(
    WidgetTester tester,
    String name, {
    Finder? finder,
    CustomPump? customPump,
    bool includeIpad = false,
    String outputDir = 'app_store_exports',
  }) async {
    final devices = includeIpad ? allRecommendedDevices : requiredIPhoneDevices;

    await appDeployScreenshot(
      tester,
      name,
      finder: finder,
      customPump: customPump,
      devices: devices,
    );
  }

  /// Captures the three most common screenshot types for iOS apps
  ///
  /// This is a convenience method that captures:
  /// 1. Main/Home screen
  /// 2. Feature detail screen
  /// 3. Settings/Profile screen
  ///
  /// You only need 3 screenshots minimum for App Store submission
  static Future<void> captureEssentialScreenshots(
    WidgetTester tester, {
    required Widget homeScreen,
    required Widget featureScreen,
    required Widget settingsScreen,
    CustomPump? customPump,
    bool includeIpad = false,
  }) async {
    // Capture home screen
    await tester.pumpWidget(homeScreen);
    await captureForAppStore(
      tester,
      'home_screen',
      customPump: customPump,
      includeIpad: includeIpad,
    );

    // Capture feature screen
    await tester.pumpWidget(featureScreen);
    await captureForAppStore(
      tester,
      'feature_screen',
      customPump: customPump,
      includeIpad: includeIpad,
    );

    // Capture settings screen
    await tester.pumpWidget(settingsScreen);
    await captureForAppStore(
      tester,
      'settings_screen',
      customPump: customPump,
      includeIpad: includeIpad,
    );
  }

  /// Validates that screenshots meet Apple's dimension requirements
  ///
  /// Returns true if all required dimensions are available
  static bool validateScreenshotDimensions() {
    final requiredDimensions = [
      const Size(1284, 2778), // iPhone 6.5"
      const Size(1290, 2796), // iPhone 6.9"
    ];

    for (final device in requiredIPhoneDevices) {
      final deviceSize = Size(
        device.size.width * device.devicePixelRatio,
        device.size.height * device.devicePixelRatio,
      );

      if (!requiredDimensions.any((required) =>
          (required.width == deviceSize.width &&
              required.height == deviceSize.height) ||
          (required.height == deviceSize.width &&
              required.width == deviceSize.height))) {
        return false;
      }
    }

    return true;
  }

  /// Gets information about Apple's current screenshot requirements
  static Map<String, dynamic> getRequirements() {
    return {
      'minimum_screenshots': 3,
      'maximum_screenshots': 10,
      'required_devices': [
        'iPhone 6.5" (1284×2778px)',
        'iPhone 6.9" (1290×2796px)',
      ],
      'recommended_devices': [
        'iPad 13" (2064×2752px)',
      ],
      'supported_formats': ['PNG', 'JPEG'],
      'max_file_size': '8MB per screenshot',
      'aspect_ratios': ['Portrait: 9:16', 'Landscape: 16:9'],
      'notes': [
        'Screenshots are used for all display sizes and localizations',
        'Only the first 3 screenshots are shown on app installation sheets',
        'High-quality screenshots improve conversion rates',
      ],
    };
  }
}

/// Extension methods for easier Apple Store screenshot testing
extension AppleStoreTestingExtension on WidgetTester {
  /// Convenience method to capture Apple App Store screenshots
  Future<void> captureAppleStoreScreenshots(
    String name, {
    Finder? finder,
    CustomPump? customPump,
    bool includeIpad = false,
  }) async {
    await AppleStoreScreenshots.captureForAppStore(
      this,
      name,
      finder: finder,
      customPump: customPump,
      includeIpad: includeIpad,
    );
  }
}
