import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/screens/diagnostics_screen.dart';
import 'features/auth/screens/home_screen.dart';
import 'features/auth/screens/membership_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/welcome_screen.dart';

class WorkTrackApp extends ConsumerStatefulWidget {
  const WorkTrackApp({super.key});

  @override
  ConsumerState<WorkTrackApp> createState() => _WorkTrackAppState();
}

class _WorkTrackAppState extends ConsumerState<WorkTrackApp> {
  final _refresh = ValueNotifier<int>(0);
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/',
      refreshListenable: _refresh,
      redirect: (context, state) {
        final auth = ref.read(authControllerProvider);
        final loc = state.matchedLocation;
        switch (auth.phase) {
          case AuthPhase.restoring:
            return loc == '/' ? null : '/';
          case AuthPhase.signedOut:
            return loc == '/welcome' ? null : '/welcome';
          case AuthPhase.selectingRole:
            return loc == '/select-role' ? null : '/select-role';
          case AuthPhase.ready:
            return (loc == '/home' || loc == '/diagnostics') ? null : '/home';
        }
      },
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
        GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
        GoRoute(path: '/select-role', builder: (_, _) => const MembershipScreen()),
        GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/diagnostics', builder: (_, _) => const DiagnosticsScreen()),
      ],
    );
    ref.listenManual(authControllerProvider, (_, _) => _refresh.value++);
  }

  @override
  void dispose() {
    _refresh.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WorkTrack',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}
