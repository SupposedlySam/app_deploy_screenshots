import 'package:flutter_test/flutter_test.dart';

import '../annotations.dart';
import '../frame/marketing_frame.dart';
import '../status_bar.dart';
import 'screen_capturer.dart';

/// Everything a capture method was asked for, passed through the pipeline
/// as one value, so a new option is added in one place instead of being
/// forwarded by hand through every layer.
class CaptureRequest {
  const CaptureRequest({
    this.finder,
    this.customPump,
    this.deviceSetup,
    this.waitForImages = true,
    this.applyDeviceOverrides = true,
    this.statusBar,
    this.annotations = const [],
    this.frame,
  });

  final Finder? finder;
  final CustomPump? customPump;
  final DeviceSetup? deviceSetup;
  final bool waitForImages;
  final bool applyDeviceOverrides;
  final StatusBarOverlay? statusBar;
  final List<ScreenshotAnnotation> annotations;
  final ScreenshotFrame? frame;
}
