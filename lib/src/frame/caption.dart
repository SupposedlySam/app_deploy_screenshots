import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A headline, an optional subheadline and an optional footnote.
///
/// Font sizes are in points of `MarketingFrame.referenceSize`, scaled by the
/// canvas area, so a caption covers the same share of every store image, from
/// a 1080 × 1920 phone to a 2064 × 2752 iPad.
///
/// To style part of the headline or subheadline differently, wrap it in
/// `**…**` and set [emphasis]:
///
/// ```dart
/// Caption(
///   headline: 'All your chats, **one inbox**',
///   emphasis: CaptionEmphasis.color(Colors.indigo),
/// )
/// ```
///
/// The markers are read only when [emphasis] is set, so captions from 1.x
/// that contain asterisks render as before. `\*` is a literal asterisk, and
/// unmatched markers stay as typed. The `**` survives translation files and
/// tools, so localised captions can mark their own emphasis.
@immutable
final class Caption {
  const Caption({
    required this.headline,
    this.subheadline,
    this.footnote,
    this.emphasis,
    this.headlineStyle,
    this.subheadlineStyle,
    this.footnoteStyle,
    this.textAlign,
    this.textDirection,
  });

  final String headline;
  final String? subheadline;

  /// Small print under the caption, such as terms or a disclaimer. Counted
  /// in the caption's share of the image. Never parsed for emphasis.
  final String? footnote;

  /// How text between `**` markers is styled. Null leaves markers as typed.
  final CaptionEmphasis? emphasis;

  /// Merged over 30pt bold Roboto in a colour that contrasts with the
  /// background. Set `fontFamily` to use one of the app's fonts.
  final TextStyle? headlineStyle;

  /// Merged over 17pt Roboto, slightly muted.
  final TextStyle? subheadlineStyle;

  /// Merged over 11pt Roboto, muted.
  final TextStyle? footnoteStyle;

  /// Null centres the text.
  final TextAlign? textAlign;

  /// Text direction. Null follows the screenshot's locale
  /// (`ScreenshotContext.textDirection`).
  final TextDirection? textDirection;

  /// This caption's text in [shared]'s look: each style merged over
  /// [shared]'s, and the emphasis, alignment and direction taken from it
  /// where this caption leaves them null. Text is never inherited.
  ///
  /// `StoreListing` does this for every slide caption. With the static
  /// methods, style captions once and pass each slide its words:
  ///
  /// ```dart
  /// frame: brand.copyWith(
  ///   caption: Caption(headline: 'Plan **together**').styledLike(brand.caption),
  /// ),
  /// ```
  Caption styledLike(Caption? shared) {
    if (shared == null) return this;
    TextStyle? merge(TextStyle? base, TextStyle? own) =>
        base?.merge(own) ?? own;
    return Caption(
      headline: headline,
      subheadline: subheadline,
      footnote: footnote,
      emphasis: emphasis ?? shared.emphasis,
      headlineStyle: merge(shared.headlineStyle, headlineStyle),
      subheadlineStyle: merge(shared.subheadlineStyle, subheadlineStyle),
      footnoteStyle: merge(shared.footnoteStyle, footnoteStyle),
      textAlign: textAlign ?? shared.textAlign,
      textDirection: textDirection ?? shared.textDirection,
    );
  }
}

/// How emphasised caption text (between `**` markers) is drawn.
@immutable
sealed class CaptionEmphasis {
  const CaptionEmphasis();

  /// Emphasised text in [color].
  const factory CaptionEmphasis.color(Color color) = EmphasisColor;

  /// Emphasised text merged with [style], e.g. a heavier weight.
  const factory CaptionEmphasis.style(TextStyle style) = EmphasisStyle;

  /// A highlighter swipe behind the emphasised text, like a marker pen.
  /// [padding] and [radius] are in caption points.
  const factory CaptionEmphasis.marker(
    Color color, {
    EdgeInsets padding,
    double radius,
    Color? textColor,
  }) = EmphasisMarker;

  /// Emphasised text filled with [gradient], across the emphasised words.
  const factory CaptionEmphasis.gradient(Gradient gradient) = EmphasisGradient;
}

/// See [CaptionEmphasis.color].
final class EmphasisColor extends CaptionEmphasis {
  const EmphasisColor(this.color);
  final Color color;
}

/// See [CaptionEmphasis.style].
final class EmphasisStyle extends CaptionEmphasis {
  const EmphasisStyle(this.style);
  final TextStyle style;
}

/// See [CaptionEmphasis.marker].
final class EmphasisMarker extends CaptionEmphasis {
  const EmphasisMarker(
    this.color, {
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    this.radius = 4,
    this.textColor,
  });
  final Color color;
  final EdgeInsets padding;
  final double radius;

  /// Text colour over the marker, or null to keep the caption colour.
  final Color? textColor;
}

/// See [CaptionEmphasis.gradient].
final class EmphasisGradient extends CaptionEmphasis {
  const EmphasisGradient(this.gradient);
  final Gradient gradient;
}

/// One run of caption text: plain, or between `**` markers.
@immutable
class CaptionRun {
  const CaptionRun(this.text, {this.emphasized = false});
  final String text;
  final bool emphasized;

  @override
  bool operator ==(Object other) =>
      other is CaptionRun &&
      other.text == text &&
      other.emphasized == emphasized;

  @override
  int get hashCode => Object.hash(text, emphasized);

  @override
  String toString() => emphasized ? '**$text**' : text;
}

/// Splits caption markup into runs. `**` opens and closes emphasis, `\*` is
/// a literal asterisk, and a `**` with no partner stays as typed.
@internal
List<CaptionRun> parseCaptionMarkup(String text) {
  // First unescape into characters, remembering which asterisks were
  // escaped, so `\*\*` never counts as a marker.
  final chars = <String>[];
  final escaped = <bool>[];
  for (var i = 0; i < text.length; i++) {
    if (text[i] == r'\' && i + 1 < text.length && text[i + 1] == '*') {
      chars.add('*');
      escaped.add(true);
      i++;
    } else {
      chars.add(text[i]);
      escaped.add(false);
    }
  }
  bool markerAt(int i) =>
      i + 1 < chars.length &&
      chars[i] == '*' &&
      chars[i + 1] == '*' &&
      !escaped[i] &&
      !escaped[i + 1];

  final markers = [
    for (var i = 0; i < chars.length; i++)
      if (markerAt(i) && (i == 0 || !markerAt(i - 1))) i,
  ];
  // Pair markers in order; an odd one out stays literal.
  final paired = markers.length.isEven
      ? markers
      : markers.sublist(0, markers.length - 1);

  final runs = <CaptionRun>[];
  var start = 0;
  var emphasized = false;
  for (final m in paired) {
    final segment = chars.sublist(start, m).join();
    if (segment.isNotEmpty) {
      runs.add(CaptionRun(segment, emphasized: emphasized));
    }
    emphasized = !emphasized;
    start = m + 2;
  }
  final tail = chars.sublist(start).join();
  if (tail.isNotEmpty) runs.add(CaptionRun(tail));
  return runs;
}
