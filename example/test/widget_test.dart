import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/app.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';
import 'package:example/shared/widgets/state_card.dart';

void main() {
  testWidgets('App renders Home Page with all cards', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const App());

    expect(find.text('flutter_ble_connection_manager'), findsOneWidget);
    expect(find.text('Quick Start'), findsOneWidget);
    expect(find.text('Lifecycle Walkthrough'), findsOneWidget);

    // API Reference is at the bottom of the list, might be off-screen. Scroll to reveal it.
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('API Reference'), findsOneWidget);
  });

  testWidgets('StateCard renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StateCard(state: BleConnectionState.disconnected)),
      ),
    );

    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.byIcon(Icons.bluetooth_disabled), findsOneWidget);
  });
}
