import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_navigator.dart';
import 'fcm_background.dart';
import 'services/api_config.dart';
import 'services/api_service.dart';
import 'services/api_data_cache.dart';
import 'services/api_keep_alive.dart';
import 'services/client_config_cache.dart';
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
import 'screens/intervention_chat_screen.dart';
import 'screens/profile_screen.dart';
import 'theme/app_fonts.dart';
import 'theme/app_theme.dart';
import 'widgets/responsive_web_frame.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  await AppFonts.ensureLoaded();
  await ApiConfig.load();
  await ApiConfig.ensureProductionDefault();
  await ApiDataCache.preload();
  // PERF: Keep-alive sans ping périodique — warm au splash / login / reprise app.
  ApiKeepAlive.instance.start();
  unawaited(ApiService.warmServer(wait: false));
  unawaited(ClientConfigCache.get());
  // Android : Firebase AVANT runApp (sinon crash [core/no-app] au démarrage).
  if (!kIsWeb) {
    await FirebaseBootstrap.init();
  }
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
    if (!kIsWeb && FirebaseBootstrap.initialized) {
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
      theme: AppTheme.light(),
      builder: (context, child) {
        final scaled = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15),
          ),
          child: child ?? const SizedBox.shrink(),
        );
        return ResponsiveWebFrame(child: scaled);
      },
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
        '/profile': (context) => const ProfileScreen(),
        '/client': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          var tab = 0;
          if (args is Map) {
            final t = args['tab'];
            if (t is int) {
              tab = t.clamp(0, 3);
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
