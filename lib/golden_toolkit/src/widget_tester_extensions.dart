import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'configuration.dart';
import 'device.dart';

/// Convenience extensions on WidgetTester
extension WidgetTesterImageLoadingExtensions on WidgetTester {
  /// Waits for images to decode. Use this to ensure that images are properly displayed
  /// in Goldens. The implementation of this can be configured as part of GoldenToolkitConfiguration
  ///
  /// If you have assets that are not loading with this implementation, please file an issue and we will explore solutions.
  Future<void> waitForAssets() => GoldenToolkit.configuration.primeAssets(this);
}

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
    await applyDeviceOverrides(device);
    try {
      await body();
    } finally {
      await resetDeviceOverrides();
    }
  }

  /// Configure the Test device to match the configuration of the supplied device
  ///
  /// Note: these settings will persist across multiple tests in the same file. It is recommended
  /// that you reset upon completion.
  ///
  /// [device] the desired configuration to apply
  ///
  Future<void> applyDeviceOverrides(Device device) async {
    await setSurfaceSize(Size(device.size.width, device.size.height));
    platformDispatcher.implicitView!.physicalSize =
        device.size * device.devicePixelRatio;
    platformDispatcher.implicitView!.devicePixelRatio = device.devicePixelRatio;
    platformDispatcher.textScaleFactorTestValue = device.textScale;
    platformDispatcher.platformBrightnessTestValue = device.brightness;
    platformDispatcher.implicitView!.padding = _FakeViewPadding(
      bottom: device.safeArea.bottom,
      left: device.safeArea.left,
      right: device.safeArea.right,
      top: device.safeArea.top,
    );
  }

  /// Resets any configuration that may be been specified by applyDeviceOverrides
  ///
  /// Only needs to be called if you are concerned about the result of applyDeviceOverrides bleeding over across tests.
  Future<void> resetDeviceOverrides() async {
    // there is an untested assumption that clearing these specific values is cheaper than
    // calling binding.window.clearAllTestValues().
    platformDispatcher.implicitView!.resetPhysicalSize();
    platformDispatcher.implicitView!.resetDevicePixelRatio();
    platformDispatcher.clearPlatformBrightnessTestValue();
    platformDispatcher.implicitView!.resetPadding();
    platformDispatcher.clearTextScaleFactorTestValue();
    await setSurfaceSize(null);
  }
}

/// Convenience extensions for configuring elements of the TestView
extension TestViewExtensions on TestFlutterView {
  /// convenience wrapper for configuring the padding
  ///
  /// [safeArea] specifies the safe area insets for all 4 edges that you wish to simulate
  ///
  set safeAreaTestValue(EdgeInsets safeArea) {
    padding = _FakeViewPadding(
      bottom: safeArea.bottom,
      left: safeArea.left,
      right: safeArea.right,
      top: safeArea.top,
    );
  }
}

class _FakeViewPadding implements FakeViewPadding {
  const _FakeViewPadding({
    this.bottom = 0,
    this.left = 0,
    this.right = 0,
    this.top = 0,
  });

  @override
  final double bottom;

  @override
  final double left;

  @override
  final double right;

  @override
  final double top;
}
