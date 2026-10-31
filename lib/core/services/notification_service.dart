// lib/services/notification_service.dart
import 'dart:convert';
import 'dart:io'; // ← Add this import

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutx_core/flutx_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// True when a tapped push should open the notification page. The app reads
  /// this once the router has left the splash screen.
  final ValueNotifier<bool> pendingOpen = ValueNotifier(false);

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
    playSound: true,
  );

  // Background handler (must be top-level/static)
  static Future<void> _backgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    DPrint.log("Background message: ${message.messageId}");
  }

  Future<void> initialize() async {
    tz.initializeTimeZones();

    // Firebase already initialized in main.dart → safe to use here
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _handleTap(message.data),
    );
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _handleTap(initialMessage.data);

    await _requestPermissions();

    // Foreground presentation options for iOS
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _createNotificationChannel();
    await _initializeLocalNotifications();

    // ← THE MOST IMPORTANT PART: Safe token handling for iOS + Android
    _startFcmTokenSync();
  }

  // ──────────────────────────────────────────────────────────────
  // 1. Permission
  // ──────────────────────────────────────────────────────────────
  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    DPrint.log("Permission status: ${settings.authorizationStatus}");
  }

  // ──────────────────────────────────────────────────────────────
  // 2. Android channel
  // ──────────────────────────────────────────────────────────────
  Future<void> _createNotificationChannel() async {
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  // ──────────────────────────────────────────────────────────────
  // 3. Local notifications (foreground)
  // ──────────────────────────────────────────────────────────────
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );

    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        DPrint.log("Notification tapped: ${response.payload}");
        _handleLocalTap(response.payload);
      },
    );

    // Tapped while the app was closed
    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _handleLocalTap(launchDetails?.notificationResponse?.payload);
    }

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // iOS already shows it, see setForegroundNotificationPresentationOptions
    if (Platform.isIOS) return;

    final imagePath = await _downloadImage(notification.android?.imageUrl);

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
          styleInformation: imagePath == null
              ? null
              : BigPictureStyleInformation(
                  FilePathAndroidBitmap(imagePath),
                  contentTitle: notification.title,
                  summaryText: notification.body,
                ),
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// A failed download only costs the image, so the text still shows.
  Future<String?> _downloadImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) return null;

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/push_${imageUrl.hashCode}');
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (e) {
      DPrint.error("Failed to download notification image: $e");
      return null;
    }
  }

  void _handleLocalTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      _handleTap(jsonDecode(payload) as Map<String, dynamic>);
    } catch (e) {
      DPrint.error("Failed to read notification payload: $e");
    }
  }

  void _handleTap(Map<String, dynamic> data) {
    if (data['type'] == 'promo') pendingOpen.value = true;
  }

  // ──────────────────────────────────────────────────────────────
  // 4. SAFE FCM TOKEN + AUTO UPDATE TO FIRESTORE (this fixes your crash)
  // ──────────────────────────────────────────────────────────────
  void _startFcmTokenSync() {
    // First attempt – safe for both platforms
    _safeGetAndSaveToken();

    // Listen to future refreshes (tokens change often on iOS!)
    _messaging.onTokenRefresh.listen(_safeGetAndSaveToken);
  }

  Future<String?> _safeGetAndSaveToken([String? _]) async {
    String? token;

    // ── iOS: wait for APNs token first ───────────────────────
    if (Platform.isIOS) {
      for (int i = 0; i < 20; i++) {
        // increased retries
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) {
          DPrint.log("APNs token received");
          token = await _messaging.getToken();
          break;
        }
        DPrint.log("Waiting for APNs token... attempt ${i + 1}");
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    // ── Android: instant ─────────────────────────────────────
    else {
      token = await _messaging.getToken();
    }

    // If we still don’t have a token → give up
    if (token == null) {
      DPrint.error("Failed to retrieve FCM token");
      return null; // ← now returns null (String?)
    }

    DPrint.log("FCM Token obtained: $token");

    // ── Save to Firestore if user is authenticated ───────────
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        String deviceName = 'Unknown Device';
        try {
          final deviceInfo = DeviceInfoPlugin();
          if (Platform.isAndroid) {
            final androidInfo = await deviceInfo.androidInfo;
            deviceName = '${androidInfo.brand} ${androidInfo.model}';
          } else if (Platform.isIOS) {
            final iosInfo = await deviceInfo.iosInfo;
            deviceName = iosInfo.name;
          }
        } catch (e) {
          DPrint.error("Failed to get device info: $e");
        }

        // 1. Save to the fcmTokens subcollection to keep track of multiple devices
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('fcmTokens')
            .doc(token)
            .set({
              'deviceName': deviceName,
              'platform': Platform.isIOS ? 'ios' : 'android',
              'token': token,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        // 2. Also save the latest token to the main user document
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'platform': Platform.isIOS ? 'ios' : 'android',
        }, SetOptions(merge: true));

        DPrint.log(
          "FCM token saved to Firestore subcollection for ${user.uid}",
        );

        _subscribeTopics();
      } catch (e) {
        DPrint.error("Failed to save FCM token: $e");
      }
    }

    return token; // ← correct return type: Future<String?>
  }

  Future<void> _subscribeTopics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _messaging.subscribeToTopic('all_users');
      // await _messaging.subscribeToTopic('user_${user.uid}');
    }
  }

  // Public helpers (optional)
  Future<String?> getToken() async => await _safeGetAndSaveToken();
  Future<void> subscribeToTopic(String topic) =>
      _messaging.subscribeToTopic(topic);
  Future<void> unsubscribeFromTopic(String topic) =>
      _messaging.unsubscribeFromTopic(topic);
}
