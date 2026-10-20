import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Push notifications through Firebase Cloud Messaging, on Android, as in
/// the HRM app.
///
/// When someone uploads a change to a shared account, the notify-changes
/// Edge Function pushes it to every other member's phones, and Android
/// shows it even while Cash Flow is closed. This registers the phone with
/// Supabase (`push_devices`) for the signed-in person, and hands on what
/// happens to a push: one arriving while the app is open (Android shows
/// nothing then) and one tapped.
class Push {
  static bool _available = false;

  /// Whether Firebase started: on Android, with google-services.json in
  /// the build and Google Play services on the phone.
  static bool get available => _available;

  /// Starts Firebase, before the app opens. Without it the app works as
  /// before, with notifications only while it is open.
  static Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (error) {
      if (kDebugMode) debugPrint('Push notifications are off: $error');
    }
  }

  final SupabaseClient _client;

  Push(this._client);

  final _subscriptions = <StreamSubscription<Object?>>[];
  String? _token;

  bool get active => _subscriptions.isNotEmpty;

  /// Registers this phone and listens for pushes. [onArrived] gets a push
  /// that came while the app was open; [onOpened] the account a tapped
  /// push is about, the one that opened the app included.
  Future<void> start({
    required void Function(String title, String body) onArrived,
    required void Function(String accountId) onOpened,
  }) async {
    if (!_available || active) return;
    final messaging = FirebaseMessaging.instance;
    try {
      // Android 13 and later ask once. Refused, the bell still counts.
      await messaging.requestPermission();
      _subscriptions
        // ignore: deprecated_member_use
        ..add(messaging.onTokenRefresh.listen(_register))
        ..add(
          FirebaseMessaging.onMessage.listen((m) {
            final n = m.notification;
            if (n != null) onArrived(n.title ?? '', n.body ?? '');
          }),
        )
        ..add(
          FirebaseMessaging.onMessageOpenedApp.listen((m) {
            final id = m.data['account_id'];
            if (id is String) onOpened(id);
          }),
        );

      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null) await _register(token);

      final opening = await messaging.getInitialMessage();
      final id = opening?.data['account_id'];
      if (id is String) onOpened(id);
    } catch (error) {
      // Offline, or Firebase out of reach: the next start tries again.
      if (kDebugMode) debugPrint('Push registration failed: $error');
    }
  }

  /// Stops pushes to this phone: on signing out, or when notifications are
  /// turned off in Settings.
  Future<void> stop() async {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
    final token = _token;
    _token = null;
    if (!_available || token == null) return;
    try {
      await _client.rpc('unregister_push_device', params: {'p_token': token});
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Offline: the server forgets the token once Firebase drops it.
    }
  }

  Future<void> _register(String token) async {
    _token = token;
    try {
      await _client.rpc('register_push_device', params: {'p_token': token, 'p_platform': 'android'});
      if (kDebugMode) debugPrint('This phone will receive push notifications.');
    } catch (error) {
      if (kDebugMode) debugPrint('Push registration failed: $error');
    }
  }
}
