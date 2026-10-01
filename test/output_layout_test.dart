import 'dart:io';

import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:app_deploy_screenshots/src/output/output_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.systemTemp.createTempSync('ads_output_').path;
  tearDownAll(() => Directory(root).deleteSync(recursive: true));

  String path(
    OutputLayout layout,
    Device device, {
    ScreenshotVariant? variant,
    int? order,
  }) => layout.pathFor(
    device,
    ScreenshotContext(
      name: 'inbox',
      device: device,
      variant: variant ?? ScreenshotVariant.none,
      order: order,
    ),
  );

  group('OutputLayout.fastlane', () {
    const fastlane = OutputLayout.fastlane(root: 'fl');
    const french = ScreenshotVariant(locale: Locale('fr', 'FR'));

    test('puts iOS screenshots where deliver reads them', () {
      expect(
        path(fastlane, Device.appStoreIphone69, variant: french, order: 1),
        'fl/screenshots/fr-FR/01_inbox_app_store_iphone_6_9.png',
      );
      expect(
        path(fastlane, Device.appStoreIpad13),
        'fl/screenshots/en-US/inbox_app_store_ipad_13.png',
      );
    });

    test('puts Play screenshots where supply reads them', () {
      expect(
        path(fastlane, Device.playStorePhone, variant: french, order: 2),
        'fl/metadata/android/fr-FR/images/phoneScreenshots/02_inbox.png',
      );
      expect(
        path(fastlane, Device.playStorePhone, variant: ScreenshotVariant.dark),
        'fl/metadata/android/en-US/images/phoneScreenshots/inbox.dark.png',
      );
    });

    test('chooses the supply folder from the device size', () {
      String folder(Device d) => path(fastlane, d).split('/')[5];
      expect(folder(Device.playStorePhone), 'phoneScreenshots');
      expect(folder(Device.playStorePhoneTall), 'phoneScreenshots');
      expect(folder(Device.playStoreTablet7), 'sevenInchScreenshots');
      expect(folder(Device.playStoreTablet10), 'tenInchScreenshots');
      expect(folder(Device.playStoreWear), 'wearScreenshots');
      expect(folder(Device.playStoreChromebook), 'tenInchScreenshots');
    });
  });

  test('OutputLayout.folders keeps one folder per store slot', () {
    expect(
      path(
        const OutputLayout.folders('out'),
        Device.playStorePhone,
        variant: ScreenshotVariant.dark,
        order: 3,
      ),
      'out/android/play_store_phone/03_inbox.dark.png',
    );
  });

  testWidgets('forStores and writeReport use the same layout', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(color: Color(0xFF808080)),
      ),
    );
    final layout = OutputLayout.fastlane(root: '$root/fastlane');
    final records = await AppDeployScreenshots.forStores(
      tester,
      'home',
      order: 1,
      output: layout,
      devices: const [Device.appStoreIphone69, Device.playStorePhone],
      customPump: (t) => t.pump(),
    );
    expect(records.map((r) => r.path), [
      '$root/fastlane/screenshots/en-US/01_home_app_store_iphone_6_9.png',
      '$root/fastlane/metadata/android/en-US/images/phoneScreenshots/01_home.png',
    ]);
    await AppDeployScreenshots.writeReport(
      output: layout,
      tester: tester,
      contactSheets: false,
    );
    expect(File('$root/fastlane/manifest.json').existsSync(), isTrue);
  });
}
