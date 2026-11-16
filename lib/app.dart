import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/proto/models.dart';
import 'features/proto/proto_store.dart';
import 'features/proto/screens/auth_onboarding.dart';
import 'features/proto/screens/workspace.dart';

/// Prototype shell — routes on the local ProtoStore phase. Real auth/API
/// wiring replaces this mapping later; screens stay unchanged.
class WorkTrackApp extends ConsumerWidget {
  const WorkTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(protoStoreProvider.select((s) => s.phase));
    final Widget home = switch (phase) {
      ProtoPhase.welcome => const ProtoWelcomeScreen(),
      ProtoPhase.onboarding => const ProtoOnboardingScreen(),
      ProtoPhase.home => const ProtoShell(),
    };
    return MaterialApp(
      title: 'WorkTrack',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: home,
    );
  }
}
