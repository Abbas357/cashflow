import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/settings_controller.dart';

/// Tells the cloud which country and currency this install uses, so people
/// per country can be counted. Works signed out, and sends only a random id
/// that is not tied to the person's account, never a name or an entry.
///
/// Waits until the welcome popup, which explains this, is finished. Sends
/// again only when something changes. With no connection it tries again at
/// the next change or the next launch, and the app never notices.
class InstallReport {
  final SettingsController settings;
  final Future<void> Function(Map<String, Object?> params) _send;
  bool _sending = false;

  InstallReport(this.settings, {Future<void> Function(Map<String, Object?> params)? send})
    : _send = send ?? _toCloud;

  static Future<void> _toCloud(Map<String, Object?> params) =>
      Supabase.instance.client.rpc('report_install', params: params);

  static Future<void> _deleteFromCloud(String id) =>
      Supabase.instance.client.rpc('delete_install', params: {'p_id': id});

  /// The device type reported, such as android or web.
  static String get platform => kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();

  /// Removes what this install reported and stops it reporting again, or the
  /// next launch would bring it back. Needs a connection only if something
  /// was sent. Throws if that fails, and then nothing has changed.
  static Future<void> delete(SettingsController settings, {Future<void> Function(String id)? remove}) async {
    final sent = settings.installReported != null;
    await settings.setInstallStatsOff(true);
    try {
      if (sent) await (remove ?? _deleteFromCloud)(settings.installId);
    } catch (_) {
      await settings.setInstallStatsOff(false);
      rethrow;
    }
    await settings.clearInstallReported();
  }

  void start() {
    settings.addListener(_check);
    unawaited(_check());
  }

  void stop() => settings.removeListener(_check);

  Future<void> _check() async {
    if (_sending || !settings.onboarded || settings.installStatsOff) return;
    final country = settings.country;
    final currency = settings.currencyInfo.code;
    final what = '$country|$currency|$platform';
    if (what == settings.installReported) return;
    _sending = true;
    try {
      await _send({
        'p_id': settings.installId,
        'p_country': country,
        'p_currency': currency,
        'p_platform': platform,
      });
      await settings.setInstallReported(what);
    } catch (_) {
      // Offline, or the cloud is unavailable: the next try will do.
    } finally {
      _sending = false;
    }
  }
}
