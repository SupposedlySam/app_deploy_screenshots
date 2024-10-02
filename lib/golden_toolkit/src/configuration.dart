import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import '../golden_toolkit.dart';

/// Manages global state & behavior for the App Deploy Toolkit
/// This is a singleton so that it can be easily configured in one place
/// and shared across tests
class AppDeployToolkit {
  AppDeployToolkit._();

  static final AppDeployToolkitConfiguration _configuration =
      AppDeployToolkitConfiguration();

  /// Applies a AppDeployToolkitConfiguration to a block of code to effectively provide a scoped
  /// singleton. The configuration will apply to just the injected body function.
  ///
  /// In most cases, this can be applied in your flutter_test_config.dart to wrap every test in its own zone
  static T runWithConfiguration<T>(
    T Function() body, {
    required AppDeployToolkitConfiguration config,
  }) {
    return runZoned<T>(
      body,
      zoneValues: <dynamic, dynamic>{#goldentoolkit.config: config},
    );
  }

  /// reads the current configuration for based on the active zone, or else falls back to the global static state.
  static AppDeployToolkitConfiguration get configuration {
    return Zone.current[#goldentoolkit.config] ?? _configuration;
  }
}

/// A func that will be evaluated at runtime to determine if the golden assertion should be skipped
typedef SkipGoldenAssertion = bool Function();

/// A factory to determine an actual file name/path from a given name.
///
/// See also:
/// * [screenMatchesGolden], which uses such a factory to determine the file name passed to [matchesGoldenFile].
/// * [AppDeployToolkitConfiguration] to configure a global file name factory.
typedef FileNameFactory = String Function(String name);

/// A factory to determine a file name/path from a name and a device.
///
/// See also:
/// * [multiScreenGolden], which uses such a factory to determine the file name passed to [matchesGoldenFile].
/// * [AppDeployToolkitConfiguration] to configure a global device file name factory.
typedef DeviceFileNameFactory = String Function(String name, Device device);

/// A function that primes all needed assets for the given [tester].
///
/// For ready to use implementations see:
/// * [legacyPrimeAssets], which is the default [PrimeAssets] used by the global configuration by default.
/// * [defaultPrimeAssets], which just waits for all [Image] widgets in the widget tree to finish decoding.
typedef PrimeAssets = Future<void> Function(WidgetTester tester);

/// Represents configuration options for the GoldenToolkit. These are akin to environmental flags.
@immutable
class AppDeployToolkitConfiguration {
  /// AppDeployToolkitConfiguration constructor
  ///
  /// [skipGoldenAssertion] a func that returns a bool as to whether the golden assertion should be skipped.
  /// A typical example may be to skip when the assertion is invoked on certain platforms. For example: () => !Platform.isMacOS
  ///
  /// [fileNameFactory] a func used to decide the final filename for screenMatchesGolden() invocations
  ///
  /// [deviceFileNameFactory] a func used to decide the final filename for multiScreenGolden() invocations
  ///
  /// [primeAssets] a func that is used to ensure that all images have been decoded before trying to render
  ///
  /// [enableRealShadows] a flag indicating that we want the goldens to have real shadows (instead of opaque shadows)
  ///
  /// [tags] a string or iterable of strings used to tag golden tests with
  AppDeployToolkitConfiguration({
    this.skipGoldenAssertion = _doNotSkip,
    this.fileNameFactory = defaultFileNameFactory,
    this.deviceFileNameFactory = defaultDeviceFileNameFactory,
    this.primeAssets = defaultPrimeAssets,
    this.defaultDevices = const [Device.phone, Device.tabletLandscape],
    this.enableRealShadows = false,
    this.tags = const ['golden'],
  }) : assert(defaultDevices.isNotEmpty);

  /// a function indicating whether a golden assertion should be skipped
  final SkipGoldenAssertion skipGoldenAssertion;

  /// A function to determine the file name/path [screenMatchesGolden] uses to call [matchesGoldenFile].
  final FileNameFactory fileNameFactory;

  /// A function to determine the file name/path [multiScreenGolden] uses to call [matchesGoldenFile].
  final DeviceFileNameFactory deviceFileNameFactory;

  /// A function that primes all needed assets for the given [tester]. Defaults to [defaultPrimeAssets].
  final PrimeAssets primeAssets;

  /// the default set of devices to use for multiScreenGolden assertions
  final List<Device> defaultDevices;

  /// whether shadows should have the real rendering
  /// by default, Widget tests use opaque shadows to avoid golden test failures
  /// See [debugDisableShadows] for more context
  final bool enableRealShadows;

  /// the tags golden test are tagged with, defaults to ['golden'],
  /// must be null, String or Iterable<String>
  final Object? tags;

  /// Copies the configuration with the given values overridden.
  AppDeployToolkitConfiguration copyWith({
    SkipGoldenAssertion? skipGoldenAssertion,
    FileNameFactory? fileNameFactory,
    DeviceFileNameFactory? deviceFileNameFactory,
    PrimeAssets? primeAssets,
    List<Device>? defaultDevices,
    bool? enableRealShadows,
    Object? tags,
  }) {
    return AppDeployToolkitConfiguration(
      skipGoldenAssertion: skipGoldenAssertion ?? this.skipGoldenAssertion,
      fileNameFactory: fileNameFactory ?? this.fileNameFactory,
      deviceFileNameFactory:
          deviceFileNameFactory ?? this.deviceFileNameFactory,
      primeAssets: primeAssets ?? this.primeAssets,
      defaultDevices: defaultDevices ?? this.defaultDevices,
      enableRealShadows: enableRealShadows ?? this.enableRealShadows,
      tags: tags ?? this.tags,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppDeployToolkitConfiguration &&
            runtimeType == other.runtimeType &&
            skipGoldenAssertion == other.skipGoldenAssertion &&
            fileNameFactory == other.fileNameFactory &&
            deviceFileNameFactory == other.deviceFileNameFactory &&
            primeAssets == other.primeAssets &&
            defaultDevices == other.defaultDevices &&
            enableRealShadows == other.enableRealShadows &&
            tags == other.tags;
  }

  @override
  int get hashCode =>
      skipGoldenAssertion.hashCode ^
      fileNameFactory.hashCode ^
      deviceFileNameFactory.hashCode ^
      primeAssets.hashCode ^
      defaultDevices.hashCode ^
      enableRealShadows.hashCode ^
      tags.hashCode;
}

bool _doNotSkip() => false;

/// This is the default file name factory which is used by [screenMatchesGolden] to determine the
/// actual file name for a golden test. The given [name] is the name passed into [screenMatchesGolden].
String defaultFileNameFactory(String name) {
  return 'app_deploy_screenshot/$name.png';
}

/// This is the default file name factory which is used by [multiScreenGolden] to determine the
/// actual file name for a golden test. The given [name] is the name passed into [multiScreenGolden].
String defaultDeviceFileNameFactory(String name, Device device) {
  return 'app_deploy_screenshots/${device.name}.$name.png';
}
