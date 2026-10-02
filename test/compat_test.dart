// 1.2 keeps every 1.1 API working. These check the parts that changed shape
// underneath, against 1.1's behaviour.
// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:ui' as ui;

import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:app_deploy_screenshots/src/frame/frame_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FrameLayout is still the 1.1 enum', () {
    expect(FrameLayout.values, [
      FrameLayout.captionTop,
      FrameLayout.captionBottom,
      FrameLayout.tilted,
    ]);
    // An exhaustive switch, as 1.1 code may have written.
    String name(FrameLayout l) => switch (l) {
      FrameLayout.captionTop => 'top',
      FrameLayout.captionBottom => 'bottom',
      FrameLayout.tilted => 'tilted',
    };
    expect(name(const MarketingFrame().layout), 'top');
  });

  group('the 1.x bleed matches SlideLayout.bleed', () {
    const image = Size(1320, 2868);
    final screen = ScreenSize(
      imageSize: image,
      viewRect: Offset.zero & const Size(440, 956),
    );
    FramePlan plan(MarketingFrame frame) => FrameGeometry.plan(
      frame: frame,
      canvasSize: image,
      screen: screen,
      captionHeight: 200,
    );

    for (final (width, visible, angle) in [
      (null, 0.8, 0.0),
      (0.7, 0.6, -8.0),
    ]) {
      test('width $width, visible $visible, angle $angle', () {
        final old = plan(
          MarketingFrame(
            bleed: FrameBleed(width: width, visible: visible, angle: angle),
          ),
        ).screen!;
        final current = plan(
          MarketingFrame(
            slideLayout: SlideLayout.bleed(
              width: width,
              visible: visible,
              angle: angle,
            ),
          ),
        ).screen!;
        expect(old.rect, current.rect);
        expect(old.angle, current.angle);
        // Control: it really bleeds, unlike the default layout.
        final top = plan(const MarketingFrame()).screen!;
        expect(current.rect.bottom, greaterThan(top.rect.bottom));
      });
    }

    test('bleed overrides the enum, and slideLayout overrides both', () {
      final viaBleed = plan(
        const MarketingFrame(
          layout: FrameLayout.captionBottom,
          bleed: FrameBleed(),
        ),
      ).screen!;
      final viaSlide = plan(
        const MarketingFrame(slideLayout: SlideLayout.bleed()),
      ).screen!;
      expect(viaBleed.rect, viaSlide.rect);
      final slideWins = plan(
        const MarketingFrame(
          layout: FrameLayout.tilted,
          slideLayout: SlideLayout.captionBottom,
        ),
      ).screen!;
      final bottom = plan(
        const MarketingFrame(layout: FrameLayout.captionBottom),
      ).screen!;
      expect(slideWins.rect, bottom.rect);
    });
  });

  test('1.1 fields read as non-null with their 1.1 defaults', () {
    const caption = Caption(headline: 'x');
    final TextAlign align = caption.textAlign;
    final TextDirection direction = caption.textDirection;
    expect((align, direction), (TextAlign.center, TextDirection.ltr));
    expect(
      const Caption(headline: 'x', textAlign: TextAlign.start).textAlign,
      TextAlign.start,
    );

    final String time = const StatusBarOverlay().time;
    expect(time, '9:41');
    expect(const StatusBarOverlay(time: '10:00').time, '10:00');

    final DisplaySize size = Device.playStorePhone.displaySize;
    expect(size, DisplaySize.sixOne);
    expect(
      const Device(
        name: 'x',
        size: Size(1, 1),
        platform: DevicePlatform.android,
      ).displaySize,
      DisplaySize.sixOne,
    );
  });

  test('1.1 FrameBackground calls still compile', () {
    // The API diff tool reads the new optional blur and tint as required,
    // because redirecting factories declare no defaults. They aren't.
    final bytes = Uint8List(0);
    expect(FrameBackground.image(bytes), isA<FrameBackground>());
    expect(
      FrameBackground.image(bytes, fallback: Colors.black),
      isA<FrameBackground>(),
    );
  });

  test('1.1 presets keep their 1.1 sizes', () {
    expect(Device.androidPhoneTall.pixelSize, const Size(2160, 1080));
    expect(Device.androidPhoneExtra.pixelSize, const Size(2400, 1080));
  });

  test('classes that were open in 1.1 can still be extended', () {
    // A compile check as much as a test: each line fails to build if the
    // class is final.
    expect(_MyDevice().name, 'mine');
    expect(_MyCaption().headline, 'mine');
    expect(_MyFrame().caption, isNull);
  });

  testWidgets('removed 1.1 helpers still work', (tester) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 2, 2),
      Paint()..color = const Color(0x80FF0000),
    );
    final bytes = (await tester.runAsync(() async {
      final image = await recorder.endRecording().toImage(2, 2);
      return encodeOpaquePng(image);
    }))!;
    // PNG signature, then IHDR with colour type 2 (RGB, no alpha).
    expect(bytes.sublist(1, 4), 'PNG'.codeUnits);
    expect(bytes[25], 2);

    expect(TestAssetBundle(), isA<CachingAssetBundle>());
    expect(
      AppDeployScreenshots.packageLibFromConfig(
        Uri.parse('file:///p/.dart_tool/package_config.json'),
        {
          'packages': [
            {'name': 'x', 'rootUri': '../x', 'packageUri': 'lib/'},
          ],
        },
        'x',
      ),
      Uri.parse('file:///p/x/lib/'),
    );
  });
}

class _MyDevice extends Device {
  _MyDevice()
    : super(name: 'mine', size: const Size(1, 1), platform: DevicePlatform.ios);
}

class _MyCaption extends Caption {
  const _MyCaption() : super(headline: 'mine');
}

class _MyFrame extends MarketingFrame {
  const _MyFrame();
}
