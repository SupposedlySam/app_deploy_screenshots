// Store screenshots for the example chat app: a whole listing in one test.
//
// Run from this folder:
//
//   flutter test test/store_screenshots_test.dart
//
// Output goes to app_deploy_screenshots/, one folder per store upload slot,
// with contact sheets in app_deploy_screenshots/_review/. Swap the output for
// `OutputLayout.fastlane()` to write straight into fastlane's upload folders.
import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:app_deploy_screenshots_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const brand = Color(0xFF4F46E5);

/// The brand gradient, following the theme.
LinearGradient brandGradient(ScreenshotContext shot) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: shot.brightness == Brightness.dark
      ? const [Color(0xFF1E1B4B), Color(0xFF0B0B12)]
      : const [Color(0xFFE0E7FF), Color(0xFFFDF2F8)],
);

/// The shared design: the brand gradient, a large device running off the
/// bottom, and the phone drawn with its camera cutout.
MarketingFrame design(ScreenshotContext shot) => MarketingFrame(
  background: FrameBackground.gradient(brandGradient(shot)),
  layout: const FrameLayout.bleed(),
  device: const DeviceStyle.detailed(),
);

/// Captions per locale. Any localisation source works here; `**…**` marks
/// the words to emphasise.
String text(ScreenshotContext shot, String en, String fr) =>
    shot.locale.languageCode == 'fr' ? fr : en;

void main() {
  testWidgets('store listing', (tester) async {
    await tester.pumpWidget(
      const ChatApp(fontFamilyFallback: [AppDeployScreenshots.emojiFontFamily]),
    );

    final listing = StoreListing(
      tester,
      variants: ScreenshotVariant.matrix(
        brightnesses: [Brightness.light, Brightness.dark],
        locales: [const Locale('en', 'US'), const Locale('fr', 'FR')],
      ),
      frame: ScreenshotFrame.builder(design),
      statusBar: const StatusBarOverlay(),
      // Some screens keep animating; a fixed pump never waits for them.
      customPump: (t) => t.pump(const Duration(milliseconds: 100)),
    );

    // 1. A hero poster: no device, just the brand and the promise.
    await listing.poster(
      'welcome',
      frame: ScreenshotFrame.builder(
        (shot) => MarketingFrame(
          background: const FrameBackground.gradient(
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E1B4B), brand],
            ),
          ),
          caption: Caption(
            headline: text(
              shot,
              'Simple. Reliable.\n**Private.**',
              'Simple. Fiable.\n**Privé.**',
            ),
            subheadline: text(
              shot,
              'Messaging for the people you actually know',
              'La messagerie des gens que vous connaissez',
            ),
            emphasis: const CaptionEmphasis.color(Color(0xFFA5B4FC)),
            headlineStyle: const TextStyle(fontSize: 46),
          ),
          decorations: const [
            FrameDecoration.widget(
              Icon(Icons.forum_rounded, color: Colors.white, size: 110),
              size: Size(130, 130),
              alignment: Alignment.bottomCenter,
              offset: Offset(0, -90),
            ),
          ],
        ),
      ),
    );

    // Keep the inbox for the side-by-side slide later.
    final inbox = await listing.captureScreens();

    // 2. The inbox, with one conversation lifted off the screen.
    await listing.screenshot(
      'inbox',
      captionFor: (shot) => Caption(
        headline: text(
          shot,
          'All your chats, **one inbox**',
          'Toutes vos discussions, **un seul endroit**',
        ),
        emphasis: const CaptionEmphasis.marker(brand, textColor: Colors.white),
      ),
      annotations: [Lift(find.byKey(ChatApp.photosKey))],
    );

    // 3. Into a conversation.
    await tester.tap(find.text('Priya Patel'));
    await tester.pump(const Duration(seconds: 1));
    final conversation = await listing.captureScreens();
    await listing.screenshot(
      'conversation',
      captionFor: (shot) => Caption(
        headline: text(
          shot,
          'Share the **moments that matter**',
          'Partagez les **moments qui comptent**',
        ),
        emphasis: const CaptionEmphasis.gradient(
          LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEC4899)]),
        ),
      ),
      frame: ScreenshotFrame.builder(
        (shot) =>
            design(shot).copyWith(layout: const FrameLayout.bleed(angle: -6)),
      ),
      annotations: [Lift(find.byKey(ChatApp.photoMessageKey))],
    );

    // 4. Both screens on one slide, overlapping, laid out with plain
    // Flutter. Slides are 440 points wide on a phone and wider on a
    // tablet, so size the devices from the constraints.
    await listing.widget(
      'two_screens',
      builder: (context, shot) => DecoratedBox(
        decoration: BoxDecoration(gradient: brandGradient(shot)),
        child: LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth * 0.57;
            return Stack(
              children: [
                Positioned(
                  top: 56,
                  left: 24,
                  right: 24,
                  child: Text(
                    text(
                      shot,
                      'Your inbox, your conversations',
                      'Vos discussions, en un coup d’œil',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  top: 190,
                  left: 16,
                  width: width,
                  child: DeviceMockup(
                    screen: inbox.of(shot),
                    style: const DeviceStyle.detailed(),
                  ),
                ),
                Positioned(
                  top: 300,
                  right: 16,
                  width: width,
                  child: DeviceMockup(
                    screen: conversation.of(shot),
                    style: const DeviceStyle.detailed(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    // Manifest, contact sheets, and Google Play's 20% caption check.
    final crowded = await listing.writeReport();
    expect(crowded, isEmpty, reason: 'captions over 20% of a Play image');
  });
}
