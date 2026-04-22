import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thoi_khoa_bieu/main.dart';

void main() {
  testWidgets('renders local schedule screen when Firebase is not configured', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const DrivingScheduleApp(firebaseConfigured: false),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Thời khóa biểu tuần'), findsOneWidget);
    expect(find.text('Chưa có lịch cho ngày này'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}
