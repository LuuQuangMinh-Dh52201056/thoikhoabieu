import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thoi_khoa_bieu/main.dart';
import 'package:thoi_khoa_bieu/services/auth_service.dart';

void main() {
  testWidgets('signs in with local admin when Firebase is not configured', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const DrivingScheduleApp(firebaseConfigured: false),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Đăng nhập tài khoản nội bộ'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên đăng nhập'),
      AuthService.localAdminUsername,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu'),
      AuthService.localAdminPassword,
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Thời khóa biểu tuần'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}
