import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:app_deploy_screenshots/src/frame/frame_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Layout arithmetic, checked with numbers rather than pixels.
Matcher near(Offset expected) => isA<Offset>()
    .having((o) => o.dx, 'dx', closeTo(expected.dx, 1e-6))
    .having((o) => o.dy, 'dy', closeTo(expected.dy, 1e-6));

void main() {
  const device = Device.appStoreIphone69; // 440 x 956 pt, 1320 x 2868 px
  final image = device.pixelSize;
  final view = Offset.zero & device.size;

  FramePlan plan(MarketingFrame frame, {double caption = 200}) =>
      FrameGeometry.plan(
        frame: frame,
        canvasSize: frame.canvasSize ?? image,
        imageSize: image,
        viewRect: view,
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
        expect(p.bezelWidth, closeTo(10 * p.screen.canvasPerPoint, 1e-9));
        // Control: the screen is scaled down, so this is not 10 * 3.
        expect(p.screen.canvasPerPoint, lessThan(device.devicePixelRatio));
      });
    }

    test('fits the whole device, bezel included, inside the margins', () {
      final p = plan(const MarketingFrame());
      final outer = p.screen.rect.inflate(p.bezelWidth);
      expect(outer.left, greaterThanOrEqualTo(p.margin));
      expect(outer.right, lessThanOrEqualTo(image.width - p.margin));
      expect(outer.bottom, lessThanOrEqualTo(image.height));
    });

    test('a thicker bezel shrinks the screen rather than the margins', () {
      final thin = plan(const MarketingFrame(bezel: DeviceBezel(width: 4)));
      final thick = plan(const MarketingFrame(bezel: DeviceBezel(width: 24)));
      expect(thick.screen.rect.width, lessThan(thin.screen.rect.width));
      expect(
        thick.screen.rect.inflate(thick.bezelWidth).width,
        lessThanOrEqualTo(thin.screen.rect.inflate(thin.bezelWidth).width + 1),
      );
    });
  });

  group('layouts', () {
    test('captionTop puts the screen below the caption', () {
      final p = plan(const MarketingFrame(), caption: 300);
      expect(p.screen.rect.top, greaterThan(p.captionTop + 300));
    });

    test('captionBottom puts the caption below the screen', () {
      final p = plan(
        const MarketingFrame(layout: FrameLayout.captionBottom),
        caption: 300,
      );
      expect(p.captionTop, greaterThan(p.screen.rect.bottom));
    });

    test('tilted rotates by the frame tilt', () {
      final p = plan(
        const MarketingFrame(layout: FrameLayout.tilted, tilt: -8),
      );
      expect(p.screen.angle, closeTo(-8 * 3.141592653589793 / 180, 1e-12));
    });
  });

  group('ScreenPlacement', () {
    test('maps the screen corners and centre onto its rect when unrotated', () {
      final p = plan(const MarketingFrame()).screen;
      expect(p.imageToCanvas(Offset.zero), near(p.rect.topLeft));
      expect(
        p.imageToCanvas(image.bottomRight(Offset.zero)),
        near(p.rect.bottomRight),
      );
      expect(p.viewToCanvas(view.center), near(p.rect.center));
    });

    test('keeps the centre fixed under rotation', () {
      final p = plan(const MarketingFrame(layout: FrameLayout.tilted)).screen;
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
}
