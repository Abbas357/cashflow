import 'dart:ui' show PlatformDispatcher;

import 'region_hints_io.dart' if (dart.library.js_interop) 'region_hints_web.dart';
import 'zone_countries.dart';

/// Works out which country this device is in, without asking for any
/// permission and without going online.
class DeviceRegion {
  DeviceRegion._();

  static Future<String?> detect() async {
    final hints = await regionHints();
    return pick(
      sim: hints.sim,
      network: hints.network,
      zone: hints.zone,
      locale: PlatformDispatcher.instance.locale.countryCode,
    );
  }

  /// The most reliable answer available: the SIM's country, then the mobile
  /// network's, then the time zone's. The language setting comes last, since
  /// many people use "English (United States)" wherever they live.
  static String? pick({String? sim, String? network, String? zone, String? locale}) {
    for (final candidate in [sim, network, zoneCountries[zone], locale]) {
      final code = candidate?.trim().toUpperCase() ?? '';
      if (RegExp(r'^[A-Z]{2}$').hasMatch(code)) return code;
    }
    return null;
  }
}
