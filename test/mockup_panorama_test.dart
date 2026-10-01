import 'dart:io';

import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/png.dart';

void main() {
  final root = Directory.systemTemp.createTempSync('ads_mockup_').path;
  tearDownAll(() => Directory(root).deleteSync(recursive: true));

  const devices = [Device.appStoreIphone69];
  bool isGrey(Color c) =>
      (c.r - 0.5).abs() < 0.06 &&
      (c.g - 0.5).abs() < 0.06 &&
      (c.b - 0.5).abs() < 0.06;
  bool isRed(Color c) => c.r > 0.8 && c.g < 0.2 && c.b < 0.2;

  Future<void> pumpApp(WidgetTester tester, Color color) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(color: color),
    ),
  );

  testWidgets('captureScreens finds each screen by device and variant', (
    tester,
  ) async {
    await pumpApp(tester, const Color(0xFF808080));
    final captures = await AppDeployScreenshots.captureScreens(
      tester,
      devices: const [Device.appStoreIphone69, Device.playStorePhone],
      variants: const [ScreenshotVariant.light, ScreenshotVariant.dark],
      customPump: (t) => t.pump(),
    );
    expect(captures.all, hasLength(4));
    final shot = ScreenshotContext(
      name: 'x',
      device: ScreenshotVariant.dark.applyTo(Device.playStorePhone),
      variant: ScreenshotVariant.dark,
    );
    final screen = captures.of(shot);
    expect(screen.device.name, 'play_store_phone');
    expect(screen.device.brightness, Brightness.dark);
    expect((screen.image.width, screen.image.height), (1080, 1920));

    Object? error;
    try {
      captures.of(
        const ScreenshotContext(name: 'x', device: Device.appStoreIpad13),
      );
    } catch (e) {
      error = e;
    }
    expect(error, isA<StateError>(), reason: 'not captured');
  });

  testWidgets('DeviceMockup lays captured screens out in a widget slide', (
    tester,
  ) async {
    await pumpApp(tester, const Color(0xFF808080));
    final before = await AppDeployScreenshots.captureScreens(
      tester,
      devices: devices,
      customPump: (t) => t.pump(),
    );
    await pumpApp(tester, const Color(0xFFFF0000));
    final after = await AppDeployScreenshots.captureScreens(
      tester,
      devices: devices,
      customPump: (t) => t.pump(),
    );

    final records = await AppDeployScreenshots.widgetForStores(
      tester,
      'before_after',
      devices: devices,
      output: OutputLayout.folders(root),
      builder: (context, shot) => ColoredBox(
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: Center(child: DeviceMockup(screen: before.of(shot))),
            ),
            Expanded(
              child: Center(child: DeviceMockup(screen: after.of(shot))),
            ),
          ],
        ),
      ),
    );
    final png = await DecodedPng.read(tester, records.single.path);
    final w = png.width.toDouble(), h = png.height.toDouble();
    expect(
      png.fraction(Rect.fromLTWH(w * 0.2, h * 0.45, w * 0.1, h * 0.1), isGrey),
      greaterThan(0.95),
    );
    expect(
      png.fraction(Rect.fromLTWH(w * 0.7, h * 0.45, w * 0.1, h * 0.1), isRed),
      greaterThan(0.95),
    );
  });

  testWidgets('panoramaForStores slices one strip into consecutive slides', (
    tester,
  ) async {
    final records = await AppDeployScreenshots.panoramaForStores(
      tester,
      ['plan', 'book', 'go'],
      order: 2,
      devices: devices,
      output: OutputLayout.folders(root),
      builder: (context, shot) => Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Colors.white)),
          // A bar across the first boundary (at 440 points).
          const Positioned(
            left: 340,
            width: 200,
            top: 400,
            height: 50,
            child: ColoredBox(color: Color(0xFFFF0000)),
          ),
        ],
      ),
    );

    expect(records.map((r) => r.path.split('/').last), [
      '02_plan.png',
      '03_book.png',
      '04_go.png',
    ]);
    final first = await DecodedPng.read(tester, records[0].path);
    final second = await DecodedPng.read(tester, records[1].path);
    expect((first.width, first.height), (1320, 2868));
    // The bar runs off the right edge of slide 1 and on at the left of 2.
    final y = (425 * 3).toDouble();
    expect(first.fraction(Rect.fromLTWH(1300, y, 20, 10), isRed), 1);
    expect(second.fraction(Rect.fromLTWH(0, y, 20, 10), isRed), 1);
    expect(
      second.fraction(Rect.fromLTWH(400, y, 20, 10), isRed),
      0,
      reason: 'bar ends',
    );
  });
}
