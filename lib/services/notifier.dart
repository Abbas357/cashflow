import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notifications for changes other people make to shared accounts, on
/// Android and in the browser.
///
/// They come from the app itself when a sync brings someone else's entry,
/// so they show while the app is open or still running in the background,
/// not after Android has closed it. That would need a push service (Firebase
/// Cloud Messaging) sending from the server.
class Notifier {
  Notifier._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<bool>? _ready;

  static bool get supported => kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> _init() => _ready ??= () async {
    if (!supported) return false;
    try {
      final ok = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          web: WebInitializationSettings(),
        ),
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }();

  /// Asks to show notifications. On the web the browser only shows its
  /// question after a tap, so call this from one.
  static Future<bool> requestPermission() async {
    if (!await _init()) return false;
    try {
      if (kIsWeb) {
        return await _plugin
                .resolvePlatformSpecificImplementation<WebFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      }
      return await _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    } catch (_) {
      return false;
    }
  }

  static int _next = 1;

  static Future<void> show(String title, String body) async {
    if (!await _init()) return;
    try {
      await _plugin.show(
        id: _next++,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'shared_changes',
            'Changes by others',
            channelDescription: 'When someone you share an account with adds, edits or deletes an entry.',
          ),
          web: WebNotificationDetails(),
        ),
      );
    } catch (_) {
      // No permission, or the browser cannot show them: nothing to do.
    }
  }
}
