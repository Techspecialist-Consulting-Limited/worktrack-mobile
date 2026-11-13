import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:worktrack_mobile/app.dart';

void main() {
  testWidgets('unconfigured build lands on welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WorkTrackApp()));
    await tester.pumpAndSettle();

    // Without --dart-define Entra config the app must fail safe to welcome,
    // never crash or expose a signed-in state.
    expect(find.text('WorkTrack'), findsWidgets);
    expect(find.text('Continue with Microsoft'), findsOneWidget);
  });
}
