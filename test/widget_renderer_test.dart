import 'dart:async';

import 'package:app_deploy_screenshots/src/capture/widget_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Counted extends StatefulWidget {
  const _Counted(this.counts);
  final List<String> counts;
  @override
  State<_Counted> createState() => _CountedState();
}

class _CountedState extends State<_Counted> {
  @override
  void initState() {
    super.initState();
    widget.counts.add('init');
  }

  @override
  void dispose() {
    widget.counts.add('dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// A delegate that takes [delay] to load, like one reading assets.
class _SlowDelegate extends LocalizationsDelegate<String> {
  const _SlowDelegate(this.delay);
  final Duration? delay;
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<String> load(Locale locale) => delay == null
      ? Completer<String>()
            .future // never loads
      : Future.delayed(delay!, () => 'loaded');
  @override
  bool shouldReload(_SlowDelegate old) => false;
}

void main() {
  const renderer = WidgetRenderer();

  testWidgets('unmounts the widget: state is disposed after rendering', (
    tester,
  ) async {
    final counts = <String>[];
    final image = await renderer.render(
      tester,
      _Counted(counts),
      logicalSize: const Size(100, 100),
      pixelRatio: 1,
    );
    image.dispose();
    expect(counts, ['init', 'dispose']);
  });

  testWidgets('an animated widget does not leave a ticker running', (
    tester,
  ) async {
    final image = await renderer.render(
      tester,
      const Center(child: CircularProgressIndicator()),
      logicalSize: const Size(100, 100),
      pixelRatio: 1,
    );
    image.dispose();
    // A ticker left running fails the test at its end ("A Ticker was
    // active"); reaching here and finishing cleanly is the assertion.
  });

  testWidgets('renders exactly the requested pixel size', (tester) async {
    for (final (size, ratio) in [
      (const Size(440, 956), 3.0),
      (const Size(333.3, 777.7), 2.625),
      (const Size(100, 100), 1.7),
    ]) {
      final image = await renderer.render(
        tester,
        const ColoredBox(color: Colors.red),
        logicalSize: size,
        pixelRatio: ratio,
      );
      expect(
        (image.width, image.height),
        ((size.width * ratio).round(), (size.height * ratio).round()),
        reason: '$size @ $ratio',
      );
      image.dispose();
    }
  });

  testWidgets('waits for a delegate that loads asynchronously', (tester) async {
    final image = await renderer.render(
      tester,
      Builder(
        builder: (context) => ColoredBox(
          color: Localizations.of<String>(context, String) == 'loaded'
              ? Colors.green
              : Colors.red,
        ),
      ),
      logicalSize: const Size(10, 10),
      pixelRatio: 1,
      localizationsDelegates: const [_SlowDelegate(Duration(milliseconds: 80))],
    );
    final data = (await tester.runAsync(() => image.toByteData()))!;
    expect(
      data.getUint8(1),
      greaterThan(100),
      reason: 'green: rendered after loading',
    );
    image.dispose();
  });

  testWidgets(
    'a delegate that never loads is an error, not a blank slide',
    (tester) async {
      Object? error;
      try {
        await renderer.render(
          tester,
          const SizedBox(),
          logicalSize: const Size(10, 10),
          pixelRatio: 1,
          localizationsDelegates: const [_SlowDelegate(null)],
        );
      } catch (e) {
        error = e;
      }
      expect(error, isA<StateError>());
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
