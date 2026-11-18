import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart' show buildAppTheme, AppColors;
import 'features/auth/auth_controller.dart';
import 'features/auth/screens/membership_screen.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/proto/screens/auth_onboarding.dart';
import 'features/proto/screens/workspace.dart';

/// App router — driven by the real auth state machine:
/// restoring → signedOut (welcome or self-service onboarding) →
/// selectingRole → ready (live workspace hydrated from the API).
class WorkTrackApp extends ConsumerStatefulWidget {
  const WorkTrackApp({super.key});

  @override
  ConsumerState<WorkTrackApp> createState() => _WorkTrackAppState();
}

class _WorkTrackAppState extends ConsumerState<WorkTrackApp> {
  @override
  void initState() {
    super.initState();
    // Silent session restore (MSAL cached account → token → memberships).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final Widget home = KeyedSubtree(
      key: ValueKey(auth.phase),
      child: switch (auth.phase) {
        AuthPhase.restoring => const _RestoreScreen(),
        AuthPhase.signedOut =>
          // No memberships + accessState 'none' → self-service onboarding.
          auth.session != null && auth.session!.accessState == 'none' && auth.session!.memberships.isEmpty
              ? const LiveOnboardingScreen()
              : const ProtoWelcomeScreen(),
        AuthPhase.selectingRole => const MembershipScreen(),
        AuthPhase.ready => const ProtoShell(),
      },
    );
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    // Mobile-first: cap the app at phone width and centre it on desktop.
    return MaterialApp(
      title: 'WorkTrack',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: ColoredBox(
        color: const Color(0xFFE9E9EF),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ColoredBox(
              color: AppColors.surface,
              child: AnimatedSwitcher(
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
                      .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: home,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RestoreScreen extends StatelessWidget {
  const _RestoreScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, size: 44, color: AppColors.primary),
            SizedBox(height: 16),
            Text('WorkTrack', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            SizedBox(height: 24),
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
