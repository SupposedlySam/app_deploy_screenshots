import 'package:flutter/widgets.dart';

/// Waits for the images in a widget tree to decode, so a capture never shows
/// an empty placeholder. Used for the app under test and for widget slides,
/// so both handle the same image sources.
abstract final class ImagePrimer {
  /// Waits for every [Image] widget and [BoxDecoration] image at or below
  /// [root], including offstage ones. Run outside the fake-async zone.
  static Future<void> prime(Element root) {
    final pending = <Future<void>>[];
    void visit(Element element) {
      final widget = element.widget;
      if (widget is Image) {
        pending.add(precacheImage(widget.image, element));
      } else if (widget is DecoratedBox) {
        final decoration = widget.decoration;
        if (decoration is BoxDecoration && decoration.image != null) {
          pending.add(precacheImage(decoration.image!.image, element));
        }
      }
      element.visitChildren(visit);
    }

    visit(root);
    return Future.wait(pending);
  }
}
