import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notifications for changes other people make to shared accounts, on
/// Android and in the browser.
///
/// On the web they come from the app itself when a sync brings someone
/// else's entry, so they show while the page is open. On Android, Firebase
/// pushes them from the server (`Push`), even with the app closed; this
/// shows the ones arriving while it is open, in the same channel.
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
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          web: WebInitializationSettings(),
        ),
      );
      // The channel Firebase pushes arrive in too (AndroidManifest.xml).
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              channelId,
              'Changes by others',
              description: _channelDescription,
              importance: Importance.high,
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

  static const channelId = 'shared_changes';
  static const _channelDescription = 'When someone you share an account with adds, edits or deletes an entry.';

  /// Creates the notification channel at startup, so pushes that arrive
  /// before anything else is shown land in it.
  static Future<void> prepare() => _init();

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
            channelId,
            'Changes by others',
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFF006B3C),
          ),
          web: WebNotificationDetails(),
        ),
      );
    } catch (_) {
      // No permission, or the browser cannot show them: nothing to do.
    }
  }
}
