/// ***************************************************
/// Copyright 2019-2020 eBay Inc.
///
/// Use of this source code is governed by a BSD-style
/// license that can be found in the LICENSE file or at
/// https://opensource.org/licenses/BSD-3-Clause
/// ***************************************************
library;

import 'package:flutter/widgets.dart';

enum DevicePlatform { ios, android }

/// Represents standard iOS device display sizes
enum DisplaySize {
  // iPhones
  threeFive(3.5),
  four(4.0),
  fourSeven(4.7),
  fiveFive(5.5),
  sixOne(6.1),
  sixThree(6.3),
  sixFive(6.5),
  sixNine(6.9),

  // iPads
  nineSeven(9.7),
  tenFive(10.5),
  eleven(11.0),
  twelveNine(12.9),
  thirteen(13.0);

  const DisplaySize(this.inches);
  final double inches;

  String get label => '$inches';

  @override
  String toString() => label;
}

/// The kind of device a [Device] is. Store upload folders that sort
/// screenshots by kind, such as fastlane supply's, use it.
enum DeviceType { phone, tablet, chromebook, tv, wear }

/// This [Device] is a configuration for golden test. Can be provided for [multiScreenGolden]
///
/// Check these locations for the latest specs:
/// Apple: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/
/// Google: https://support.google.com/googleplay/android-developer/answer/9866151?hl=en&sjid=9437801895573353493-NA#zippy=%2Cscreenshots
final class Device {
  /// This [Device] is a configuration for golden test. Can be provided for [multiScreenGolden]
  const Device({
    required this.size,
    required this.name,
    this.displaySize,
    required this.platform,
    this.devicePixelRatio = 1.0,
    this.textScale = 1.0,
    this.brightness = Brightness.light,
    this.safeArea = const EdgeInsets.all(0),
    this.screenCornerRadius = 0,
    this.type,
  });

  /// iPhone 6.9" App Store size: 1320 × 2868 px (iPhone 16 Pro Max).
  ///
  /// The size App Store Connect requires for iPhone apps; it scales these
  /// screenshots down for every smaller iPhone.
  static const Device appStoreIphone69 = Device(
    name: 'app_store_iphone_6_9',
    size: Size(440, 956),
    displaySize: DisplaySize.sixNine,
    platform: DevicePlatform.ios,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 62, bottom: 34),
    screenCornerRadius: 55,
    type: DeviceType.phone,
  );

  /// iPad 13" App Store size: 2064 × 2752 px (iPad Pro M4).
  ///
  /// Required when the app runs on iPad; scaled down for smaller iPads.
  static const Device appStoreIpad13 = Device(
    name: 'app_store_ipad_13',
    size: Size(1032, 1376),
    displaySize: DisplaySize.thirteen,
    platform: DevicePlatform.ios,
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 24, bottom: 20),
    screenCornerRadius: 18,
    type: DeviceType.tablet,
  );

  /// Google Play phone size: 1080 × 1920 px (9:16).
  ///
  /// Play rejects screenshots whose long side is more than twice the short
  /// side, which rules out native 20:9 phone resolutions such as 1080 × 2400.
  /// 9:16 at 1080 px or more also qualifies for promotional placement. To
  /// show a taller phone, render a taller [Device] and place it on a
  /// 1080 × 1920 canvas with a `MarketingFrame`.
  static const Device playStorePhone = Device(
    name: 'play_store_phone',
    size: Size(432, 768),
    platform: DevicePlatform.android,
    devicePixelRatio: 2.5,
    safeArea: EdgeInsets.only(top: 24),
    type: DeviceType.phone,
  );

  /// Google Play 7" tablet size: 1224 × 2176 px (9:16), 612 dp wide.
  static const Device playStoreTablet7 = Device(
    name: 'play_store_tablet_7',
    size: Size(612, 1088),
    platform: DevicePlatform.android,
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 24),
    type: DeviceType.tablet,
  );

  /// Google Play 10" tablet size: 1620 × 2880 px (9:16), 810 dp wide.
  static const Device playStoreTablet10 = Device(
    name: 'play_store_tablet_10',
    size: Size(810, 1440),
    platform: DevicePlatform.android,
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 24),
    type: DeviceType.tablet,
  );

  /// Google Play phone at 1080 × 2400 (20:9), a modern phone's native
  /// shape.
  ///
  /// Not in [playStore]. Play's written rule is that the long side be at
  /// most twice the short side, which this breaks (2.22:1), so
  /// [meetsPlayStoreRequirements] says no; but several top apps have
  /// screenshots this tall live on Play. Prefer [playStorePhone] (9:16),
  /// which also qualifies for promotional placement.
  static const Device playStorePhoneTall = Device(
    name: 'play_store_phone_tall',
    size: Size(360, 800),
    platform: DevicePlatform.android,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 24),
    type: DeviceType.phone,
  );

  /// Google Play Wear OS: 454 × 454 (1:1). Play asks for square
  /// screenshots of at least 384 × 384 and no device frames, so capture
  /// these raw, without a `MarketingFrame`. Play applies its own round
  /// mask.
  static const Device playStoreWear = Device(
    name: 'play_store_wear',
    size: Size(227, 227),
    platform: DevicePlatform.android,
    devicePixelRatio: 2.0,
    type: DeviceType.wear,
  );

  /// Google Play Chromebook: 1920 × 1080 (16:9 landscape).
  static const Device playStoreChromebook = Device(
    name: 'play_store_chromebook',
    size: Size(1280, 720),
    platform: DevicePlatform.android,
    devicePixelRatio: 1.5,
    type: DeviceType.chromebook,
  );

  /// The sizes App Store Connect requires: iPhone 6.9" and iPad 13".
  static const List<Device> appStore = [appStoreIphone69, appStoreIpad13];

  /// Google Play phone, 7" tablet and 10" tablet sizes, all 9:16.
  static const List<Device> playStore = [
    playStorePhone,
    playStoreTablet7,
    playStoreTablet10,
  ];

  /// [phone] one of the smallest phone screens
  static const Device phone = Device(
    name: 'phone',
    size: Size(375, 667),
    displaySize: DisplaySize.fourSeven, // iPhone 6/6s/7/8 size
    platform: DevicePlatform.ios,
  );

  /// [iphone11] matches specs of iphone11, but with lower DPI for performance
  static const Device iphone11 = Device(
    name: 'iphone11',
    size: Size(414, 896),
    displaySize: DisplaySize.sixOne,
    platform: DevicePlatform.ios,
    devicePixelRatio: 1.0,
    safeArea: EdgeInsets.only(top: 44, bottom: 34),
  );

  /// [tabletLandscape] example of tablet that in landscape mode
  static const Device tabletLandscape = Device(
    name: 'tablet_landscape',
    size: Size(1366, 1024),
    displaySize: DisplaySize.tenFive, // 10.5" iPad size in landscape
    platform: DevicePlatform.ios,
  );

  /// [tabletPortrait] example of tablet that in portrait mode
  static const Device tabletPortrait = Device(
    name: 'tablet_portrait',
    size: Size(1024, 1366),
    displaySize: DisplaySize.tenFive, // 10.5" iPad size in portrait
    platform: DevicePlatform.ios,
  );

  /// iPhone Devices (6.9")
  static const Device iphone16ProMax = Device(
    name: 'iphone16_pro_max',
    size: Size(430, 932), // 1290/3, 2796/3
    displaySize: DisplaySize.sixNine,
    platform: DevicePlatform.ios,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 62, bottom: 34),
  );

  /// iPhone Devices (6.5")
  static const Device iphone14Plus = Device(
    name: 'iphone14_plus',
    size: Size(428, 926), // 1284/3, 2778/3
    displaySize: DisplaySize.sixFive,
    platform: DevicePlatform.ios,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 47, bottom: 34),
  );

  /// iPhone Devices (6.3")
  static const Device iphone16Pro = Device(
    name: 'iphone16_pro',
    size: Size(393, 852), // 1179/3, 2556/3
    displaySize: DisplaySize.sixThree,
    platform: DevicePlatform.ios,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 62, bottom: 34),
  );

  /// iPhone Devices (6.1")
  static const Device iphone14 = Device(
    name: 'iphone14',
    size: Size(390, 844), // 1170/3, 2532/3
    displaySize: DisplaySize.sixOne,
    platform: DevicePlatform.ios,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 47, bottom: 34),
  );

  /// iPhone Devices (5.5")
  static const Device iphone8Plus = Device(
    name: 'iphone8_plus',
    size: Size(414, 736), // 1242/3, 2208/3
    displaySize: DisplaySize.fiveFive,
    platform: DevicePlatform.ios,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 20),
  );

  /// iPhone Devices (4.7")
  static const Device iphoneSE3 = Device(
    name: 'iphone_se_3',
    size: Size(375, 667), // 750/2, 1334/2
    displaySize: DisplaySize.fourSeven,
    platform: DevicePlatform.ios,
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 20),
  );

  /// iPad Devices (13")
  static const Device ipadProM4 = Device(
    name: 'ipad_pro_m4',
    size: Size(1032, 1376), // 2064/2, 2752/2
    displaySize: DisplaySize.thirteen,
    platform: DevicePlatform.ios,
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 24, bottom: 20),
  );

  /// iPad Devices (12.9")
  static const Device ipadPro12_9 = Device(
    name: 'ipad_pro_12_9',
    size: Size(1024, 1366), // 2048/2, 2732/2
    displaySize: DisplaySize.twelveNine,
    platform: DevicePlatform.ios,
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 24, bottom: 20),
  );

  /// iPad Devices (11")
  static const Device ipadPro11 = Device(
    name: 'ipad_pro_11',
    size: Size(834, 1194), // 1668/2, 2388/2
    displaySize: DisplaySize.eleven,
    platform: DevicePlatform.ios,
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 24, bottom: 20),
  );

  /// Mac (16:10 aspect ratio)
  static const Device macDefault = Device(
    name: 'mac_default',
    size: Size(1440, 900),
    displaySize: DisplaySize.thirteen, // Using largest size for Mac
    platform: DevicePlatform.ios,
  );

  /// Apple TV
  static const Device appleTV = Device(
    name: 'apple_tv',
    size: Size(1920, 1080),
    displaySize: DisplaySize.thirteen, // Using largest size for TV
    platform: DevicePlatform.ios,
    type: DeviceType.tv,
  );

  /// Apple Vision Pro
  static const Device visionPro = Device(
    name: 'vision_pro',
    size: Size(3840, 2160),
    displaySize: DisplaySize.thirteen, // Using largest size for Vision Pro
    platform: DevicePlatform.ios,
  );

  /// Android phone, 16:9 landscape: 1920 × 1080 px.
  static const Device androidPhoneWide = Device(
    name: 'android_phone_16_9',
    size: Size(640, 360), // 1920/3, 1080/3
    displaySize: DisplaySize.sixOne,
    platform: DevicePlatform.android,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 24),
  );

  /// Android Phone Screenshots - 9:16 aspect ratio
  static const Device androidPhone = Device(
    name: 'android_phone_9_16',
    size: Size(360, 640), // 1080/3, 1920/3
    displaySize: DisplaySize.sixOne,
    platform: DevicePlatform.android,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 24),
  );

  /// Android phone, 18:9 portrait: 1080 × 2160 px.
  ///
  /// Before 2.0 this was landscape (2160 × 1080) despite its name.
  static const Device androidPhoneTall = Device(
    name: 'android_phone_18_9',
    size: Size(360, 720), // 1080/3, 2160/3
    displaySize: DisplaySize.sixThree,
    platform: DevicePlatform.android,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 24),
  );

  /// Android phone, 20:9 portrait: 1080 × 2400 px. Taller than Play's
  /// written 2:1 limit; see [playStorePhoneTall].
  ///
  /// Before 2.0 this was landscape (2400 × 1080) despite its name.
  static const Device androidPhoneExtra = Device(
    name: 'android_phone_20_9',
    size: Size(360, 800), // 1080/3, 2400/3
    displaySize: DisplaySize.sixFive,
    platform: DevicePlatform.android,
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 24),
  );

  /// Android Tablet Screenshots - 16:10 aspect ratio
  static const Device androidTablet = Device(
    name: 'android_tablet',
    size: Size(1280, 800), // 2560/2, 1600/2
    displaySize: DisplaySize.tenFive,
    platform: DevicePlatform.android,
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 24),
    type: DeviceType.tablet,
  );

  /// Android TV Screenshots - 16:9 aspect ratio
  static const Device androidTV = Device(
    name: 'android_tv',
    size: Size(1920, 1080), // No scaling needed for TV
    displaySize: DisplaySize.thirteen,
    platform: DevicePlatform.android,
    devicePixelRatio: 1.0,
    safeArea: EdgeInsets.zero,
    type: DeviceType.tv,
  );

  static const List<Device> allDevices = [
    iphone16ProMax,
    iphone16Pro,
    iphone14Plus,
    iphone14,
    iphone11,
    iphone8Plus,
    iphoneSE3,
    phone,
    ipadProM4,
    ipadPro12_9,
    ipadPro11,
    androidPhone,
    androidPhoneWide,
    androidPhoneTall,
    androidPhoneExtra,
    androidTablet,
    androidTV,
    visionPro,
    macDefault,
    appleTV,
  ];

  static List<Device> byPlatform(DevicePlatform platform) {
    return allDevices.where((device) => device.platform == platform).toList();
  }

  /// [name] specify device name. Ex: Phone, Tablet, Watch

  final String name;

  /// [size] specify device screen size. Ex: Size(1366, 1024))
  final Size size;

  /// [devicePixelRatio] specify device Pixel Ratio
  final double devicePixelRatio;

  /// [textScale] specify custom text scale
  final double textScale;

  /// [brightness] specify platform brightness
  final Brightness brightness;

  /// [safeArea] the system insets (status bar, home indicator) in logical
  /// points, as the app reads them from `MediaQuery.paddingOf`.
  final EdgeInsets safeArea;

  /// [displaySize] specify display size
  final DisplaySize? displaySize;

  /// [platform] specify platform
  final DevicePlatform platform;

  /// Corner radius of the physical screen in logical points, used when a
  /// `MarketingFrame` draws the screen. 0 means square corners.
  final double screenCornerRadius;

  /// What kind of device this is. `OutputLayout.fastlane` files Android
  /// screenshots by it (phone, 7" or 10" tablet, TV, Wear OS). Null: worked
  /// out from [size], where 600 dp across is a tablet and a small square a
  /// watch, so a TV or Chromebook needs it set.
  final DeviceType? type;

  /// The size of a full-screen capture, in pixels.
  Size get pixelSize => size * devicePixelRatio;

  /// Filter devices by display size
  static List<Device> byDisplaySize(DisplaySize size) {
    return [
      iphone16ProMax,
      iphone16Pro,
      iphone14Plus,
      iphone14,
      iphone11,
      iphone8Plus,
      iphoneSE3,
      phone,
      ipadProM4,
      ipadPro12_9,
      ipadPro11,
      // Add any other device constants here
    ].where((device) => device.displaySize == size).toList();
  }

  /// [copyWith] convenience function for [Device] modification
  Device copyWith({
    Size? size,
    double? devicePixelRatio,
    String? name,
    double? textScale,
    Brightness? brightness,
    EdgeInsets? safeArea,
    DisplaySize? displaySize,
    DevicePlatform? platform,
    double? screenCornerRadius,
    DeviceType? type,
  }) {
    return Device(
      size: size ?? this.size,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
      name: name ?? this.name,
      textScale: textScale ?? this.textScale,
      brightness: brightness ?? this.brightness,
      safeArea: safeArea ?? this.safeArea,
      displaySize: displaySize ?? this.displaySize,
      platform: platform ?? this.platform,
      screenCornerRadius: screenCornerRadius ?? this.screenCornerRadius,
      type: type ?? this.type,
    );
  }

  /// [dark] convenience method to copy the current device and apply dark theme
  Device dark() => copyWith(brightness: Brightness.dark, name: '${name}_dark');

  /// Helper method to get screenshot configurations
  static List<Device> androidScreenshots({DeviceType type = DeviceType.phone}) {
    switch (type) {
      case DeviceType.phone:
        return [
          androidPhoneWide, // 16:9
          androidPhoneTall, // 18:9
          androidPhoneExtra, // 20:9
        ];
      case DeviceType.tablet:
        return [androidTablet]; // 16:10
      case DeviceType.tv:
        return [androidTV]; // 16:9
      default:
        return [androidPhoneTall]; // Default to common phone size
    }
  }

  /// Whether a full-screen capture on this device is a valid Google Play
  /// screenshot: each side 320–3840 px, and the long side at most twice the
  /// short side.
  ///
  /// Before 1.1.0 this checked the logical size and ignored the aspect rule.
  bool meetsPlayStoreRequirements() {
    final shortSide = pixelSize.shortestSide;
    final longSide = pixelSize.longestSide;
    return shortSide >= 320 && longSide <= 3840 && longSide <= shortSide * 2;
  }

  @override
  String toString() {
    return 'Device: $name, ${size.width}x${size.height} @ $devicePixelRatio, text: $textScale, $brightness, safe: $safeArea';
  }
}
