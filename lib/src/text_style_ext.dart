import 'package:flutter/painting.dart';

import 'setup/fonts.dart';

/// Text styles for what the package draws itself.
abstract final class PackageText {
  /// The family the package's own text uses, with the static Roboto as a
  /// fallback if the variable one could not be loaded.
  static const String family = FontSetup.textFontFamily;
  static const List<String> fallback = ['Roboto'];

  /// [style] with its weight applied as a `wght` variation too, unless it
  /// sets variations itself. A variable font only changes weight through
  /// its axis; `fontWeight` alone gets a faint synthetic bold. Static fonts
  /// ignore the variation.
  static TextStyle withWeightAxis(TextStyle style) {
    final weight = style.fontWeight;
    if (weight == null || style.fontVariations != null) return style;
    return style.copyWith(
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
    );
  }
}
