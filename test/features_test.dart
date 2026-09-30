import 'dart:convert';
import 'dart:io';

import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:app_deploy_screenshots/src/png_encoder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_app.dart';
import 'support/png.dart';

const root = 'app_deploy_screenshots/features';

/// A known picture: a grey screen with a blue 100×60 box at (40, 200) and a
/// green 80×40 box at (40, 500), in logical points.
class _Blocks extends StatelessWidget {
  const _Blocks({this.overlay});

  static const blue = ValueKey('blue');
  static const green = ValueKey('green');
  final SystemUiOverlayStyle? overlay;

  @override
  Widget build(BuildContext context) {
    final body = Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF808080),
        child: Stack(
          children: [
            Positioned(
              left: 40,
              top: 200,
              child: Container(
                key: blue,
                width: 100,
                height: 60,
                color: const Color(0xFF0000FF),
              ),
            ),
            Positioned(
              left: 40,
              top: 500,
              child: Container(
                key: green,
                width: 80,
                height: 40,
                color: const Color(0xFF00FF00),
              ),
            ),
          ],
        ),
      ),
    );
    return overlay == null
        ? body
        : AnnotatedRegion<SystemUiOverlayStyle>(value: overlay!, child: body);
  }
}

Future<void> fixedPump(WidgetTester t) =>
    t.pump(const Duration(milliseconds: 16));

const phone = Device.appStoreIphone69; // 440×956 @3, 62pt status bar

Future<DecodedPng> shoot(
  WidgetTester tester,
  String file, {
  Device device = phone,
  StatusBarOverlay? statusBar,
  List<ScreenshotAnnotation> annotations = const [],
  ScreenshotFrame? frame,
}) async {
  await AppDeployScreenshots.byDevice(
    tester,
    file,
    device: device,
    fileName: '$root/$file.png',
    customPump: fixedPump,
    statusBar: statusBar,
    annotations: annotations,
    frame: frame,
  );
  return DecodedPng.read(tester, '$root/$file.png');
}

bool isGrey(Color c) => _near(c, const Color(0xFF808080));
bool isBlue(Color c) => _near(c, const Color(0xFF0000FF));
bool isGreen(Color c) => _near(c, const Color(0xFF00FF00));
bool isDark(Color c) => c.r < 0.2 && c.g < 0.2 && c.b < 0.2;
bool isWhite(Color c) => c.r > 0.9 && c.g > 0.9 && c.b > 0.9;
bool _near(Color a, Color b) =>
    (a.r - b.r).abs() < 0.06 &&
    (a.g - b.g).abs() < 0.06 &&
    (a.b - b.b).abs() < 0.06;

/// Logical rect on [phone] to image pixels.
Rect px(Rect logical, [double dpr = 3]) => Rect.fromLTRB(
  logical.left * dpr,
  logical.top * dpr,
  logical.right * dpr,
  logical.bottom * dpr,
);

void main() {
  tearDownAll(() {
    final dir = Directory(root);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('store presets', () {
    test('produce the exact pixel sizes the stores accept', () {
      expect(
        {
          for (final d in [...Device.appStore, ...Device.playStore])
            d.name: d.pixelSize,
        },
        {
          'app_store_iphone_6_9': const Size(1320, 2868),
          'app_store_ipad_13': const Size(2064, 2752),
          'play_store_phone': const Size(1080, 1920),
          'play_store_tablet_7': const Size(1224, 2176),
          'play_store_tablet_10': const Size(1620, 2880),
        },
      );
    });

    test('Play presets pass the Play rules and 20:9 phones do not', () {
      expect(
        Device.playStore.every((d) => d.meetsPlayStoreRequirements()),
        isTrue,
      );
      // 2400 × 1080: long side more than twice the short side.
      expect(Device.androidPhoneExtra.meetsPlayStoreRequirements(), isFalse);
    });

    testWidgets('forStores writes one upload-ready image per store slot', (
      tester,
    ) async {
      await tester.pumpWidget(const _Blocks());
      final records = await AppDeployScreenshots.forStores(
        tester,
        'home',
        root: '$root/stores',
        order: 3,
        customPump: fixedPump,
      );

      expect(records.map((r) => r.path), [
        '$root/stores/ios/app_store_iphone_6_9/03_home.png',
        '$root/stores/ios/app_store_ipad_13/03_home.png',
        '$root/stores/android/play_store_phone/03_home.png',
        '$root/stores/android/play_store_tablet_7/03_home.png',
        '$root/stores/android/play_store_tablet_10/03_home.png',
      ]);
      for (final r in records) {
        final header = File(r.path).readAsBytesSync().sublist(16, 26);
        final data = ByteData.sublistView(header);
        final device = r.context.device;
        expect(
          (data.getUint32(0), data.getUint32(4)),
          (device.pixelSize.width.toInt(), device.pixelSize.height.toInt()),
          reason: r.path,
        );
        expect(
          header[9],
          2,
          reason: '${r.path}: colour type 2 is RGB, no alpha',
        );
      }
    });
  });

  group('encodeOpaquePng', () {
    testWidgets(
      'writes RGB and composites translucent pixels over the background',
      (tester) async {
        final pixels = Uint8List.fromList([
          255, 0, 0, 255, // opaque red
          0, 0, 255, 128, // half-transparent blue
        ]);
        final bytes = encodeRgbaAsOpaquePng(pixels, 2, 1);
        expect(bytes[25], 2);
        final file = File('$root/encoder.png')..createSync(recursive: true);
        file.writeAsBytesSync(bytes);
        final png = await DecodedPng.read(tester, file.path);
        expect(png.pixel(0, 0), const Color(0xFFFF0000));
        // 50% blue over white.
        expect(png.pixel(1, 0), const Color(0xFF7F7FFF));
      },
    );
  });

  group('status bar', () {
    final bar = px(const Rect.fromLTWH(0, 0, 440, 62));

    testWidgets(
      'draws dark icons on a light app by default, only inside the inset',
      (tester) async {
        await tester.pumpWidget(const _Blocks());
        final plain = await shoot(tester, 'bar_none');
        final png = await shoot(
          tester,
          'bar_dark',
          statusBar: const StatusBarOverlay(),
        );

        expect(
          plain.fraction(bar, isDark, step: 2),
          0,
          reason: 'control: nothing there without it',
        );
        expect(png.fraction(bar, isDark, step: 2), greaterThan(0.01));
        expect(
          png.fraction(px(const Rect.fromLTWH(0, 62, 440, 100)), isGrey),
          1,
        );
      },
    );

    testWidgets("follows the app's SystemUiOverlayStyle", (tester) async {
      await tester.pumpWidget(
        const _Blocks(overlay: SystemUiOverlayStyle.light),
      );
      final png = await shoot(
        tester,
        'bar_light',
        statusBar: const StatusBarOverlay(),
      );

      expect(png.fraction(bar, isWhite, step: 2), greaterThan(0.01));
      expect(png.fraction(bar, isDark, step: 2), 0);
    });

    testWidgets('draws nothing on a device without a top inset', (
      tester,
    ) async {
      await tester.pumpWidget(const _Blocks());
      final png = await shoot(
        tester,
        'bar_zero',
        device: phone.copyWith(safeArea: EdgeInsets.zero),
        statusBar: const StatusBarOverlay(),
      );
      expect(png.fraction(bar, isGrey), 1);
    });
  });

  group('annotations', () {
    testWidgets('Spotlight dims everything except the target', (tester) async {
      await tester.pumpWidget(const _Blocks());
      final png = await shoot(
        tester,
        'spotlight',
        annotations: [
          Spotlight(
            find.byKey(_Blocks.blue),
            padding: EdgeInsets.zero,
            radius: 0,
          ),
        ],
      );

      expect(png.fraction(px(const Rect.fromLTWH(45, 205, 90, 50)), isBlue), 1);
      expect(
        png.fraction(px(const Rect.fromLTWH(45, 505, 70, 30)), isGreen),
        0,
        reason: 'dimmed',
      );
      expect(
        png.fraction(px(const Rect.fromLTWH(200, 300, 100, 100)), isGrey),
        0,
        reason: 'dimmed',
      );
    });

    testWidgets('Callout draws a bubble next to the target', (tester) async {
      await tester.pumpWidget(const _Blocks());
      final png = await shoot(
        tester,
        'callout',
        annotations: [
          Callout(
            find.byKey(_Blocks.blue),
            'Tap here',
            placement: CalloutPlacement.below,
          ),
        ],
      );
      bool bubble(Color c) => _near(c, const Color(0xFF1C1C1E));

      // Just below the box (60pt tall, from y=200), and not above it.
      expect(
        png.fraction(px(const Rect.fromLTWH(40, 275, 100, 10)), bubble),
        greaterThan(0.3),
      );
      expect(
        png.fraction(px(const Rect.fromLTWH(40, 150, 100, 40)), bubble),
        0,
      );
    });

    testWidgets('MagnifierInset enlarges the target', (tester) async {
      await tester.pumpWidget(const _Blocks());
      final plain = await shoot(tester, 'magnifier_none');
      final png = await shoot(
        tester,
        'magnifier',
        annotations: [
          MagnifierInset(
            find.byKey(_Blocks.green),
            zoom: 2,
            padding: EdgeInsets.zero,
          ),
        ],
      );
      final all = Rect.fromLTWH(
        0,
        0,
        png.width.toDouble(),
        png.height.toDouble(),
      );

      // 2× zoom: four times the green area, give or take the border.
      final ratio =
          png.fraction(all, isGreen, step: 3) /
          plain.fraction(all, isGreen, step: 3);
      expect(ratio, inInclusiveRange(3.5, 4.5));
    });

    testWidgets('a finder that matches nothing throws instead of skipping', (
      tester,
    ) async {
      await tester.pumpWidget(const _Blocks());
      Object? error;
      try {
        await shoot(
          tester,
          'missing',
          annotations: [Spotlight(find.byKey(const ValueKey('nope')))],
        );
      } catch (e) {
        error = e;
      }
      expect(error, isA<StateError>());
      expect(File('$root/missing.png').existsSync(), isFalse);
    });
  });

  group('MarketingFrame', () {
    testWidgets('places the screen on the canvas under the caption', (
      tester,
    ) async {
      await tester.pumpWidget(const _Blocks());
      final png = await shoot(
        tester,
        'frame',
        frame: const MarketingFrame(
          background: FrameBackground.solid(Color(0xFFFF0000)),
          caption: Caption(
            headline: 'Headline',
            headlineStyle: TextStyle(color: Color(0xFFFFFFFF)),
          ),
          bezel: null,
          shadow: false,
        ),
      );

      expect((png.width, png.height), (1320, 2868));
      final w = png.width.toDouble(), h = png.height.toDouble();
      // Background at the edges, caption ink in the top band, app below it.
      expect(png.fraction(Rect.fromLTWH(0, 0, w, 40), isRed), 1);
      expect(png.fraction(Rect.fromLTWH(0, h - 40, w, 40), isRed), 1);
      expect(
        png.fraction(Rect.fromLTWH(0, 100, w, 200), isWhite),
        greaterThan(0.02),
      );
      expect(png.fraction(Rect.fromLTWH(0, 100, w, 200), isGrey), 0);
      expect(
        png.fraction(Rect.fromLTWH(w * 0.4, h * 0.5, w * 0.2, h * 0.1), isGrey),
        greaterThan(0.9),
      );
    });

    testWidgets('canvasSize puts one device on another store canvas', (
      tester,
    ) async {
      await tester.pumpWidget(const _Blocks());
      final png = await shoot(
        tester,
        'frame_canvas',
        frame: const MarketingFrame(canvasSize: Size(1080, 1920)),
      );
      expect((png.width, png.height), (1080, 1920));
    });

    testWidgets('ScreenshotFrame.builder can opt a screenshot out', (
      tester,
    ) async {
      await tester.pumpWidget(const _Blocks());
      final png = await shoot(
        tester,
        'frame_none',
        frame: ScreenshotFrame.builder((_) => null),
      );
      expect((png.width, png.height), (1320, 2868));
      expect(png.pixel(10, 400), const Color(0xFF808080));
    });
  });

  group('variants', () {
    testWidgets(
      'render each brightness fully transitioned, with suffixed names',
      (tester) async {
        await tester.pumpWidget(const DemoApp());
        final records = await AppDeployScreenshots.byDevices(
          tester,
          'inbox',
          devices: const [Device.iphone16Pro],
          variants: const [ScreenshotVariant.dark, ScreenshotVariant.light],
          fileNameBuilder: (d) => '$root/variants/${d.name}/inbox.png',
          order: 1,
          customPump: fixedPump,
        );

        expect(records.map((r) => r.path), [
          '$root/variants/iphone16_pro/01_inbox.dark.png',
          '$root/variants/iphone16_pro/01_inbox.light.png',
        ]);
        // "Conversation 0" title. Implicit theme animations chain; a capture
        // that lands mid-way draws light-mode text in dark-mode colours.
        final title = px(const Rect.fromLTWH(72, 136, 110, 24));
        final dark = await DecodedPng.read(tester, records[0].path);
        final light = await DecodedPng.read(tester, records[1].path);
        expect(light.fraction(title, isDark, step: 1), greaterThan(0.02));
        expect(dark.fraction(title, isWhiteish, step: 1), greaterThan(0.02));
        expect(
          dark.fraction(title, isDark, step: 1),
          greaterThan(0.5),
          reason: 'dark background',
        );
      },
    );

    testWidgets('apply the locale through the platform', (tester) async {
      await tester.pumpWidget(const DemoApp());
      final seen = <String>[];
      final contexts = <String>[];
      await AppDeployScreenshots.byDevices(
        tester,
        'inbox',
        devices: const [Device.iphone16Pro],
        variants: ScreenshotVariant.matrix(
          locales: const [Locale('en'), Locale('fr')],
        ),
        fileNameBuilder: (d) => '$root/locales/inbox.png',
        customPump: (t) async {
          await fixedPump(t);
          seen.add(
            find.text('Messages').evaluate().isEmpty ? 'Inbox' : 'Messages',
          );
        },
        frame: ScreenshotFrame.builder((c) {
          contexts.add(c.locale.languageCode);
          return null;
        }),
      );
      expect(seen, ['Inbox', 'Messages']);
      expect(contexts, ['en', 'fr']);
      expect(File('$root/locales/inbox.fr.png').existsSync(), isTrue);
      expect(
        tester.platformDispatcher.locales,
        isNot(contains(const Locale('fr'))),
      );
    });

    test('matrix and suffixes', () {
      final m = ScreenshotVariant.matrix(
        brightnesses: const [Brightness.light, Brightness.dark],
        locales: const [Locale('en'), Locale('fr', 'CA')],
      );
      expect(m.map((v) => v.suffix), [
        'light.en',
        'light.fr_CA',
        'dark.en',
        'dark.fr_CA',
      ]);
      expect(ScreenshotVariant.none.suffix, '');
    });
  });

  testWidgets('capture draws real shadows and restores the test setting', (
    tester,
  ) async {
    expect(debugDisableShadows, isTrue, reason: 'flutter_test default');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFFFFFFFF),
          body: Center(
            child: Material(
              elevation: 12,
              color: Color(0xFFFFFFFF),
              child: SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      ),
    );
    final png = await shoot(tester, 'shadow');
    // With debugDisableShadows the edge is a solid black line; a real
    // shadow is a soft grey falloff with no black at all.
    final belowCard = px(const Rect.fromLTWH(170, 578, 100, 12));
    expect(png.fraction(belowCard, isDark, step: 1), 0);
    expect(
      png.fraction(belowCard, (c) => !isWhite(c), step: 1),
      greaterThan(0.2),
    );
    expect(debugDisableShadows, isTrue, reason: 'restored');
  });

  group('writeReport', () {
    testWidgets('writes a manifest and one contact sheet per folder', (
      tester,
    ) async {
      const reportRoot = '$root/report';
      await tester.pumpWidget(const _Blocks());
      for (final (order, name) in [(1, 'a'), (2, 'b')]) {
        await AppDeployScreenshots.forStores(
          tester,
          name,
          root: reportRoot,
          order: order,
          devices: const [Device.playStorePhone, Device.appStoreIpad13],
          customPump: fixedPump,
        );
      }
      // A stale entry whose file is gone must be dropped on merge.
      File('$reportRoot/manifest.json').writeAsStringSync(
        jsonEncode({
          'screenshots': [
            {'path': 'gone.png'},
          ],
        }),
      );

      await AppDeployScreenshots.writeReport(root: reportRoot, tester: tester);

      final manifest =
          jsonDecode(File('$reportRoot/manifest.json').readAsStringSync())
              as Map;
      final entries = (manifest['screenshots'] as List).cast<Map>();
      expect(entries.map((e) => e['path']), [
        'android/play_store_phone/01_a.png',
        'android/play_store_phone/02_b.png',
        'ios/app_store_ipad_13/01_a.png',
        'ios/app_store_ipad_13/02_b.png',
      ]);
      expect(entries.first, containsPair('width', 1080));
      expect(entries.first, containsPair('order', 1));

      final sheets = Directory(
        '$reportRoot/_review',
      ).listSync().map((f) => f.uri.pathSegments.last).toList()..sort();
      expect(sheets, [
        'android__play_store_phone.png',
        'ios__app_store_ipad_13.png',
      ]);
      final sheet = await DecodedPng.read(
        tester,
        '$reportRoot/_review/android__play_store_phone.png',
      );
      expect(
        sheet.width,
        greaterThan(sheet.height),
        reason: 'two thumbnails side by side',
      );
    });
  });
}

bool isWhiteish(Color c) => c.r > 0.75 && c.g > 0.75 && c.b > 0.75;
