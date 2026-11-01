import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.finance.cash_flow/region');

/// What Android knows about where it is (see MainActivity.kt). Other
/// platforms have nothing here and fall back to the language setting.
Future<({String? sim, String? network, String? zone})> regionHints() async {
  if (defaultTargetPlatform != TargetPlatform.android) return (sim: null, network: null, zone: null);
  try {
    // Startup waits for this, so it must never hang.
    final hints = await _channel.invokeMapMethod<String, String?>('hints').timeout(const Duration(seconds: 2));
    return (sim: hints?['sim'], network: hints?['network'], zone: hints?['zone']);
  } catch (_) {
    return (sim: null, network: null, zone: null);
  }
}
