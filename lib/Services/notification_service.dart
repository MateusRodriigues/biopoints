// lib/services/notification_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal() {
    _ensureTimezonesInitialized();
  }

  bool _timezonesInitialized = false;
  String _deviceTimezone = 'Etc/UTC';

  Future<void> _ensureTimezonesInitialized() async {
    if (!_timezonesInitialized) {
      try {
        tz.initializeTimeZones();
        _deviceTimezone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(_deviceTimezone));
        _timezonesInitialized = true;
        if (kDebugMode) {
          print(
              "[NotificationService] Timezone inicializado para: $_deviceTimezone (${tz.local.name})");
        }
      } catch (e) {
        if (kDebugMode) {
          print(
              "[NotificationService] Erro ao inicializar timezones: $e. Usando UTC como fallback.");
        }
        tz.setLocalLocation(tz.getLocation('Etc/UTC'));
        _timezonesInitialized = true;
      }
    }
  }

  Future<void> init() async {
    await _ensureTimezonesInitialized();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
            '@mipmap/ic_launcher'); // Use seu ícone de app aqui

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    try {
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            onDidReceiveBackgroundNotificationResponse,
      );
      if (kDebugMode) {
        print("[NotificationService] Plugin de notificações inicializado.");
      }
    } catch (e) {
      if (kDebugMode) {
        print(
            "[NotificationService] Erro ao inicializar plugin de notificações: $e");
      }
    }
    // Solicita permissões após a inicialização do plugin
    if (Platform.isIOS) {
      await requestIOSPermissions();
    } else if (Platform.isAndroid) {
      await requestAndroidPermissions();
    }
  }

  static void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    if (kDebugMode) {
      print(
          "[NotificationService DEBUG] onDidReceiveLocalNotification (iOS foreground): id=$id, title=$title, body=$body, payload=$payload");
    }
  }

  static void onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;
    if (payload != null && kDebugMode) {
      print(
          '[NotificationService DEBUG] onDidReceiveNotificationResponse (usuário tocou): payload=$payload, actionId: ${notificationResponse.actionId}, input: ${notificationResponse.input}');
    }
  }

  @pragma('vm:entry-point')
  static void onDidReceiveBackgroundNotificationResponse(
      NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;
    if (payload != null && kDebugMode) {
      print(
          '[NotificationService DEBUG] onDidReceiveBackgroundNotificationResponse (usuário tocou - app em background/terminado): payload=$payload');
    }
  }

  Future<bool> requestIOSPermissions() async {
    if (!Platform.isIOS) return true;
    if (kDebugMode)
      print("[NotificationService DEBUG] Solicitando permissões iOS...");
    final bool? result = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    if (kDebugMode) {
      print(
          "[NotificationService DEBUG] Permissão iOS solicitada manualmente, resultado: $result");
    }
    return result ?? false;
  }

  Future<bool> requestAndroidPermissions() async {
    if (!Platform.isAndroid) return true;
    if (kDebugMode)
      print("[NotificationService DEBUG] Solicitando permissões Android...");
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final bool? result =
        await androidImplementation?.requestNotificationsPermission();
    if (kDebugMode) {
      print(
          "[NotificationService DEBUG] Permissão Android (API 33+) solicitada manualmente, resultado: $result");
    }
    return result ?? false;
  }

  Future<void> scheduleZonedNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
  }) async {
    await _ensureTimezonesInitialized(); // Garante que os timezones estão realmente prontos

    final DateTime nowDeviceLocal = DateTime.now();
    final DateTime intendedLocalNotificationTime = scheduledDateTime.isUtc
        ? scheduledDateTime.toLocal()
        : scheduledDateTime;

    if (kDebugMode) {
      print(
          "[NotificationService DEBUG scheduleZoned] ID: $id, Title: '$title'");
      print(
          "[NotificationService DEBUG scheduleZoned] scheduledDateTime (recebida): $scheduledDateTime (isUtc: ${scheduledDateTime.isUtc})");
      print(
          "[NotificationService DEBUG scheduleZoned] intendedLocalNotificationTime: $intendedLocalNotificationTime");
      print(
          "[NotificationService DEBUG scheduleZoned] nowDeviceLocal: $nowDeviceLocal");
    }

    if (intendedLocalNotificationTime
        .isBefore(nowDeviceLocal.subtract(const Duration(seconds: 10)))) {
      if (kDebugMode) {
        print(
            "[NotificationService DEBUG scheduleZoned] NÃO AGENDANDO ID $id: Data/Hora local intencionada ($intendedLocalNotificationTime) já passou em relação a ${nowDeviceLocal}.");
      }
      return;
    }

    tz.TZDateTime tzScheduledDate;
    try {
      if (!_timezonesInitialized ||
          tz.local.name == 'Etc/UTC' && _deviceTimezone != 'Etc/UTC') {
        // Se a inicialização do timezone falhou e recorreu a UTC, ou se tz.local ainda é UTC mas não deveria ser
        if (kDebugMode)
          print(
              "[NotificationService DEBUG scheduleZoned] Timezone pode não estar corretamente configurado como local. Tentando re-assegurar.");
        await _ensureTimezonesInitialized(); // Tenta novamente
        if (tz.local.name == 'Etc/UTC' &&
            _deviceTimezone != 'Etc/UTC' &&
            _deviceTimezone.isNotEmpty) {
          // Ainda não pegou o local correto, forçar o uso do deviceTimezone se conhecido
          try {
            tz.setLocalLocation(tz.getLocation(_deviceTimezone));
            if (kDebugMode)
              print(
                  "[NotificationService DEBUG scheduleZoned] Forçando tz.local para $_deviceTimezone");
          } catch (e) {
            if (kDebugMode)
              print(
                  "[NotificationService DEBUG scheduleZoned] Falha ao forçar timezone: $e");
          }
        }
      }
      tzScheduledDate =
          tz.TZDateTime.from(intendedLocalNotificationTime, tz.local);

      if (kDebugMode) {
        print(
            "[NotificationService DEBUG scheduleZoned] TZDateTime a ser agendado: $tzScheduledDate (Location: ${tzScheduledDate.location.name})");
      }
    } catch (e) {
      if (kDebugMode) {
        print(
            "[NotificationService DEBUG scheduleZoned] Erro CRÍTICO ao converter para TZDateTime (ID $id): $e. Data intencionada: $intendedLocalNotificationTime, tz.local atual: ${tz.local.name}. Notificação NÃO será agendada.");
      }
      return; // Não agendar se houver erro na conversão de timezone
    }

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'lembretes_channel_id_biopoints_v1',
      'Lembretes BioPoints',
      channelDescription: 'Canal para notificações de lembretes do BioPoints.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Lembrete BioPoints',
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload ?? 'lembrete_id_$id',
      );
      if (kDebugMode) {
        print(
            "[NotificationService DEBUG scheduleZoned] Notificação ID $id EFETIVAMENTE AGENDADA para $tzScheduledDate.");
      }
    } catch (e) {
      if (kDebugMode) {
        print(
            "[NotificationService DEBUG scheduleZoned] Erro ao chamar plugin.zonedSchedule para ID $id: $e");
        print(
            "[NotificationService DEBUG scheduleZoned] Detalhes: TZDate=$tzScheduledDate, isUTC=${tzScheduledDate.isUtc}, TZName=${tzScheduledDate.location.name}");
      }
    }
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    if (kDebugMode) {
      print("[NotificationService DEBUG] Notificação ID $id cancelada.");
    }
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    if (kDebugMode) {
      print(
          "[NotificationService DEBUG] Todas as notificações foram canceladas.");
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      final List<PendingNotificationRequest> pendingNotificationRequests =
          await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      if (kDebugMode) {
        print(
            "[NotificationService DEBUG] Notificações Pendentes Atualmente (${pendingNotificationRequests.length}):");
        for (var pnr in pendingNotificationRequests) {
          print(
              "  ---> ID: ${pnr.id}, Title: ${pnr.title}, Body: ${pnr.body}, Payload: ${pnr.payload}");
        }
      }
      return pendingNotificationRequests;
    } catch (e) {
      if (kDebugMode) {
        print(
            "[NotificationService DEBUG] Erro ao buscar notificações pendentes: $e");
      }
      return [];
    }
  }
}
