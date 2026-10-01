import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:app_deploy_screenshots/src/frame/frame_geometry.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Layout arithmetic, checked with numbers rather than pixels.
Matcher near(Offset expected) => isA<Offset>()
    .having((o) => o.dx, 'dx', closeTo(expected.dx, 1e-6))
    .having((o) => o.dy, 'dy', closeTo(expected.dy, 1e-6));

void main() {
  const device = Device.appStoreIphone69; // 440 x 956 pt, 1320 x 2868 px
  final image = device.pixelSize;
  final view = Offset.zero & device.size;

  FramePlan plan(MarketingFrame frame, {double caption = 200, Rect? source}) =>
      FrameGeometry.plan(
        frame: frame,
        canvasSize: frame.canvasSize ?? image,
        screen: ScreenSize(
          imageSize: image,
          viewRect: view,
          sourceRect: source,
        ),
        captionHeight: caption,
      );

  group('bezel', () {
    for (final layout in [
      FrameLayout.captionTop,
      FrameLayout.captionBottom,
      FrameLayout.tilted,
    ]) {
      test('is its width in device points at the drawn scale ($layout)', () {
        final p = plan(MarketingFrame(layout: layout));
        // 10 pt, at the canvas pixels per point the screen is drawn at.
        expect(p.bezelWidth, closeTo(10 * p.screen!.canvasPerPoint, 1e-9));
        // Control: the screen is scaled down, so this is not 10 * 3.
        expect(p.screen!.canvasPerPoint, lessThan(device.devicePixelRatio));
      });
    }

    test('fits the whole device, bezel included, inside the margins', () {
      final p = plan(const MarketingFrame());
      final outer = p.screen!.rect.inflate(p.bezelWidth);
      expect(outer.left, greaterThanOrEqualTo(p.margin));
      expect(outer.right, lessThanOrEqualTo(image.width - p.margin));
      expect(outer.bottom, lessThanOrEqualTo(image.height));
    });

    test('a thicker bezel shrinks the screen rather than the margins', () {
      final thin = plan(
        const MarketingFrame(device: DeviceStyle(bezel: DeviceBezel(width: 4))),
      );
      final thick = plan(
        const MarketingFrame(
          device: DeviceStyle(bezel: DeviceBezel(width: 24)),
        ),
      );
      expect(thick.screen!.rect.width, lessThan(thin.screen!.rect.width));
      expect(
        thick.screen!.rect.inflate(thick.bezelWidth).width,
        lessThanOrEqualTo(thin.screen!.rect.inflate(thin.bezelWidth).width + 1),
      );
    });
  });

  group('layouts', () {
    test('captionTop puts the screen below the caption', () {
      final p = plan(const MarketingFrame(), caption: 300);
      expect(p.screen!.rect.top, greaterThan(p.captionTop + 300));
    });

    test('captionBottom puts the caption below the screen', () {
      final p = plan(
        const MarketingFrame(layout: FrameLayout.captionBottom),
        caption: 300,
      );
      expect(p.captionTop, greaterThan(p.screen!.rect.bottom));
    });

    test('bleed rotates by its angle', () {
      final p = plan(
        const MarketingFrame(layout: FrameLayout.bleed(angle: -8)),
      );
      expect(p.screen!.angle, closeTo(-8 * 3.141592653589793 / 180, 1e-12));
    });

    test('1.x parameters still work through the deprecated forwarders', () {
      // ignore: deprecated_member_use_from_same_package
      final tilted = plan(
        const MarketingFrame(layout: FrameLayout.tilted, tilt: -12),
      );
      expect(
        tilted.screen!.angle,
        closeTo(-12 * 3.141592653589793 / 180, 1e-12),
      );
      final noBezel = plan(
        // ignore: deprecated_member_use_from_same_package
        const MarketingFrame(bezel: null),
      );
      expect(noBezel.bezelWidth, 0);
    });
  });

  group('ScreenPlacement', () {
    test('maps the screen corners and centre onto its rect when unrotated', () {
      final p = plan(const MarketingFrame()).screen!;
      expect(p.imageToCanvas(Offset.zero), near(p.rect.topLeft));
      expect(
        p.imageToCanvas(image.bottomRight(Offset.zero)),
        near(p.rect.bottomRight),
      );
      expect(p.viewToCanvas(view.center), near(p.rect.center));
    });

    test('keeps the centre fixed under rotation', () {
      final p = plan(const MarketingFrame(layout: FrameLayout.tilted)).screen!;
      final centre = p.viewToCanvas(view.center);
      expect(centre.dx, closeTo(p.rect.center.dx, 1e-9));
      expect(centre.dy, closeTo(p.rect.center.dy, 1e-9));
      // Control: an off-centre point does move.
      expect(p.viewToCanvas(Offset.zero), isNot(p.rect.topLeft));
    });
  });

  test('layout unit scales with canvas area, not width', () {
    const frame = MarketingFrame();
    final phone = FrameGeometry.unitFor(frame, image);
    final tablet = FrameGeometry.unitFor(
      frame,
      Device.appStoreIpad13.pixelSize,
    );
    // Same share of area: unit^2 / area is constant.
    expect(
      phone * phone / (image.width * image.height),
      closeTo(
        tablet *
            tablet /
            Device.appStoreIpad13.pixelSize.width /
            Device.appStoreIpad13.pixelSize.height,
        1e-12,
      ),
    );
  });

  test('a slide without a device has no screen and keeps the caption', () {
    final p = FrameGeometry.plan(
      frame: const MarketingFrame(),
      canvasSize: image,
      screen: null,
      captionHeight: 200,
    );
    expect(p.screen, isNull);
    expect(p.captionTop, greaterThan(0));
    expect(p.captionWidth, image.width - 2 * p.margin);
  });

  group('cropped source', () {
    // Hide a 62 pt status bar: drop the top 186 px of the image.
    final crop = Rect.fromLTRB(0, 62 * 3, image.width, image.height);

    test('keeps the shown area\'s aspect ratio', () {
      final p = plan(const MarketingFrame(), source: crop).screen!;
      expect(
        p.rect.height / p.rect.width,
        closeTo(crop.height / crop.width, 1e-9),
      );
    });

    test('maps view points below the crop line onto the drawn screen', () {
      final p = plan(const MarketingFrame(), source: crop).screen!;
      // The first point shown is at the top-left of the drawn screen.
      expect(p.viewToCanvas(const Offset(0, 62)), near(p.rect.topLeft));
      expect(
        p.viewToCanvas(Offset(device.size.width, device.size.height)),
        near(p.rect.bottomRight),
      );
      // Control: without the crop, the same point lands lower.
      final full = plan(const MarketingFrame()).screen!;
      expect(
        full.viewToCanvas(const Offset(0, 62)).dy,
        greaterThan(full.rect.top),
      );
    });
  });

  group('bleed', () {
    for (final (name, size) in [
      ('phone', Device.appStoreIphone69.pixelSize),
      ('Play phone', Device.playStorePhone.pixelSize),
    ]) {
      test('runs the device off the bottom of a $name canvas', () {
        final p = FrameGeometry.plan(
          frame: const MarketingFrame(layout: FrameLayout.bleed(visible: 0.8)),
          canvasSize: size,
          screen: ScreenSize(imageSize: image, viewRect: view),
          captionHeight: 200,
        );
        final device = p.screen!.rect.inflate(p.bezelWidth);
        final cap = size.width * FrameGeometry.maxBleedWidth;
        final visible = (size.height - device.top) / device.height;
        expect(device.bottom, greaterThan(size.height), reason: 'bleeds');
        expect(device.width, lessThanOrEqualTo(cap + 1e-6));
        // Either the requested fraction shows, or the width cap stopped it.
        expect(
          device.width >= cap - 1e-6 || (visible - 0.8).abs() < 1e-9,
          isTrue,
          reason: 'visible=$visible',
        );
      });
    }

    test('shows exactly the requested fraction when the width allows', () {
      final p = FrameGeometry.plan(
        frame: const MarketingFrame(layout: FrameLayout.bleed(visible: 0.95)),
        canvasSize: image,
        screen: ScreenSize(imageSize: image, viewRect: view),
        captionHeight: 300,
      );
      final device = p.screen!.rect.inflate(p.bezelWidth);
      expect((image.height - device.top) / device.height, closeTo(0.95, 1e-9));
    });

    test(
      'caps the width on a squat canvas instead of overflowing sideways',
      () {
        final pad = Device.appStoreIpad13.pixelSize;
        final p = FrameGeometry.plan(
          frame: const MarketingFrame(layout: FrameLayout.bleed(visible: 0.5)),
          canvasSize: pad,
          screen: ScreenSize(imageSize: image, viewRect: view),
          captionHeight: 200,
        );
        final device = p.screen!.rect.inflate(p.bezelWidth);
        expect(
          device.width,
          closeTo(pad.width * FrameGeometry.maxBleedWidth, 1e-6),
        );
        expect(device.left, greaterThan(0));
      },
    );

    test('control: captionTop keeps the whole device on the canvas', () {
      final p = plan(const MarketingFrame());
      expect(
        p.screen!.rect.inflate(p.bezelWidth).bottom,
        lessThan(image.height),
      );
    });

    test('a tilted device keeps its corners on the canvas at the sides', () {
      final p = FrameGeometry.plan(
        frame: const MarketingFrame(layout: FrameLayout.bleed(angle: -8)),
        canvasSize: image,
        screen: ScreenSize(imageSize: image, viewRect: view),
        captionHeight: 200,
      );
      final s = p.screen!;
      final top = [
        s.viewToCanvas(Offset.zero),
        s.viewToCanvas(Offset(device.size.width, 0)),
      ];
      for (final corner in top) {
        expect(corner.dx, inInclusiveRange(0, image.width));
      }
    });
  });
}
