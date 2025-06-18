// lib/main.dart (Corrigido para chamar permissões do NotificationService)
import 'package:biopoints/services/notification_service.dart'; // IMPORTADO
import 'package:biopoints/utils/app_colors.dart';
import 'package:biopoints/view/home/home_screen.dart';
import 'package:biopoints/view/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform; // Para checar plataforma

// Instância global (ou injetada via Provider/GetIt)
final NotificationService notificationService = NotificationService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o serviço de notificação (incluindo timezones)
  await notificationService.init();

  // Solicita permissões após a inicialização do plugin
  if (Platform.isIOS) {
    await notificationService.requestIOSPermissions();
  } else if (Platform.isAndroid) {
    await notificationService.requestAndroidPermissions();
  }

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool rememberMe = prefs.getBool('remember_me') ?? false;
  String? token = prefs.getString('jwt_token');
  bool isLoggedIn = rememberMe && (token != null && token.isNotEmpty);

  if (kDebugMode) {
    print("[main] Remember Me: $rememberMe");
    print("[main] Token exists: ${token != null && token.isNotEmpty}");
    print("[main] Should log in automatically: $isLoggedIn");
  }

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BioPoints App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimaryBlue),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimaryBlue,
          foregroundColor: kWhite,
          elevation: 1,
          iconTheme: IconThemeData(color: kWhite),
          titleTextStyle: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: kWhite),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryBlue,
                foregroundColor: kWhite,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600))),
      ),
      home: isLoggedIn ? const HomePage() : const LoginScreen(),
    );
  }
}
