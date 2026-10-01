import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart' show internal;

import '../device.dart';
import 'frame/device_painter.dart';
import 'frame/device_style.dart';
import 'variant.dart';

/// One captured screen: the app as it looked on [device], with the status
/// bar and annotations drawn. Put it in a [DeviceMockup].
final class DeviceScreen {
  @internal
  DeviceScreen(this.image, this.device, this.viewRect);

  /// The screenshot, in pixels.
  final ui.Image image;

  /// The device it was captured on, with the variant's brightness.
  final Device device;

  /// The part of the device's view the image covers, in logical points.
  final Rect viewRect;
}

/// The screens captured by `AppDeployScreenshots.captureScreens`, one per
/// device and variant. Freed automatically when the test ends.
final class ScreenCaptures {
  @internal
  ScreenCaptures(this._screens);

  final Map<(String, ScreenshotVariant), DeviceScreen> _screens;

  /// The screen for the device and variant [shot] describes: pass the
  /// `shot` a widget slide's builder receives.
  DeviceScreen of(ScreenshotContext shot) {
    final screen = _screens[(shot.device.name, shot.variant)];
    if (screen == null) {
      throw StateError(
        'No capture for ${shot.device.name} ${shot.variant}. Captured: '
        '${_screens.keys.map((k) => '${k.$1} ${k.$2}').join(', ')}. '
        'Capture the same devices and variants the slide renders.',
      );
    }
    return screen;
  }

  /// Every capture, in capture order.
  Iterable<DeviceScreen> get all => _screens.values;

  @internal
  void dispose() {
    for (final s in _screens.values) {
      s.image.dispose();
    }
    _screens.clear();
  }
}

/// A captured screen drawn inside a device: the same bezel, cutout, buttons
/// and shadow a `MarketingFrame` draws, as a widget, so several devices,
/// a before/after pair or a panorama can be laid out with ordinary Flutter
/// in a widget slide.
///
/// ```dart
/// final inbox = await AppDeployScreenshots.captureScreens(tester);
/// await tester.tap(find.text('Maya Chen'));
/// final chat = await AppDeployScreenshots.captureScreens(tester);
///
/// await AppDeployScreenshots.widgetForStores(
///   tester,
///   'two_screens',
///   builder: (context, shot) => Row(children: [
///     Expanded(child: DeviceMockup(screen: inbox.of(shot))),
///     Expanded(child: DeviceMockup(screen: chat.of(shot))),
///   ]),
/// );
/// ```
///
/// The device keeps its proportions and is as large as fits.
class DeviceMockup extends StatelessWidget {
  const DeviceMockup({
    super.key,
    required this.screen,
    this.style = const DeviceStyle(),
  });

  final DeviceScreen screen;
  final DeviceStyle style;

  @override
  Widget build(BuildContext context) {
    final device = screen.device;
    final image = screen.image;
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final source = style.crop.sourceRectFor(device, imageSize, screen.viewRect);
    // The device's size in its own points: the part of the screen shown,
    // plus the bezel all round.
    final shown = Size(
      screen.viewRect.width,
      screen.viewRect.height * source.height / imageSize.height,
    );
    final bezel = style.bezel?.width ?? 0;
    final total = Size(shown.width + 2 * bezel, shown.height + 2 * bezel);

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          constraints.hasBoundedWidth
              ? constraints.maxWidth / total.width
              : double.infinity,
          constraints.hasBoundedHeight
              ? constraints.maxHeight / total.height
              : double.infinity,
        );
        final perPoint = scale.isFinite ? scale : 1.0;
        return SizedBox(
          width: total.width * perPoint,
          height: total.height * perPoint,
          child: CustomPaint(
            painter: _MockupPainter(
              screen: screen,
              source: source,
              style: style,
              perPoint: perPoint,
              screenSize: shown * perPoint,
            ),
          ),
        );
      },
    );
  }
}

class _MockupPainter extends CustomPainter {
  _MockupPainter({
    required this.screen,
    required this.source,
    required this.style,
    required this.perPoint,
    required this.screenSize,
  });

  final DeviceScreen screen;
  final Rect source;
  final DeviceStyle style;
  final double perPoint;
  final Size screenSize;

  @override
  void paint(Canvas canvas, Size size) {
    DevicePainter.paint(
      canvas,
      image: screen.image,
      sourceRect: source,
      screenSize: screenSize,
      centre: size.center(Offset.zero),
      angle: 0,
      device: screen.device,
      style: style,
      perPoint: perPoint,
      // Shadows are in caption points; a mockup has no caption scale, so
      // use the device's.
      unit: perPoint,
    );
  }

  @override
  bool shouldRepaint(_MockupPainter old) =>
      old.screen != screen ||
      old.style != style ||
      old.perPoint != perPoint ||
      old.source != source;
}
