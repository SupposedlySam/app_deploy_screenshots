import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../annotations.dart';

/// Finds annotation targets in the widget tree. Part of capture: it reads
/// the tree, under the device's overrides, before the image is taken.
abstract final class AnnotationResolver {
  static List<ResolvedAnnotation> resolve(
    WidgetTester tester,
    List<ScreenshotAnnotation> annotations,
  ) => [for (final a in annotations) ResolvedAnnotation(a, _rectOf(tester, a))];

  static Rect _rectOf(WidgetTester tester, ScreenshotAnnotation a) {
    final matches = a.target.evaluate();
    if (matches.isEmpty) {
      throw StateError(
        '${a.runtimeType} target matched no widgets: ${a.target.describeMatch(Plurality.zero)}',
      );
    }
    return tester.getRect(find.byElementPredicate((e) => e == matches.first));
  }
}
