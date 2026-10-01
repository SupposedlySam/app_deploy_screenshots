import 'dart:io';

import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/png.dart';

void main() {
  final root = Directory.systemTemp.createTempSync('ads_listing_').path;
  tearDownAll(() => Directory(root).deleteSync(recursive: true));

  const brand = MarketingFrame(
    background: FrameBackground.solid(Color(0xFF0000FF)),
    caption: Caption(headline: 'Shared headline'),
  );
  bool isBlue(Color c) => c.b > 0.8 && c.r < 0.2 && c.g < 0.2;
  bool isWhite(Color c) => c.r > 0.9 && c.g > 0.9 && c.b > 0.9;

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(color: Color(0xFF808080)),
    ),
  );

  testWidgets('numbers slides in the order they are added, across kinds', (
    tester,
  ) async {
    await pumpApp(tester);
    final listing = StoreListing(
      tester,
      devices: const [Device.appStoreIphone69],
      output: OutputLayout.folders('$root/order'),
      frame: brand,
      customPump: (t) => t.pump(),
    );
    await listing.poster('welcome');
    await listing.screenshot('home');
    await listing.widget('stats', builder: (_, _) => const SizedBox());
    expect(listing.nextOrder, 4);
    expect(listing.records.map((r) => r.path.split('/').last), [
      '01_welcome.png',
      '02_home.png',
      '03_stats.png',
    ]);
    expect(listing.records.map((r) => r.source), [
      ScreenshotSource.poster,
      ScreenshotSource.app,
      ScreenshotSource.widget,
    ]);
  });

  testWidgets('a slide caption replaces the shared one and keeps the design', (
    tester,
  ) async {
    await pumpApp(tester);
    final captions = <String>[];
    final listing = StoreListing(
      tester,
      devices: const [Device.appStoreIphone69],
      output: OutputLayout.folders('$root/caption'),
      variants: ScreenshotVariant.matrix(
        locales: const [Locale('en'), Locale('fr')],
      ),
      frame: ScreenshotFrame.builder((c) {
        return brand;
      }),
    );
    final records = await listing.poster(
      'hello',
      captionFor: (shot) {
        final text = shot.locale.languageCode == 'fr' ? 'Bonjour' : 'Hello';
        captions.add(text);
        return Caption(headline: text);
      },
    );
    expect(captions, ['Hello', 'Bonjour']);
    final png = await DecodedPng.read(tester, records.first.path);
    final w = png.width.toDouble();
    // Shared design kept: blue background. New caption drawn: white ink.
    expect(png.pixel(10, png.height - 10), const Color(0xFF0000FF));
    expect(
      png.fraction(Rect.fromLTWH(0, 100, w, 200), isWhite),
      greaterThan(0.005),
    );
    expect(png.fraction(Rect.fromLTWH(0, 600, w, 600), isBlue), 1);
  });

  testWidgets(
    'a framed screenshot lays its caption out in the locale direction',
    (tester) async {
      await pumpApp(tester);
      final listing = StoreListing(
        tester,
        devices: const [Device.appStoreIphone69],
        output: OutputLayout.folders('$root/direction'),
        variants: const [
          ScreenshotVariant(locale: Locale('en')),
          ScreenshotVariant(locale: Locale('ar')),
        ],
        frame: brand,
        customPump: (t) => t.pump(),
      );
      final records = await listing.screenshot(
        'start',
        caption: const Caption(headline: 'Hi', textAlign: TextAlign.start),
      );
      final ltr = await DecodedPng.read(tester, records[0].path);
      final rtl = await DecodedPng.read(tester, records[1].path);
      final w = ltr.width.toDouble();
      double side(DecodedPng png, double left) =>
          png.fraction(Rect.fromLTWH(left, 0, w / 2, 500), isWhite, step: 2);
      // Start is left in English (the control) and right in Arabic.
      expect(side(ltr, 0), greaterThan(0.002));
      expect(side(ltr, w / 2), 0);
      expect(side(rtl, w / 2), greaterThan(0.002));
      expect(side(rtl, 0), 0);
    },
  );

  testWidgets('writeReport writes the manifest for the listing output', (
    tester,
  ) async {
    await pumpApp(tester);
    final listing = StoreListing(
      tester,
      devices: const [Device.playStorePhone],
      output: OutputLayout.fastlane(root: '$root/fastlane'),
    );
    await listing.poster('welcome', caption: const Caption(headline: 'Hi'));
    await listing.writeReport(contactSheets: false);
    expect(File('$root/fastlane/manifest.json').existsSync(), isTrue);
  });

  testWidgets('a poster with nothing to draw is a clear error', (tester) async {
    final listing = StoreListing(
      tester,
      devices: const [Device.playStorePhone],
      output: OutputLayout.folders('$root/empty'),
    );
    Object? error;
    try {
      await listing.poster('empty');
    } catch (e) {
      error = e;
    }
    expect(error, isA<ArgumentError>());
  });
}
