import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:app_deploy_screenshots/src/output/png_encoder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/png.dart';

// Each test file writes to its own temp directory: files run in
// parallel, and a shared output folder lets one file's cleanup delete
// another's screenshots mid-run.
final root = Directory.systemTemp.createTempSync('ads_slides_').path;

bool isRed(Color c) => c.r > 0.8 && c.g < 0.25 && c.b < 0.25;
bool isGreen(Color c) => c.g > 0.8 && c.r < 0.25 && c.b < 0.25;
bool isWhite(Color c) => c.r > 0.9 && c.g > 0.9 && c.b > 0.9;
bool isDark(Color c) => c.r < 0.2 && c.g < 0.2 && c.b < 0.2;

/// A solid colour image of [w] x [h] as PNG bytes.
Uint8List solidPng(int w, int h, List<int> rgb) {
  final pixels = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    pixels.setAll(i * 4, [...rgb, 255]);
  }
  return PngEncoder.encodeRgba(pixels, w, h);
}

void main() {
  tearDownAll(() {
    final dir = Directory(root);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('widgetForStores', () {
    testWidgets('writes every store size exactly, and leaves the app alone', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: Text('THE APP')));
      final records = await AppDeployScreenshots.widgetForStores(
        tester,
        'hero',
        root: '$root/hero',
        order: 1,
        builder: (context, shot) => const ColoredBox(color: Color(0xFFFF0000)),
      );

      expect(records, hasLength(5));
      for (final r in records) {
        final png = await DecodedPng.read(tester, r.path);
        final expected = r.context.device.pixelSize;
        expect(
          (png.width, png.height),
          (expected.width.toInt(), expected.height.toInt()),
          reason: r.path,
        );
        expect(
          png.pixel(png.width ~/ 2, png.height ~/ 2),
          const Color(0xFFFF0000),
        );
        expect(r.source, ScreenshotSource.widget);
      }
      expect(
        records.first.path,
        '$root/hero/ios/app_store_iphone_6_9/01_hero.png',
      );
      // The app under test was not replaced.
      expect(find.text('THE APP'), findsOneWidget);
    });

    testWidgets('gets the variant: dark theme and right-to-left text', (
      tester,
    ) async {
      final seen = <String>[];
      final records = await AppDeployScreenshots.widgetForStores(
        tester,
        'themed',
        root: '$root/themed',
        devices: const [Device.appStoreIphone69],
        variants: [
          ScreenshotVariant.dark,
          const ScreenshotVariant(locale: Locale('ar')),
        ],
        builder: (context, shot) {
          seen.add(
            '${Theme.of(context).brightness.name} '
            '${Directionality.of(context).name} ${shot.locale.languageCode}',
          );
          return const Scaffold();
        },
      );
      expect(seen, ['dark ltr en', 'light rtl ar']);
      final dark = await DecodedPng.read(tester, records.first.path);
      expect(isDark(dark.pixel(10, 10)), isTrue, reason: 'dark Scaffold');
    });
  });

  group('posterForStores', () {
    testWidgets('composes background, caption and decorations with no device', (
      tester,
    ) async {
      final logo = solidPng(40, 20, [0, 255, 0]);
      final records = await AppDeployScreenshots.posterForStores(
        tester,
        'welcome',
        root: '$root/poster',
        order: 1,
        devices: const [Device.appStoreIphone69, Device.playStorePhone],
        frame: MarketingFrame(
          background: const FrameBackground.solid(Color(0xFFFF0000)),
          caption: const Caption(headline: 'Simple. Reliable. Private.'),
          decorations: [
            FrameDecoration.image(
              logo,
              width: 100,
              alignment: Alignment.bottomCenter,
            ),
            const FrameDecoration.widget(
              ColoredBox(color: Color(0xFF00FF00)),
              size: Size(60, 30),
              alignment: Alignment.center,
              countsAsText: true,
            ),
          ],
        ),
      );

      for (final r in records) {
        final png = await DecodedPng.read(tester, r.path);
        final w = png.width.toDouble(), h = png.height.toDouble();
        expect(r.source, ScreenshotSource.poster);
        // Red everywhere except caption, logo (bottom) and badge (centre).
        expect(
          png.fraction(Rect.fromLTWH(0, h * 0.3, w * 0.2, h * 0.4), isRed),
          1,
        );
        expect(
          png.fraction(
            Rect.fromLTWH(w * 0.4, h * 0.85, w * 0.2, h * 0.14),
            isGreen,
          ),
          greaterThan(0.1),
        );
        expect(
          png.fraction(
            Rect.fromLTWH(w * 0.48, h * 0.49, w * 0.04, h * 0.02),
            isGreen,
          ),
          1,
        );
        // Red is a dark background, so the caption is drawn in white.
        expect(
          png.fraction(Rect.fromLTWH(0, 0, w, h * 0.2), isWhite),
          greaterThan(0.005),
          reason: 'caption',
        );
      }

      await AppDeployScreenshots.writeReport(
        root: '$root/poster',
        tester: tester,
        contactSheets: false,
      );
      final manifest =
          jsonDecode(File('$root/poster/manifest.json').readAsStringSync())
              as Map;
      final entry = (manifest['screenshots'] as List).first as Map;
      expect(entry['source'], 'poster');
      expect(manifest['version'], 1);
    });

    testWidgets('countsAsText decorations raise the caption coverage', (
      tester,
    ) async {
      Future<double> coverage(bool counts) async {
        final r = await AppDeployScreenshots.posterForStores(
          tester,
          'cover_$counts',
          root: '$root/coverage',
          devices: const [Device.playStorePhone],
          frame: MarketingFrame(
            caption: const Caption(headline: 'Headline'),
            decorations: [
              FrameDecoration.widget(
                const SizedBox(),
                size: const Size(200, 100),
                countsAsText: counts,
              ),
            ],
          ),
        );
        return r.single.captionCoverage!;
      }

      // Area-normalised: a 200 x 100 pt badge adds 200 * 100 / (440 * 956)
      // of any canvas, whatever its pixel size.
      final added = await coverage(true) - await coverage(false);
      expect(added, closeTo(200 * 100 / (440 * 956), 1e-3));
    });

    testWidgets('a builder returning null is a clear error', (tester) async {
      Object? error;
      try {
        await AppDeployScreenshots.posterForStores(
          tester,
          'none',
          root: '$root/none',
          devices: const [Device.playStorePhone],
          frame: ScreenshotFrame.builder((_) => null),
        );
      } catch (e) {
        error = e;
      }
      expect(error, isA<ArgumentError>());
    });
  });

  testWidgets('decorations sit on screenshot frames too, behind or in front', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(color: Color(0xFF808080)),
      ),
    );
    final logo = solidPng(10, 10, [0, 255, 0]);
    Future<DecodedPng> shoot(bool behind) async {
      final r = await AppDeployScreenshots.byDevice(
        tester,
        'deco_$behind',
        device: Device.appStoreIphone69,
        fileName: '$root/deco_$behind.png',
        customPump: (t) => t.pump(),
        frame: MarketingFrame(
          device: const DeviceStyle.screenOnly(shadow: null),
          decorations: [
            // Centred on the canvas, which the device covers.
            FrameDecoration.image(
              logo,
              width: 60,
              alignment: Alignment.center,
              behindDevice: behind,
            ),
          ],
        ),
      );
      return DecodedPng.read(tester, r.path);
    }

    final centre = const Rect.fromLTWH(640, 1414, 40, 40);
    expect(
      (await shoot(false)).fraction(centre, isGreen),
      1,
      reason: 'in front',
    );
    expect(
      (await shoot(true)).fraction(centre, isGreen),
      0,
      reason: 'hidden behind',
    );
  });
}
