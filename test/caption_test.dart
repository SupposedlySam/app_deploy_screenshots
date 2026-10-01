import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';
import 'package:app_deploy_screenshots/src/frame/caption.dart';
import 'package:app_deploy_screenshots/src/frame/frame_compositor.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/png.dart';

void main() {
  group('parseCaptionMarkup', () {
    List<String> parse(String s) => [
      for (final r in parseCaptionMarkup(s)) r.toString(),
    ];

    test('splits emphasised runs', () {
      expect(parse('All your chats, **one inbox**'), [
        'All your chats, ',
        '**one inbox**',
      ]);
      expect(parse('**Bold** start and **end**'), [
        '**Bold**',
        ' start and ',
        '**end**',
      ]);
    });

    test('treats escaped and unmatched markers as text', () {
      expect(parse(r'5 \*\* stars'), ['5 ** stars']);
      expect(parse('Only **one marker'), ['Only **one marker']);
      expect(parse('**a** and ** b'), ['**a**', ' and ** b']);
      expect(parse('Plain'), ['Plain']);
      expect(parse(''), isEmpty);
    });
  });

  group('emphasis rendering', () {
    const canvas = Size(1320, 2868);
    const background = FrameBackground.solid(Color(0xFFFFFFFF));
    final captionBand = const Rect.fromLTWH(0, 100, 1320, 300);

    Future<DecodedPng> render(WidgetTester tester, Caption caption) async {
      final image = (await tester.runAsync(
        () => const FrameCompositor().compose(
          frame: MarketingFrame(background: background, caption: caption),
          canvasSize: canvas,
        ),
      ))!.image;
      return DecodedPng.fromImage(tester, image);
    }

    bool blue(Color c) => c.b > 0.8 && c.r < 0.3 && c.g < 0.3;
    bool yellow(Color c) => c.r > 0.9 && c.g > 0.8 && c.b < 0.3;
    bool red(Color c) => c.r > 0.8 && c.g < 0.3 && c.b < 0.3;

    testWidgets('colour applies only between markers', (tester) async {
      final colored = await render(
        tester,
        const Caption(
          headline: 'All your chats, **one inbox**',
          emphasis: CaptionEmphasis.color(Color(0xFF0000FF)),
        ),
      );
      final none = await render(
        tester,
        const Caption(headline: 'All your chats, **one inbox**'),
      );
      expect(colored.fraction(captionBand, blue, step: 1), greaterThan(0.005));
      expect(none.fraction(captionBand, blue, step: 1), 0, reason: 'control');
    });

    testWidgets('without emphasis the markers are drawn as typed', (
      tester,
    ) async {
      final typed = await render(tester, const Caption(headline: '**x**'));
      final parsed = await render(
        tester,
        const Caption(
          headline: '**x**',
          emphasis: CaptionEmphasis.color(Color(0xFF000000)),
        ),
      );
      bool ink(Color c) => c.r < 0.5;
      // Five characters of ink against one.
      expect(
        typed.fraction(captionBand, ink, step: 1),
        greaterThan(parsed.fraction(captionBand, ink, step: 1) * 2),
      );
    });

    testWidgets('marker paints behind the emphasised words', (tester) async {
      final png = await render(
        tester,
        const Caption(
          headline: 'Plain **marked**',
          emphasis: CaptionEmphasis.marker(Color(0xFFFFE000)),
        ),
      );
      expect(png.fraction(captionBand, yellow, step: 2), greaterThan(0.01));
    });

    testWidgets('gradient fills the emphasised words across its colours', (
      tester,
    ) async {
      final png = await render(
        tester,
        const Caption(
          headline: 'A **gradient headline**',
          emphasis: CaptionEmphasis.gradient(
            LinearGradient(colors: [Color(0xFFFF0000), Color(0xFF0000FF)]),
          ),
        ),
      );
      expect(png.fraction(captionBand, red, step: 1), greaterThan(0.001));
      expect(png.fraction(captionBand, blue, step: 1), greaterThan(0.001));
    });

    testWidgets('a footnote adds a line and counts toward coverage', (
      tester,
    ) async {
      Future<double> coverage(Caption caption) async => (await tester.runAsync(
        () => const FrameCompositor().compose(
          frame: MarketingFrame(background: background, caption: caption),
          canvasSize: canvas,
        ),
      ))!.captionCoverage;
      final without = await coverage(const Caption(headline: 'Headline'));
      final withNote = await coverage(
        const Caption(
          headline: 'Headline',
          footnote: '*Terms apply. Offer for new members only.',
        ),
      );
      expect(withNote, greaterThan(without));
    });

    testWidgets('weights are real weights, not a faint synthetic bold', (
      tester,
    ) async {
      bool ink(Color c) => c.r < 0.5;
      Future<double> inkFor(FontWeight w) async => (await render(
        tester,
        Caption(
          headline: 'Weight check',
          headlineStyle: TextStyle(fontWeight: w),
        ),
      )).fraction(captionBand, ink, step: 1);
      final regular = await inkFor(FontWeight.w400);
      final heavy = await inkFor(FontWeight.w900);
      // Measured: a real wght axis adds about 55% ink; synthetic bold ~14%.
      expect(heavy / regular, greaterThan(1.35));
    });
  });
}
