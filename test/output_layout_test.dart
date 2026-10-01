import 'dart:io';

import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
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

    String folder(Device d) => path(fastlane, d).split('/')[5];

    test('chooses the supply folder from the device type', () {
      expect(folder(Device.playStorePhone), 'phoneScreenshots');
      expect(folder(Device.playStorePhoneTall), 'phoneScreenshots');
      expect(folder(Device.playStoreTablet7), 'sevenInchScreenshots');
      expect(folder(Device.playStoreTablet10), 'tenInchScreenshots');
      expect(folder(Device.playStoreWear), 'wearScreenshots');
      // 960 dp across: a size-only guess would call it a 10" tablet.
      expect(folder(Device.androidTV), 'tvScreenshots');
    });

    test('falls back to the size for a device without a type', () {
      Device custom(double w, double h) => Device(
        name: 'custom',
        size: Size(w, h),
        platform: DevicePlatform.android,
      );
      expect(folder(custom(400, 800)), 'phoneScreenshots');
      expect(folder(custom(600, 960)), 'sevenInchScreenshots');
      expect(folder(custom(800, 1280)), 'tenInchScreenshots');
      expect(folder(custom(200, 200)), 'wearScreenshots');
    });

    test('refuses what supply would misfile, before capturing', () {
      expect(
        () => fastlane.check(
          const [Device.playStoreChromebook],
          const [ScreenshotVariant.none],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('no Chromebook screenshot folder'),
          ),
        ),
      );
      // Light and dark of one locale would both upload.
      expect(
        () => fastlane.check(
          const [Device.playStorePhone],
          [ScreenshotVariant.light, ScreenshotVariant.dark],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('en-US folder'),
          ),
        ),
      );
      // The control: one variant per locale, on every store device.
      fastlane.check(
        const [...Device.appStore, ...Device.playStore],
        ScreenshotVariant.matrix(
          brightnesses: const [Brightness.dark],
          locales: const [Locale('en', 'US'), Locale('fr', 'FR')],
        ),
      );
      // Folders hold anything.
      const OutputLayout.folders().check(
        const [Device.playStoreChromebook],
        const [ScreenshotVariant.light, ScreenshotVariant.dark],
      );
    });

    test('names each locale folder the way that store does', () {
      String folders(Locale locale) {
        final variant = ScreenshotVariant(locale: locale);
        final ios = path(fastlane, Device.appStoreIphone69, variant: variant);
        final play = path(fastlane, Device.playStorePhone, variant: variant);
        return '${ios.split('/')[2]} ${play.split('/')[3]}';
      }

      expect(folders(const Locale('fr', 'FR')), 'fr-FR fr-FR');
      expect(folders(const Locale('ja', 'JP')), 'ja ja-JP');
      expect(folders(const Locale('ja')), 'ja ja-JP');
      expect(folders(const Locale('de')), 'de-DE de-DE');
      expect(folders(const Locale('he', 'IL')), 'he iw-IL');
      expect(folders(const Locale('nb', 'NO')), 'no no-NO');
      expect(folders(const Locale('zh', 'CN')), 'zh-Hans zh-CN');
      expect(
        folders(
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ),
        'zh-Hant zh-TW',
      );
      expect(folders(const Locale('zh', 'HK')), 'zh-Hant zh-HK');
    });

    test('refuses a locale a store has no folder for', () {
      Matcher fails(String message) => throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains(message),
        ),
      );
      // Too vague: which English?
      expect(
        () => fastlane.check(
          const [Device.appStoreIphone69],
          const [ScreenshotVariant(locale: Locale('en'))],
        ),
        fails('en-AU, en-CA, en-GB, en-US'),
      );
      // Play has Indian English; the App Store doesn't.
      const indian = [ScreenshotVariant(locale: Locale('en', 'IN'))];
      fastlane.check(const [Device.playStorePhone], indian);
      expect(
        () => fastlane.check(const [Device.appStoreIphone69], indian),
        fails('The App Store has no screenshot folder for en-IN'),
      );
      expect(
        () => fastlane.check(
          const [Device.playStorePhone],
          const [ScreenshotVariant(locale: Locale('tlh'))],
        ),
        fails('does not list that language'),
      );
    });

    testWidgets('StoreListing checks its layout when it is made', (
      tester,
    ) async {
      expect(
        () => StoreListing(
          tester,
          output: fastlane,
          variants: const [ScreenshotVariant.light, ScreenshotVariant.dark],
        ),
        throwsArgumentError,
      );
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
