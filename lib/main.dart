import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'core/routes/route_endpoint.dart';
import 'core/services/notification_service.dart';
import 'feature/auth/presentation/providers/auth_provider.dart';
import 'firebase_options.dart';

import '../core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  NotificationService().initialize();

  // try {
  //   // Initialize Stripe
  //   await StripeService.init();
  // } catch (e) {
  //   debugPrint("StripeService initialization failed: $e");
  // }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = ref.read(routerProvider);
    NotificationService().pendingOpen.addListener(_schedulePendingOpen);
    _router.routerDelegate.addListener(_schedulePendingOpen);
    _schedulePendingOpen();
  }

  @override
  void dispose() {
    NotificationService().pendingOpen.removeListener(_schedulePendingOpen);
    _router.routerDelegate.removeListener(_schedulePendingOpen);
    super.dispose();
  }

  void _schedulePendingOpen() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _openNotifications());
  }

  /// Opens the page for a tapped push, waiting until splash has finished.
  void _openNotifications() {
    final pendingOpen = NotificationService().pendingOpen;
    if (!mounted || !pendingOpen.value) return;

    final location = _router.routerDelegate.currentConfiguration.uri.path;
    if (location.isEmpty || location == RoutePaths.splash) return;

    pendingOpen.value = false;
    if (location != RoutePaths.notification &&
        ref.read(authProvider).isAuthenticated) {
      _router.push(RoutePaths.notification);
    }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SmileStreatsApp',
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
