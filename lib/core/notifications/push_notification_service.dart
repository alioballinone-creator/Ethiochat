import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../db/app_database.dart';
import '../logging/app_logger.dart';

const _messageChannelId = 'ethiochat_messages';
const _callChannelId = 'ethiochat_calls';
bool _backgroundHandlerRegistered = false;

FirebaseOptions? firebaseOptionsFromEnv() {
  if (!Env.hasFirebase) return null;
  return FirebaseOptions(
    apiKey: Env.firebaseApiKey,
    appId: Env.firebaseAppId,
    messagingSenderId: Env.firebaseMessagingSenderId,
    projectId: Env.firebaseProjectId,
    storageBucket:
        Env.firebaseStorageBucket.isEmpty ? null : Env.firebaseStorageBucket,
    iosBundleId:
        Env.firebaseIosBundleId.isEmpty ? null : Env.firebaseIosBundleId,
  );
}

/// Initializes Firebase once and registers the background message handler.
///
/// Returns false when push credentials are absent or user/platform setup was
/// incomplete. Callers must treat push as an optional capability.
Future<bool> initializeFirebasePush() async {
  final options = firebaseOptionsFromEnv();
  if (options == null) return false;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: options);
    }
    if (!_backgroundHandlerRegistered) {
      _backgroundHandlerRegistered = true;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
    return true;
  } catch (error, stackTrace) {
    AppLogger.warn(
      'Firebase push initialization failed',
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    final options = firebaseOptionsFromEnv();
    if (options == null) return;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: options);
    }
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await _showNotification(plugin, message, background: true);
  } catch (error) {
    debugPrint('Background push handling failed: $error');
  }
}

class PushNotificationService {
  PushNotificationService({required this.db});

  final AppDatabase db;
  final _notifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  void Function(String location)? _onOpen;
  bool _started = false;
  bool _initialized = false;

  Future<void> start({required void Function(String location) onOpen}) async {
    if (_started) return;
    _started = true;
    _onOpen = onOpen;
    if (!Env.hasFirebase || !Env.hasSupabase) return;
    if (!await initializeFirebasePush()) return;

    await _initializeLocalNotifications();
    final messaging = FirebaseMessaging.instance;
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        AppLogger.info('Push notifications were declined by the user.');
      }
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Could not request push permission',
        error: error,
        stackTrace: stackTrace,
      );
    }

    _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
      unawaited(_handleForeground(message));
    });
    _openedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _openMessage(message);
    });
    _tokenSubscription = messaging.onTokenRefresh.listen((token) {
      unawaited(_registerToken(token));
    });

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.session?.user == null) {
        unawaited(_onSignedOut());
      } else {
        unawaited(_registerCurrentToken());
      }
    });

    final launch = await _notifications.getNotificationAppLaunchDetails();
    final launchPayload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      _openPayload(launchPayload);
    }

    final initial = await messaging.getInitialMessage();
    if (initial != null) _openMessage(initial);

    await _registerCurrentToken();
  }

  Future<void> _initializeLocalNotifications() async {
    if (_initialized) return;
    _initialized = true;
    const initialization = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _notifications.initialize(
      initialization,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _openPayload(payload);
      },
    );
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _messageChannelId,
        'Messages',
        description: 'New message notifications',
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _callChannelId,
        'Incoming calls',
        description: 'Incoming voice and video call alerts',
        importance: Importance.max,
        playSound: true,
      ),
    );
    await android?.requestNotificationsPermission();
  }

  Future<void> _registerCurrentToken() async {
    if (!Env.hasFirebase) return;
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _registerToken(token);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Could not obtain an FCM token',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _registerToken(String token) async {
    if (token.isEmpty) return;
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      // The token is not a secret, but it is account-scoped. The partial unique
      // index on (user_id, fcm_token) makes refresh idempotent.
      await client.from('devices').upsert(
        {
          'user_id': user.id,
          'fcm_token': token,
          'platform': defaultTargetPlatform.name,
          'last_active': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,fcm_token',
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Could not register this device for push',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _onSignedOut() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // The local token is still discarded on the next launch.
    }
  }

  Future<void> _handleForeground(RemoteMessage message) async {
    if (!await _shouldNotify(message)) return;
    await _showNotification(_notifications, message);
  }

  Future<bool> _shouldNotify(RemoteMessage message) async {
    final data = message.data;
    if (data['type'] == 'incoming_call') return true;
    final current = Supabase.instance.client.auth.currentUser?.id;
    if (current != null && data['sender_id'] == current) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationId = data['conversation_id']?.toString();
      if (conversationId != null && conversationId.isNotEmpty) {
        final conversation = await (db.select(db.conversations)
              ..where((row) => row.id.equals(conversationId)))
            .getSingleOrNull();
        if (conversation != null) {
          final mutedUntil = conversation.mutedUntil;
          if (mutedUntil != null && mutedUntil.isAfter(DateTime.now())) {
            return false;
          }
          if (conversation.type == 'group') {
            return prefs.getBool('settings.groupNotifications') ?? true;
          }
        }
      }
      return prefs.getBool('settings.messageNotifications') ?? true;
    } catch (_) {
      return true;
    }
  }

  void _openMessage(RemoteMessage message) {
    final location = _locationFor(message.data);
    if (location != null) _deliverLocation(location);
  }

  void _openPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final location = _locationFor(map);
        if (location != null) _deliverLocation(location);
      }
    } catch (_) {
      // Unknown payloads are ignored rather than opening a broken route.
    }
  }

  void _deliverLocation(String location) {
    final callback = _onOpen;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => callback(location));
  }

  String? _locationFor(Map<String, dynamic> data) {
    final conversationId = data['conversation_id']?.toString();
    if (conversationId == null || conversationId.isEmpty) return null;
    if (data['type'] == 'incoming_call') {
      final callId = data['call_id']?.toString() ?? '';
      final video = data['video'] == 'true' || data['video'] == true;
      return '/call/$conversationId?callId=$callId&incoming=true&video=$video';
    }
    return '/chats/$conversationId';
  }

  void dispose() {
    _authSubscription?.cancel();
    _tokenSubscription?.cancel();
    _messageSubscription?.cancel();
    _openedSubscription?.cancel();
    _authSubscription = null;
    _tokenSubscription = null;
    _messageSubscription = null;
    _openedSubscription = null;
    _onOpen = null;
    _started = false;
  }
}

Future<void> _showNotification(
  FlutterLocalNotificationsPlugin plugin,
  RemoteMessage message, {
  bool background = false,
}) async {
  final data = message.data;
  final isCall = data['type'] == 'incoming_call';
  final title = message.notification?.title ??
      data['title']?.toString() ??
      (isCall ? 'Incoming call' : 'New message');
  final body = message.notification?.body ??
      data['body']?.toString() ??
      (isCall ? 'Tap to answer' : 'You have a new message');
  final payload = jsonEncode(data);
  final id = (message.messageId ?? payload).hashCode & 0x7fffffff;

  if (background && message.notification != null) {
    // Android/iOS already displayed the notification payload. Avoid duplicates.
    return;
  }

  await plugin.show(
    id,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        isCall ? _callChannelId : _messageChannelId,
        isCall ? 'Incoming calls' : 'Messages',
        channelDescription: isCall
            ? 'Incoming voice and video call alerts'
            : 'New message notifications',
        importance: isCall ? Importance.max : Importance.high,
        priority: isCall ? Priority.max : Priority.high,
        category: isCall ? AndroidNotificationCategory.call : null,
        playSound: true,
        fullScreenIntent: false,
        actions: isCall
            ? const [
                AndroidNotificationAction(
                  'open',
                  'Open call',
                  showsUserInterface: true,
                ),
              ]
            : null,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: isCall ? InterruptionLevel.timeSensitive : null,
      ),
    ),
    payload: payload,
  );
}
