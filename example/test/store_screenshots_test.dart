// Store screenshots for the example chat app.
//
// Run from this folder:
//
//   flutter test test/store_screenshots_test.dart
//
// Output goes to app_deploy_screenshots/, one folder per store upload slot,
// with contact sheets in app_deploy_screenshots/_review/.
import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:app_deploy_screenshots_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captions per locale. Any localisation source works here.
const _headlines = {
  'en': ('All your chats, one inbox', 'Fast, private and beautifully simple'),
  'fr': ('Toutes vos discussions', 'Rapide, privé et simple'),
};

/// The store artwork: brand gradient, localised caption, and a tilted device
/// on Android for variety.
MarketingFrame _frame(ScreenshotContext context) {
  final dark = context.brightness == Brightness.dark;
  final (headline, subheadline) = _headlines[context.locale.languageCode]!;
  return MarketingFrame(
    background: FrameBackground.gradient(
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF1E1B4B), Color(0xFF0B0B12)]
            : const [Color(0xFFE0E7FF), Color(0xFFFDF2F8)],
      ),
    ),
    caption: Caption(headline: headline, subheadline: subheadline),
    layout: context.device.platform == DevicePlatform.android
        ? FrameLayout.tilted
        : FrameLayout.captionTop,
  );
}

// The app keeps a progress indicator or animation running in many real
// screens, so use a fixed pump instead of pumpAndSettle.
Future<void> _pump(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 100));

void main() {
  testWidgets('store screenshots', (tester) async {
    await tester.pumpWidget(
      const ChatApp(
        fontFamilyFallback: [AppDeployScreenshots.emojiFontFamily],
      ),
    );

    // 1. The inbox, framed, in light and dark, English and French.
    await AppDeployScreenshots.forStores(
      tester,
      'inbox',
      order: 1,
      customPump: _pump,
      variants: ScreenshotVariant.matrix(
        brightnesses: [Brightness.light, Brightness.dark],
        locales: [const Locale('en'), const Locale('fr')],
      ),
      statusBar: const StatusBarOverlay(),
      frame: ScreenshotFrame.builder(_frame),
    );

    // 2. The same screen, pointing out features.
    await AppDeployScreenshots.forStores(
      tester,
      'features',
      order: 2,
      customPump: _pump,
      statusBar: const StatusBarOverlay(),
      annotations: [
        Spotlight(find.byKey(ChatApp.composeKey)),
        Callout(find.byKey(ChatApp.searchKey), 'Find any chat instantly'),
        MagnifierInset(find.byKey(ChatApp.photosKey)),
      ],
      frame: ScreenshotFrame.builder(_frame),
    );

    // 3. A plain screenshot, no frame, for listings that prefer the raw UI.
    await AppDeployScreenshots.forStores(
      tester,
      'plain',
      order: 3,
      customPump: _pump,
      statusBar: const StatusBarOverlay(),
    );

    // Manifest, contact sheets, and Google Play's 20% caption check.
    final crowded = await AppDeployScreenshots.writeReport(tester: tester);
    expect(crowded, isEmpty, reason: 'captions over 20% of a Play image');
  });
}
