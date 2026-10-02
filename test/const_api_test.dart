// 1.x API kept working until 2.0.
// ignore_for_file: deprecated_member_use_from_same_package

// Every public configuration type must work in a const expression: that is
// how most users write frames. A const evaluation error is a compile error,
// so this file failing to load is the failure.
import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const frames = <MarketingFrame>[
  MarketingFrame(),
  MarketingFrame(slideLayout: SlideLayout.captionBottom),
  MarketingFrame(layout: FrameLayout.tilted),
  MarketingFrame(slideLayout: SlideLayout.bleed()),
  MarketingFrame(
    slideLayout: SlideLayout.bleed(width: 0.8, visible: 0.7, angle: -6),
  ),
  MarketingFrame(device: DeviceStyle()),
  MarketingFrame(device: DeviceStyle.screenOnly()),
  MarketingFrame(device: DeviceStyle.detailed()),
  MarketingFrame(
    background: FrameBackground.solid(Color(0xFF000000)),
    caption: Caption(headline: 'Headline', subheadline: 'Sub'),
    device: DeviceStyle(
      bezel: DeviceBezel(color: Color(0xFF222222), width: 8),
      cornerRadius: 40,
      cutout: ScreenCutout.island,
      outline: DeviceOutline(),
      glow: DeviceGlow(color: Color(0x806366F1)),
      shadow: null,
      crop: ScreenCrop.belowStatusBar,
      fadeOut: 0.3,
    ),
    canvasSize: Size(1080, 1920),
  ),
  MarketingFrame(device: DeviceStyle(crop: ScreenCrop.points(top: 20))),
];

const statusBars = [StatusBarOverlay(), StatusBarOverlay(time: '10:00')];

void main() {
  test('public configuration types are const-constructible', () {
    expect(frames, hasLength(10));
    expect(statusBars, hasLength(2));
  });

  test('setting both device: and a deprecated device parameter is caught', () {
    expect(
      () => MarketingFrame(device: const DeviceStyle(), shadow: false),
      throwsAssertionError,
    );
  });
}
