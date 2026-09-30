import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'device.dart';

/// Convenience extensions for more easily configuring WidgetTester for pre-set configurations
extension WidgetFlutterBindingExtensions on TestWidgetsFlutterBinding {
  /// Configure the Test device for the duration of the supplied operation and revert
  ///
  /// [device] the desired configuration to apply
  ///
  /// [body] the closure you wish to be executed with the device configuration applied
  ///
  Future<void> runWithDeviceOverrides(
    Device device, {
    required Future<void> Function() body,
  }) async {
    await _applyDeviceOverrides(device);
    try {
      await body();
    } finally {
      await _resetDeviceOverrides();
    }
  }

  /// Configure the Test device to match the configuration of the supplied device
  ///
  /// Note: these settings will persist across multiple tests in the same file. It is recommended
  /// that you reset upon completion.
  ///
  /// [device] the desired configuration to apply
  ///
  Future<void> _applyDeviceOverrides(Device device) async {
    await setSurfaceSize(Size(device.size.width, device.size.height));
    platformDispatcher.implicitView!.physicalSize =
        device.size * device.devicePixelRatio;
    platformDispatcher.implicitView!.devicePixelRatio = device.devicePixelRatio;
    platformDispatcher.textScaleFactorTestValue = device.textScale;
    platformDispatcher.platformBrightnessTestValue = device.brightness;
    // `FakeViewPadding` is in physical pixels; `Device.safeArea` is in
    // logical points, like `MediaQuery.padding`. Before 1.1.0 the constants
    // were written pre-divided (`59 / 3`) and applied as physical pixels, so
    // apps saw a 6.6pt notch on a 59pt device.
    final safeArea = device.safeArea * device.devicePixelRatio;
    platformDispatcher.implicitView!.padding = FakeViewPadding(
      bottom: safeArea.bottom,
      left: safeArea.left,
      right: safeArea.right,
      top: safeArea.top,
    );
  }

  /// Resets any configuration that may be been specified by applyDeviceOverrides
  ///
  /// Only needs to be called if you are concerned about the result of applyDeviceOverrides bleeding over across tests.
  Future<void> _resetDeviceOverrides() async {
    platformDispatcher.implicitView!.resetPhysicalSize();
    platformDispatcher.implicitView!.resetDevicePixelRatio();
    platformDispatcher.clearTextScaleFactorTestValue();
    platformDispatcher.clearPlatformBrightnessTestValue();
    platformDispatcher.implicitView!.resetPadding();
    await setSurfaceSize(null);
  }
}

/// Convenience extensions for configuring elements of the TestView
extension TestViewExtensions on TestFlutterView {
  /// convenience wrapper for configuring the padding
  ///
  /// [safeArea] specifies the safe area insets for all 4 edges that you wish to simulate
  ///
  /// ## Example
  /// ```dart
  /// testWidgets('Test with safe area', (tester) async {
  ///   tester.view.safeAreaTestValue = const EdgeInsets.all(10);
  ///   await tester.pumpWidget(const TestApp());
  ///   expect(find.text('Hello, World!'), findsOneWidget);
  /// });
  /// ```
  set safeAreaTestValue(EdgeInsets safeArea) {
    padding = FakeViewPadding(
      bottom: safeArea.bottom,
      left: safeArea.left,
      right: safeArea.right,
      top: safeArea.top,
    );
  }
}
