import 'dart:convert';
import 'dart:io';

import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:app_deploy_screenshots/src/frame/frame_geometry.dart';
import 'package:app_deploy_screenshots/src/output/png_encoder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_app.dart';
import 'support/png.dart';

// Each test file writes to its own temp directory: files run in
// parallel, and a shared output folder lets one file's cleanup delete
// another's screenshots mid-run.
final root = Directory.systemTemp.createTempSync('ads_features_').path;

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

    test('opt-in presets have the sizes each store slot asks for', () {
      expect(Device.playStorePhoneTall.pixelSize, const Size(1080, 2400));
      expect(Device.playStoreWear.pixelSize, const Size(454, 454));
      expect(Device.playStoreChromebook.pixelSize, const Size(1920, 1080));
      // Wear OS: 1:1, at least 384 px. Chromebook: 16:9, at least 1080 px.
      expect(
        Device.playStoreWear.pixelSize.shortestSide,
        greaterThanOrEqualTo(384),
      );
      expect(
        Device.playStoreChromebook.pixelSize.aspectRatio,
        closeTo(16 / 9, 1e-9),
      );
      // Opt-in: none of them changes what forStores writes by default.
      for (final d in [
        Device.playStorePhoneTall,
        Device.playStoreWear,
        Device.playStoreChromebook,
      ]) {
        expect(Device.playStore, isNot(contains(d)));
      }
      // The tall phone breaks Play's written 2:1 rule, and the check says so.
      expect(Device.playStorePhoneTall.meetsPlayStoreRequirements(), isFalse);
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
        output: OutputLayout.folders('$root/stores'),
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
        final bytes = PngEncoder.encodeRgba(pixels, 2, 1);
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

    testWidgets('Lift enlarges the target in place', (tester) async {
      await tester.pumpWidget(const _Blocks());
      final plain = await shoot(tester, 'lift_none');
      final png = await shoot(
        tester,
        'lift',
        annotations: [Lift(find.byKey(_Blocks.blue), scale: 1.2, elevation: 0)],
      );
      final all = Rect.fromLTWH(
        0,
        0,
        png.width.toDouble(),
        png.height.toDouble(),
      );
      final ratio =
          png.fraction(all, isBlue, step: 2) /
          plain.fraction(all, isBlue, step: 2);
      expect(ratio, closeTo(1.44, 0.08), reason: '1.2 x 1.2');
      // In place: the box's centre doesn't move.
      expect(png.centroid(isBlue)!, offsetNear(plain.centroid(isBlue)!, 3));
    });

    testWidgets('Lift turns with a tilted device and stays on the widget', (
      tester,
    ) async {
      await tester.pumpWidget(const _Blocks());
      const frame = MarketingFrame(
        layout: FrameLayout.bleed(angle: -8),
        device: DeviceStyle.screenOnly(shadow: null),
      );
      final png = await shoot(
        tester,
        'lift_tilted',
        // Large enough to cover the original box, so the bounds below
        // measure only the lifted piece.
        annotations: [Lift(find.byKey(_Blocks.blue), scale: 1.3, elevation: 0)],
        frame: frame,
      );
      // Where the geometry puts the blue box's centre on the canvas.
      final placement = FrameGeometry.plan(
        frame: frame,
        canvasSize: phone.pixelSize,
        screen: ScreenSize(
          imageSize: phone.pixelSize,
          viewRect: Offset.zero & phone.size,
        ),
        captionHeight: 0,
      ).screen!;
      final expected = placement.viewToCanvas(
        const Rect.fromLTWH(40, 200, 100, 60).center,
      );
      expect(png.centroid(isBlue)!, offsetNear(expected, 6));
      // Turned with the device: the top edge of the lifted box slopes.
      // Between the quarter and three-quarter columns of a 130 pt wide box
      // rotated 8 degrees it shifts by 65 * tan(8) = 9.1 pt; upright, 0.
      final pt = placement.canvasPerPoint;
      final box = png.bounds(isBlue)!;
      double topAt(double x) {
        for (var y = box.top.toInt(); y < box.bottom; y++) {
          if (isBlue(png.pixel(x.toInt(), y))) return y.toDouble();
        }
        fail('no blue in column $x');
      }

      final slope =
          (topAt(box.left + box.width * 0.25) -
                  topAt(box.left + box.width * 0.75))
              .abs() /
          pt;
      expect(slope, closeTo(9.1, 2));
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
          device: DeviceStyle.screenOnly(shadow: null),
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

    testWidgets('captions cover the same share of phone and tablet canvases', (
      tester,
    ) async {
      await tester.pumpWidget(const _Blocks());
      const frame = MarketingFrame(
        caption: Caption(headline: 'One inbox', subheadline: 'Fast'),
      );
      final records = await AppDeployScreenshots.byDevices(
        tester,
        'share',
        devices: const [Device.appStoreIphone69, Device.appStoreIpad13],
        fileNameBuilder: (d) => '$root/share/${d.name}.png',
        customPump: fixedPump,
        frame: frame,
      );
      final phone = records[0].captionCoverage!,
          pad = records[1].captionCoverage!;
      expect(phone, greaterThan(0.005));
      // Set in device points, the iPad caption covered about 40% of the
      // phone's share.
      expect(pad / phone, inInclusiveRange(0.85, 1.15));
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

  group('DeviceStyle', () {
    Future<DecodedPng> framed(
      WidgetTester tester,
      String file,
      MarketingFrame frame,
    ) => shoot(tester, file, statusBar: const StatusBarOverlay(), frame: frame);
    const white = FrameBackground.solid(Color(0xFFFFFFFF));
    // Where the Dynamic Island goes: inside the screen, centred, 11 pt from
    // the top, 126 x 37 pt (computed from the same geometry the frame uses).
    Rect islandArea(MarketingFrame frame) {
      final p = FrameGeometry.plan(
        frame: frame,
        canvasSize: phone.pixelSize,
        screen: ScreenSize(
          imageSize: phone.pixelSize,
          viewRect: Offset.zero & phone.size,
        ),
        captionHeight: 0,
      ).screen!;
      return Rect.fromPoints(
        p.viewToCanvas(Offset(phone.size.width / 2 - 50, 16)),
        p.viewToCanvas(Offset(phone.size.width / 2 + 50, 42)),
      );
    }

    testWidgets('detailed() draws a cutout; the default does not', (
      tester,
    ) async {
      await tester.pumpWidget(const _Blocks());
      final plain = await framed(
        tester,
        'style_plain',
        const MarketingFrame(background: white),
      );
      final detailed = await framed(
        tester,
        'style_detailed',
        const MarketingFrame(background: white, device: DeviceStyle.detailed()),
      );
      final area = islandArea(const MarketingFrame());
      // Control: the default has no cutout, only the status bar's grey.
      expect(plain.fraction(area, isDark, step: 2), 0);
      expect(detailed.fraction(area, isDark, step: 2), greaterThan(0.9));
    });

    testWidgets('detailed() adds side buttons past the bezel edge', (
      tester,
    ) async {
      await tester.pumpWidget(const _Blocks());
      Future<DecodedPng> render(String file, DeviceStyle style) => framed(
        tester,
        file,
        MarketingFrame(background: white, device: style),
      );
      // Just outside the device's right edge, at power-button height.
      final p = FrameGeometry.plan(
        frame: const MarketingFrame(device: DeviceStyle.detailed()),
        canvasSize: phone.pixelSize,
        screen: ScreenSize(
          imageSize: phone.pixelSize,
          viewRect: Offset.zero & phone.size,
        ),
        captionHeight: 0,
      );
      final outer = p.screen!.rect.inflate(p.bezelWidth);
      final edge = Rect.fromLTWH(
        outer.right + 1,
        outer.top + outer.height * 0.30,
        2.5 * p.screen!.canvasPerPoint - 2,
        outer.height * 0.04,
      );
      bool painted(Color c) => c.r < 0.6;
      final plain = await render(
        'buttons_off',
        const DeviceStyle(shadow: null),
      );
      final detailed = await render(
        'buttons_on',
        const DeviceStyle.detailed(shadow: null),
      );
      expect(plain.fraction(edge, painted, step: 1), 0, reason: 'control');
      expect(detailed.fraction(edge, painted, step: 1), greaterThan(0.9));
    });

    testWidgets('ScreenCrop.belowStatusBar leaves the status bar out', (
      tester,
    ) async {
      await tester.pumpWidget(const _Blocks());
      final upperScreen = Rect.fromLTWH(200, 150, 920, 300);
      final shown = await framed(
        tester,
        'style_bar',
        const MarketingFrame(
          background: white,
          device: DeviceStyle.screenOnly(),
        ),
      );
      final cropped = await framed(
        tester,
        'style_crop',
        const MarketingFrame(
          background: white,
          device: DeviceStyle.screenOnly(crop: ScreenCrop.belowStatusBar),
        ),
      );
      expect(shown.fraction(upperScreen, isDark, step: 2), greaterThan(0.002));
      expect(cropped.fraction(upperScreen, isDark, step: 2), 0);
    });

    testWidgets('fadeOut blends the bottom of the device into the background', (
      tester,
    ) async {
      await tester.pumpWidget(const _Blocks());
      const background = Color(0xFFFF0000);
      final png = await framed(
        tester,
        'style_fade',
        const MarketingFrame(
          background: FrameBackground.solid(background),
          device: DeviceStyle(fadeOut: 0.4, shadow: null),
        ),
      );
      final w = png.width.toDouble();
      // Grey screen shows at mid-height; only red background near the
      // device's bottom edge.
      expect(
        png.fraction(Rect.fromLTWH(w * 0.4, 1300, w * 0.2, 60), isGrey),
        greaterThan(0.9),
      );
      expect(
        png.fraction(Rect.fromLTWH(w * 0.4, 2700, w * 0.2, 40), isRed),
        greaterThan(0.95),
      );
    });
  });

  group('FrameBackground', () {
    testWidgets('screen() fills the canvas from the app itself', (
      tester,
    ) async {
      await tester.pumpWidget(const _Blocks());
      final png = await shoot(
        tester,
        'bg_screen',
        frame: const MarketingFrame(
          background: FrameBackground.screen(tint: Color(0x00000000)),
          layout: FrameLayout.captionTop,
        ),
      );
      // The app is grey with a blue and a green box; blurred and enlarged,
      // the canvas corners come out grey, not the fallback's near-black.
      expect(
        png.fraction(const Rect.fromLTWH(0, 0, 60, 60), isGrey),
        greaterThan(0.9),
      );
    });

    testWidgets(
      'image(blur:) softens hard edges; without blur they stay hard',
      (tester) async {
        // 200 x 200, left half black: scaled to cover the canvas, a hard edge
        // down the middle, smoothed over only ~14 px.
        final pixels = Uint8List(200 * 200 * 4);
        for (var i = 0; i < 200 * 200; i++) {
          final white = i % 200 >= 100 ? 255 : 0;
          pixels.setAll(i * 4, [white, white, white, 255]);
        }
        final halves = PngEncoder.encodeRgba(pixels, 200, 200);
        Future<DecodedPng> render(double blur) async {
          await tester.pumpWidget(const _Blocks());
          return shoot(
            tester,
            'bg_blur_$blur',
            frame: MarketingFrame(
              background: FrameBackground.image(halves, blur: blur),
              device: const DeviceStyle.screenOnly(shadow: null),
            ),
          );
        }

        // 30-60 px left of the edge: pure black when sharp. Blurred by 60 px
        // (20 pt at 3 px/pt), white bleeds in: 16-31% for a Gaussian there.
        bool lifted(Color c) => c.r > 0.08;
        final edge = const Rect.fromLTWH(600, 20, 30, 40);
        expect((await render(0)).fraction(edge, lifted, step: 1), 0);
        expect((await render(20)).fraction(edge, lifted, step: 1), 1);
      },
    );
  });

  test('status bar clock defaults to each platform\'s marketing time', () {
    const bar = StatusBarOverlay();
    expect(bar.timeFor(DevicePlatform.ios), '9:41');
    expect(bar.timeFor(DevicePlatform.android), '9:30');
    expect(
      const StatusBarOverlay(time: '10:00').timeFor(DevicePlatform.android),
      '10:00',
    );
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

  testWidgets('emoji render through the bundled fallback font', (tester) async {
    Widget emoji(String e, List<String>? fallback) => SizedBox(
      width: 80,
      height: 80,
      child: Text(
        e,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 60,
          color: const Color(0xFF000000),
          fontFamilyFallback: fallback,
        ),
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final fallback in [
                null,
                const [AppDeployScreenshots.emojiFontFamily],
              ])
                Row(children: [emoji('😀', fallback), emoji('👍', fallback)]),
            ],
          ),
        ),
      ),
    );
    final png = await shoot(tester, 'emoji', device: Device.phone);
    bool ink(Color c) => c.r < 0.5;
    double inkAt(double x, double y) =>
        png.fraction(Rect.fromLTWH(x, y, 80, 80), ink, step: 1);

    // Without the fallback both are the same empty box; with it they differ.
    expect(inkAt(0, 0), closeTo(inkAt(80, 0), 0.001), reason: 'control');
    expect(inkAt(0, 80), greaterThan(0.05));
    expect((inkAt(0, 80) - inkAt(80, 80)).abs(), greaterThan(0.01));
  });

  group('packageLibFromConfig', () {
    final config = Uri.file('/work/app/.dart_tool/package_config.json');
    Uri? lib(String rootUri, [String? packageUri = 'lib/']) =>
        AppDeployScreenshots.packageLibFromConfig(config, {
          'packages': [
            {'name': 'other', 'rootUri': '../../other/'},
            {
              'name': 'app_deploy_screenshots',
              'rootUri': rootUri,
              'packageUri': ?packageUri,
            },
          ],
        }, 'app_deploy_screenshots');

    test('resolves a path dependency written without a trailing slash', () {
      expect(
        lib('../../../app_deploy_screenshots')?.toFilePath(),
        '/app_deploy_screenshots/lib/',
      );
    });

    test('resolves the package itself, the pub cache, and no packageUri', () {
      expect(lib('../')?.toFilePath(), '/work/app/lib/');
      expect(
        lib('file:///cache/app_deploy_screenshots-1.1.0')?.toFilePath(),
        '/cache/app_deploy_screenshots-1.1.0/lib/',
      );
      expect(lib('../', null)?.toFilePath(), '/work/app/lib/');
      expect(lib('../', 'lib')?.toFilePath(), '/work/app/lib/');
    });

    test('answers null when absent and throws on a malformed file', () {
      expect(
        AppDeployScreenshots.packageLibFromConfig(config, {
          'packages': [],
        }, 'x'),
        isNull,
      );
      expect(
        () => AppDeployScreenshots.packageLibFromConfig(config, [], 'x'),
        throwsFormatException,
      );
    });
  });

  group('writeReport', () {
    testWidgets('warns about Play captions over the coverage limit only', (
      tester,
    ) async {
      final reportRoot = '$root/coverage';
      await tester.pumpWidget(const _Blocks());
      MarketingFrame frame(double size) => MarketingFrame(
        caption: Caption(
          headline: 'A very large headline over many lines',
          headlineStyle: TextStyle(fontSize: size),
        ),
      );
      for (final (name, size) in [('big', 80.0), ('small', 24.0)]) {
        await AppDeployScreenshots.forStores(
          tester,
          name,
          output: OutputLayout.folders(reportRoot),
          devices: const [Device.playStorePhone, Device.appStoreIphone69],
          customPump: fixedPump,
          frame: frame(size),
        );
      }

      final over = await AppDeployScreenshots.writeReport(
        output: OutputLayout.folders(reportRoot),
        tester: tester,
        contactSheets: false,
      );

      expect(over.map((e) => e.$1), ['android/play_store_phone/big.png']);
      expect(over.single.$2, greaterThan(0.2));
      final manifest =
          jsonDecode(File('$reportRoot/manifest.json').readAsStringSync())
              as Map;
      final coverage = {
        for (final e in (manifest['screenshots'] as List).cast<Map>())
          e['path']: e['captionCoverage'],
      };
      // Control: the iOS copy of the same caption is just as big, and is
      // recorded but not flagged.
      expect(coverage['ios/app_store_iphone_6_9/big.png'], greaterThan(0.2));
      expect(coverage['android/play_store_phone/small.png'], lessThan(0.2));
    });

    testWidgets('writes a manifest and one contact sheet per folder', (
      tester,
    ) async {
      final reportRoot = '$root/report';
      await tester.pumpWidget(const _Blocks());
      for (final (order, name) in [(1, 'a'), (2, 'b')]) {
        await AppDeployScreenshots.forStores(
          tester,
          name,
          output: OutputLayout.folders(reportRoot),
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

Matcher offsetNear(Offset expected, double tolerance) => isA<Offset>().having(
  (o) => (o - expected).distance,
  'distance from $expected',
  lessThan(tolerance),
);

bool isWhiteish(Color c) => c.r > 0.75 && c.g > 0.75 && c.b > 0.75;
