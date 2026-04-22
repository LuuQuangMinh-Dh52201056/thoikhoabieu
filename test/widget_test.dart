import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thoi_khoa_bieu/main.dart';

void main() {
  testWidgets('renders Firebase setup screen when not configured', (
    tester,
  ) async {
    await tester.pumpWidget(
      const DrivingScheduleApp(firebaseConfigured: false),
    );
    await tester.pump();

    expect(find.text('Cần cấu hình Firebase'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
  });
}
