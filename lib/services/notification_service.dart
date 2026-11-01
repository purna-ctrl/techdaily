import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../models/user_preferences.dart';

/// Outcome of turning push notifications on.
enum PushStatus { enabled, denied, unsupported, needsSetup, error }

class PushResult {
  final PushStatus status;
  final String message;
  const PushResult(this.status, this.message);

  bool get isEnabled => status == PushStatus.enabled;
}

abstract class INotificationService {
  Future<bool> requestPermissions();
  Future<void> updateSubscriptions(UserPreferences preferences);
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    String? category,
    String? articleId,
  });
  bool checkRateLimit(String topic);

  /// Asks for permission (only when the user flips the Profile toggle) and
  /// subscribes to `breaking` + `daily-brief` (Android) or stores the web
  /// token in `users/{uid}.fcmTokens`.
  Future<PushResult> enablePush({String? userId});

  /// Unsubscribes / removes the token. Never throws.
  Future<void> disablePush({String? userId});
}

/// Firebase Cloud Messaging implementation. Every call is guarded so the app
/// never crashes on platforms/browsers without push support or when
/// Firebase was not initialised (offline/local mode).
class TechDailyNotificationService implements INotificationService {
  final Map<String, DateTime> _lastSentTimes = {};
  static const Duration minTopicInterval = Duration(hours: 4);

  final FirebaseFirestore? _firestore;

  TechDailyNotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore; // ignore: prefer_initializing_formals

  bool get _firebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isSupported() async {
    if (!_firebaseReady) return false;
    try {
      return await FirebaseMessaging.instance.isSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (!await _isSupported()) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('[Push] permission request failed: $e');
      return false;
    }
  }

  @override
  Future<PushResult> enablePush({String? userId}) async {
    if (!await _isSupported()) {
      return const PushResult(PushStatus.unsupported,
          'Notifications aren’t supported on this device or browser.');
    }
    final granted = await requestPermissions();
    if (!granted) {
      return const PushResult(PushStatus.denied,
          'Notifications are blocked. Allow them in your browser or phone settings.');
    }

    final messaging = FirebaseMessaging.instance;
    try {
      if (kIsWeb) {
        // Topic subscription is not available from the browser. Store the
        // token on the user document; the backend subscribes it server-side.
        if (kWebPushVapidKey.isEmpty) {
          return const PushResult(PushStatus.needsSetup,
              'Web push isn’t configured yet (missing VAPID key).');
        }
        final token = await messaging.getToken(vapidKey: kWebPushVapidKey);
        if (token == null) {
          return const PushResult(PushStatus.error, 'Couldn’t get a push token.');
        }
        if (userId == null || userId.isEmpty) {
          return const PushResult(PushStatus.needsSetup,
              'Sign in to get alerts in this browser.');
        }
        await (_firestore ?? FirebaseFirestore.instance)
            .collection('users')
            .doc(userId)
            .set({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'fcmTopics': [kTopicBreaking, kTopicDailyBrief],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return const PushResult(PushStatus.enabled, 'Alerts are on for this browser.');
      }

      await messaging.subscribeToTopic(kTopicBreaking);
      await messaging.subscribeToTopic(kTopicDailyBrief);
      return const PushResult(PushStatus.enabled,
          'You’ll get breaking news and the daily brief.');
    } catch (e) {
      debugPrint('[Push] enable failed: $e');
      return const PushResult(PushStatus.error, 'Couldn’t turn on notifications. Try again later.');
    }
  }

  @override
  Future<void> disablePush({String? userId}) async {
    if (!await _isSupported()) return;
    final messaging = FirebaseMessaging.instance;
    try {
      if (kIsWeb) {
        final token = kWebPushVapidKey.isEmpty
            ? null
            : await messaging.getToken(vapidKey: kWebPushVapidKey);
        if (token != null && userId != null && userId.isNotEmpty) {
          await (_firestore ?? FirebaseFirestore.instance)
              .collection('users')
              .doc(userId)
              .set({
            'fcmTokens': FieldValue.arrayRemove([token]),
          }, SetOptions(merge: true));
        }
        await messaging.deleteToken();
      } else {
        await messaging.unsubscribeFromTopic(kTopicBreaking);
        await messaging.unsubscribeFromTopic(kTopicDailyBrief);
      }
    } catch (e) {
      debugPrint('[Push] disable failed: $e');
    }
  }

  @override
  Future<void> updateSubscriptions(UserPreferences preferences) async {
    debugPrint(
      '[NotificationService] preferences: '
      'breaking=${preferences.breakingNewsNotifications}, '
      'brief=${preferences.dailyBriefNotifications}',
    );
  }

  @override
  bool checkRateLimit(String topic) {
    final lastSent = _lastSentTimes[topic];
    if (lastSent == null) return true;
    return DateTime.now().difference(lastSent) >= minTopicInterval;
  }

  @override
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    String? category,
    String? articleId,
  }) async {
    final topicKey = category ?? 'general';
    if (!checkRateLimit(topicKey)) return;
    _lastSentTimes[topicKey] = DateTime.now();
    debugPrint('[NotificationService] Dispatched: "$title" - "$body"');
  }
}
