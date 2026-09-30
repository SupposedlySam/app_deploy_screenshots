import 'dart:io';

import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/png.dart';

/// Regressions for per-device capture: setup, image decoding and safe area
/// must all happen for every device, not once for the first.
void main() {
  const root = 'app_deploy_screenshots/per_device';
  const devices = [Device.iphone16Pro, Device.ipadProM4];

  tearDownAll(() {
    final dir = Directory(root);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  // Screens that never settle must still be capturable.
  Future<void> fixedPump(WidgetTester t) =>
      t.pump(const Duration(milliseconds: 16));

  testWidgets('runs deviceSetup once per device, under that device', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final seen = <String>[];

    await AppDeployScreenshots.byDevices(
      tester,
      'setup',
      devices: devices,
      customPump: fixedPump,
      fileNameBuilder: (d) => '$root/${d.name}.setup.png',
      deviceSetup: (device, tester) async {
        await tester.pump();
        seen.add('${device.name}@${tester.view.physicalSize}');
      },
    );

    expect(seen, [
      'iphone16_pro@Size(1179.0, 2556.0)',
      'ipad_pro_m4@Size(2064.0, 2752.0)',
    ]);
  });

  testWidgets('decodes images laid out again at each device size', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) => ListView(
              // A new key per width forces a fresh Image, and a fresh decode,
              // at every device size, as a responsive list would.
              key: ValueKey(constraints.maxWidth),
              children: [
                Image.memory(
                  redPng,
                  height: 300,
                  width: constraints.maxWidth,
                  fit: BoxFit.fill,
                  cacheWidth: constraints.maxWidth.toInt(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await AppDeployScreenshots.byDevices(
      tester,
      'images',
      devices: devices,
      customPump: fixedPump,
      fileNameBuilder: (d) => '$root/${d.name}.images.png',
    );

    for (final device in devices) {
      final png = await DecodedPng.read(
        tester,
        '$root/${device.name}.images.png',
      );
      final dpr = device.devicePixelRatio;
      // ListView pads its content below the status bar inset.
      final top = device.safeArea.top;
      final width = png.width.toDouble();
      final imageBand = Rect.fromLTWH(0, top * dpr, width, 300 * dpr);
      final belowImage = Rect.fromLTWH(0, (top + 320) * dpr, width, 100);

      expect(
        png.fraction(imageBand, isRed),
        greaterThan(0.99),
        reason: device.name,
      );
      // Positive control: red is where the image is, and only there.
      expect(png.fraction(belowImage, isRed), 0, reason: device.name);
    }
  });

  testWidgets('applies safe area in logical points', (tester) async {
    final paddings = <String, EdgeInsets>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            paddings['${MediaQuery.sizeOf(context)}'] = MediaQuery.paddingOf(
              context,
            );
            return const Scaffold();
          },
        ),
      ),
    );

    await AppDeployScreenshots.byDevices(
      tester,
      'safe_area',
      devices: devices,
      customPump: fixedPump,
      fileNameBuilder: (d) => '$root/${d.name}.safe_area.png',
    );

    expect(paddings['${Device.iphone16Pro.size}'], Device.iphone16Pro.safeArea);
    expect(paddings['${Device.ipadProM4.size}'], Device.ipadProM4.safeArea);
    expect(Device.iphone16Pro.safeArea.top, 62);
  });
}
