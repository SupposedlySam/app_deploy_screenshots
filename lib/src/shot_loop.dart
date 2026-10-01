import 'package:flutter/painting.dart';

import '../device.dart';
import 'output/output_layout.dart';
import 'output/report.dart';
import 'variant.dart';

/// Runs one slide across devices and variants, in the order every method
/// uses: each device, then each variant on it.
abstract final class ShotLoop {
  static Future<List<ScreenshotRecord>> run(
    String name, {
    required List<Device> devices,
    required List<ScreenshotVariant> variants,
    required int? order,
    required ScreenshotSource source,
    required Size? Function(Device device) canvasFor,
    required Future<ScreenshotRecord> Function(ScreenshotContext context) shoot,
    OutputLayout? output,
  }) async {
    assert(devices.isNotEmpty);
    assert(variants.isNotEmpty);
    output?.check(devices, variants);
    assert(order == null || order > 0, 'order starts at 1');
    return [
      for (final device in devices)
        for (final variant in variants)
          await shoot(
            ScreenshotContext(
              name: name,
              device: variant.applyTo(device),
              variant: variant,
              order: order,
              source: source,
              canvasSize: canvasFor(device),
            ),
          ),
    ];
  }
}
