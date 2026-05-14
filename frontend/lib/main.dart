import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_navigator.dart';
import 'fcm_background.dart';
import 'services/api_config.dart';
import 'services/firebase_bootstrap.dart';
import 'services/notification_navigation.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/client_dashboard.dart';
import 'screens/mecanicien_dashboard.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/help_screen.dart';
import 'screens/intervention_chat_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  await ApiConfig.load();
  await FirebaseBootstrap.init();
  runApp(const MechAssistApp());
}

class MechAssistApp extends StatefulWidget {
  const MechAssistApp({super.key});

  @override
  State<MechAssistApp> createState() => _MechAssistAppState();
}

class _MechAssistAppState extends State<MechAssistApp> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      FirebaseMessaging.instance.getInitialMessage().then((m) {
        if (m == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationNavigation.handleRemoteMessage(m);
        });
      });
      FirebaseMessaging.onMessageOpenedApp.listen(NotificationNavigation.handleRemoteMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'MechAssist',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F4C75),
          primary: const Color(0xFF0F4C75),
          secondary: const Color(0xFFE67E22),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF0F4C75);
            }
            return null;
          }),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F6FA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: const BorderSide(color: Color(0xFF0F4C75), width: 1.8),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F4C75),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/reset-password': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          String? email;
          if (args is Map) {
            email = args['email']?.toString();
          }
          return ResetPasswordScreen(initialEmail: email);
        },
        '/help': (context) => const HelpScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/client': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          var tab = 0;
          if (args is Map) {
            final t = args['tab'];
            if (t is int) {
              tab = t;
            }
          }
          return DashboardClient(initialTabIndex: tab);
        },
        '/mecanicien': (context) => const DashboardMecanicien(),
        '/intervention-chat': (context) {
          final raw = ModalRoute.of(context)?.settings.arguments;
          final id = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
          if (id == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Chat')),
              body: const Center(child: Text('Demande introuvable.')),
            );
          }
          return InterventionChatScreen(requestId: id);
        },
      },
    );
  }
}
