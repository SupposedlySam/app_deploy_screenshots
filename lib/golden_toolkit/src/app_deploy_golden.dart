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

/// Creates all ios and android screnshots based on app store guidelines
///
/// iPhone: Adding accurate screenshots of your app on the newest devices can help you represent the app's user experience. Keep in mind that we'll use these screenshots for all display sizes and localizations. Screenshots are only required for iOS apps, and only the first 3 will be used on the app installation sheets.
///   6.9": Drag up to 3 app previews and 10 screenshots here for iPhone 6.7" or 6.9" Displays. (1320 × 2868px, 2868 × 1320px, 1290 × 2796px or 2796 × 1290px)
///   6.5": Drag up to 3 app previews and 10 screenshots here. (1242 × 2688px, 2688 × 1242px, 1284 × 2778px or 2778 × 1284px)
///   iPad-13: Drag up to 3 app previews and 10 screenshots here for iPad 12.9" or 13" Displays. (2064 × 2752px, 2752 × 2064px, 2048 × 2732px or 2732 × 2048px)
/// android:
///   phone: Upload 2-8 phone screenshots. Screenshots must be PNG or JPEG, up to 8 MB each, 16:9 or 9:16 aspect ratio, with each side between 320 px and 3,840 px
///   tablet-7: Upload up to eight 7-inch tablet screenshots. Screenshots must be PNG or JPEG, up to 8 MB each, 16:9 or 9:16 aspect ratio, with each side between 320 px and 3,840 px
///   tablet-10: Upload up to eight 10-inch tablet screenshots. Screenshots must be PNG or JPEG, up to 8 MB each, 16:9 or 9:16 aspect ratio, with each side between 1,080 px and 7,680 px
///   chromebook: Upload 4-8 screenshots. Screenshots must be PNG or JPEG, up to 8 MB each, 16:9 or 9:16 aspect ratio, with each side between 1,080 px and 7,680 px
Future<void> createAllByPlatformAndDevice(
  WidgetTester tester,
  String name, {
  Finder? finder,
  CustomPump? customPump,
}) async {
  final iosDevices = Device.byPlatform(DevicePlatform.ios);

  final androidDevices = Device.byPlatform(DevicePlatform.android);

  final devices = [...iosDevices, ...androidDevices];

  for (final device in devices) {
    await tester.binding.runWithDeviceOverrides(
      device,
      body: () async {
        await _twoPumps(device, tester);
        await captureScreenshot(
          tester,
          name,
          customPump: customPump,
          finder: finder,
          device: device,
          fileNameFactory: (name, device) =>
              'app_deploy_screenshots/${device.platform.name}/${device.displaySize.label}_${device.name}/$name.png',
        );
      },
    );
  }
}
