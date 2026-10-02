import '../../device.dart';
import '../variant.dart';

/// Where each screenshot is written. Every path the package builds comes from
/// here, so the folder layout, which upload scripts depend on, is defined in
/// one place.
abstract final class OutputPaths {
  /// The directory screenshots are written to unless a path says otherwise.
  static const String defaultRoot = 'app_deploy_screenshots';

  /// `<root>/<platform>/<device>/<stem>.png`, one folder per store slot.
  /// Used by `forStores`.
  static String store(String root, Device device, ScreenshotContext context) =>
      '$root/${device.platform.name}/${device.name}/${context.fileStem}.png';

  /// `app_deploy_screenshots/<platform>/<size>_<device>/<stem>.png`. Used by
  /// `byPlatform`.
  static String platform(Device device, ScreenshotContext context) =>
      '$defaultRoot/${device.platform.name}/'
      '${device.displaySize.label}_${device.name}/'
      '${context.fileStem}.png';

  /// `app_deploy_screenshots/<device>.<stem>.png`. The `byDevices` default.
  static String flat(Device device, ScreenshotContext context) =>
      '$defaultRoot/${device.name}.${context.fileStem}.png';

  /// A path from a user's `fileNameBuilder`, with the order prefix and
  /// variant suffix added to its file name: `a/b/home.png` becomes
  /// `a/b/01_home.dark.png`.
  static String decorate(String path, ScreenshotContext context) {
    if (context.orderPrefix.isEmpty && context.variantSuffix.isEmpty) {
      return path;
    }
    final slash = path.lastIndexOf('/');
    var base = path.substring(slash + 1);
    if (base.endsWith('.png')) base = base.substring(0, base.length - 4);
    return '${path.substring(0, slash + 1)}'
        '${context.orderPrefix}$base${context.variantSuffix}.png';
  }
}
