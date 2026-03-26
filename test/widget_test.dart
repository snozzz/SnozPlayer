import 'package:flutter_test/flutter_test.dart';

import 'package:snoz_player/app/app.dart';

void main() {
  testWidgets('shows SnozPlayer shell', (tester) async {
    await tester.pumpWidget(const SnozPlayerApp());

    expect(find.text('SnozPlayer'), findsOneWidget);
    expect(find.text('Hold for 3x'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
  });
}
