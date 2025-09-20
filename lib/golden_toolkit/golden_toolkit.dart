/// ***************************************************
/// Copyright 2019-2020 eBay Inc.
///
/// Use of this source code is governed by a BSD-style
/// license that can be found in the LICENSE file or at
/// https://opensource.org/licenses/BSD-3-Clause
/// ***************************************************
// ignore:unnecessary_library_name
library golden_toolkit;

export '../configuration.dart';
export '../device.dart';
export 'src/device_builder.dart';
export 'src/font_loader.dart' show loadAppFonts;
export 'src/testing_tools.dart' hide compareWithGolden;
export '../widget_tester_extensions.dart';
