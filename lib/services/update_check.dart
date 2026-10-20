import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../core/config/page_base_io.dart' if (dart.library.js_interop) '../core/config/page_base_web.dart';

/// On the web: notices when a newer build has been published while the
/// page is open, so it can offer to reload.
///
/// Each deploy stamps its build id into the app (`--dart-define=BUILD_ID`)
/// and into `build_id.txt` beside it (tool/web_cache_bust.dart). When the
/// file on the server says something else, a new version is out.
class UpdateCheck {
  final VoidCallback onNewVersion;

  UpdateCheck(this.onNewVersion);

  static const buildId = String.fromEnvironment('BUILD_ID');
  static bool get enabled => kIsWeb && buildId != '';

  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _told = false;

  void start() {
    if (!enabled) return;
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _check());
    // Also when coming back to the tab, the likeliest moment to have missed one.
    _lifecycle = AppLifecycleListener(onResume: _check);
  }

  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
  }

  Future<void> _check() async {
    if (_told) return;
    try {
      // The time in the address keeps any cache from answering.
      final url = Uri.parse('${pageBase()}build_id.txt?t=${DateTime.now().millisecondsSinceEpoch}');
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      final live = res.body.trim();
      if (res.statusCode == 200 && live.isNotEmpty && live != buildId) {
        _told = true;
        onNewVersion();
      }
    } catch (_) {
      // Offline or unreachable: try again next time.
    }
  }

  static void reload() => reloadPage();
}
