library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden_toolkit.dart';

Future<void> _twoPumps(Device device, WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// Function definition for allowing for device or test setup to occur for each device configuration under test
typedef DeviceSetup = Future<void> Function(Device device, WidgetTester tester);

/// This [appDeployScreenshot] will run [scenarios] for given [devices] list
///
/// Will output a single  golden file for each device in [devices] and will append device name to png file
///
/// [name] is a file name output, must NOT include extension like .png
///
/// [finder] optional finder, defaults to [WidgetsApp]
///
/// [customPump] optional pump function, see [CustomPump] documentation
///
/// [deviceSetup] allows custom setup after the window changes size.
/// Takes two pumps to modify the device size. It could take more if the widget tree uses widgets that schedule builds for the next run loop
/// e.g. StreamBuilder, FutureBuilder
///
/// [devices] list of devices to run the tests
Future<void> appDeployScreenshot(
  WidgetTester tester,
  String name, {
  Finder? finder,
  CustomPump? customPump,
  DeviceSetup? deviceSetup,
  List<Device>? devices,
}) async {
  assert(devices == null || devices.isNotEmpty);
  final deviceSetupPump = deviceSetup ?? _twoPumps;
  final defaultDevices = AppDeployToolkit.configuration.defaultDevices;

  for (final device in devices ?? defaultDevices) {
    await tester.binding.runWithDeviceOverrides(
      device,
      body: () async {
        await deviceSetupPump(device, tester);
        await captureScreenshot(
          tester,
          name,
          customPump: customPump,
          finder: finder,
          device: device,
          fileNameFactory: AppDeployToolkit.configuration.deviceFileNameFactory,
        );
      },
    );
  }
}
