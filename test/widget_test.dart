import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:worktrack_mobile/app.dart';

void main() {
  testWidgets('app lands on welcome screen when signed out', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WorkTrackApp()));
    await tester.pumpAndSettle();

    expect(find.text('WorkTrack'), findsWidgets);
    expect(find.text('Sign in with Microsoft'), findsOneWidget);
  });
}
