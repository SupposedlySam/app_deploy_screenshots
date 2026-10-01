// One slide per feature, on the 6.9" iPhone only: the images in the
// package README. Each test is a self-contained recipe to copy.
//
//   flutter test test/feature_gallery_test.dart
//
// Output goes to app_deploy_screenshots/gallery/.
import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:app_deploy_screenshots_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const brand = Color(0xFF4F46E5);

const lavender = FrameBackground.gradient(
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE0E7FF), Color(0xFFFDF2F8)],
  ),
);

void main() {
  late StoreListing listing;

  Future<void> start(WidgetTester tester, String folder) async {
    await tester.pumpWidget(
      const ChatApp(fontFamilyFallback: [AppDeployScreenshots.emojiFontFamily]),
    );
    listing = StoreListing(
      tester,
      devices: const [Device.appStoreIphone69],
      output: OutputLayout.folders('app_deploy_screenshots/gallery/$folder'),
      statusBar: const StatusBarOverlay(),
      customPump: (t) => t.pump(const Duration(milliseconds: 100)),
    );
  }

  testWidgets('layouts', (tester) async {
    await start(tester, 'layouts');
    const caption = Caption(headline: 'All your chats, one inbox');
    for (final (name, layout, device) in [
      ('caption_top', FrameLayout.captionTop, const DeviceStyle()),
      ('bleed', const FrameLayout.bleed(), const DeviceStyle.detailed()),
      (
        'tilted',
        const FrameLayout.bleed(angle: -8),
        const DeviceStyle.detailed(),
      ),
      (
        'cropped',
        FrameLayout.captionBottom,
        const DeviceStyle.screenOnly(crop: ScreenCrop.belowStatusBar),
      ),
    ]) {
      await listing.screenshot(
        name,
        frame: MarketingFrame(
          background: lavender,
          caption: caption,
          layout: layout,
          device: device,
        ),
      );
    }
    // The app's own screen, blurred, as the background.
    await listing.screenshot(
      'screen_background',
      frame: const MarketingFrame(
        background: FrameBackground.screen(),
        caption: Caption(
          headline: 'All your chats, one inbox',
          headlineStyle: TextStyle(color: Colors.white),
        ),
        layout: FrameLayout.bleed(),
        device: DeviceStyle.detailed(),
      ),
    );
  });

  testWidgets('caption emphasis', (tester) async {
    await start(tester, 'captions');
    for (final (name, emphasis) in [
      ('color', const CaptionEmphasis.color(brand)),
      ('marker', const CaptionEmphasis.marker(brand, textColor: Colors.white)),
      (
        'gradient',
        const CaptionEmphasis.gradient(
          LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEC4899)]),
        ),
      ),
      (
        'style',
        const CaptionEmphasis.style(
          TextStyle(fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
        ),
      ),
    ]) {
      await listing.screenshot(
        name,
        frame: MarketingFrame(
          background: lavender,
          layout: const FrameLayout.bleed(),
          device: const DeviceStyle.detailed(),
          caption: Caption(
            headline: 'All your chats, **one inbox**',
            subheadline: 'Fast, private and beautifully simple',
            emphasis: emphasis,
          ),
        ),
      );
    }
  });

  testWidgets('annotations', (tester) async {
    await start(tester, 'annotations');
    const frame = MarketingFrame(
      background: lavender,
      layout: FrameLayout.bleed(visible: 0.85),
      device: DeviceStyle.detailed(),
    );
    for (final (name, headline, annotation) in [
      (
        'lift',
        'Lift',
        Lift(find.byKey(ChatApp.photosKey)) as ScreenshotAnnotation,
      ),
      (
        'spotlight',
        'Spotlight',
        Spotlight(find.widgetWithText(ListTile, 'Leo Martin')),
      ),
      (
        'callout',
        'Callout',
        Callout(find.byKey(ChatApp.searchKey), 'Find any chat instantly'),
      ),
      (
        'magnifier',
        'MagnifierInset',
        MagnifierInset(find.widgetWithText(ListTile, 'Book Club')),
      ),
    ]) {
      await listing.screenshot(
        name,
        frame: frame.copyWith(caption: Caption(headline: headline)),
        annotations: [annotation],
      );
    }
  });

  testWidgets('panorama', (tester) async {
    await start(tester, 'panorama');
    final inbox = await listing.captureScreens();
    await tester.tap(find.text('Priya Patel'));
    await tester.pump(const Duration(seconds: 1));
    final chat = await listing.captureScreens();

    // One strip, three slides wide (3 × 440 points). The second phone
    // straddles the join between slides 2 and 3.
    TextStyle headline(BuildContext context) => Theme.of(
      context,
    ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w700);
    await listing.panorama(
      ['plan', 'chat', 'share'],
      builder: (context, shot) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0E7FF), Color(0xFFFDF2F8), Color(0xFFFFEDD5)],
          ),
        ),
        child: Stack(
          children: [
            for (final (left, text) in [
              (0.0, 'Every chat'),
              (440.0, 'Every photo'),
              (880.0, 'One app'),
            ])
              Positioned(
                left: left,
                width: 440,
                top: 64,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: headline(context),
                ),
              ),
            Positioned(
              left: 70,
              top: 170,
              width: 300,
              child: DeviceMockup(
                screen: inbox.of(shot),
                style: const DeviceStyle.detailed(),
              ),
            ),
            Positioned(
              left: 720,
              top: 220,
              width: 300,
              child: Transform.rotate(
                angle: 0.12,
                child: DeviceMockup(
                  screen: chat.of(shot),
                  style: const DeviceStyle.detailed(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  });
}
