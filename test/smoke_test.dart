import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chessyar/app.dart';
import 'package:chessyar/state/app_settings.dart';

/// Builds the real app shell (RTL sidebar + analysis screen + chessboard +
/// engine panel) so that CI catches rendering regressions, not just analyzer
/// issues.
void main() {
  Future<void> bootApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await appSettings.load();
    await tester.pumpWidget(const ChessYarApp());
    await tester.pumpAndSettle();
  }

  testWidgets('shell renders with analysis screen and engine panel', (tester) async {
    await bootApp(tester);

    // Analysis screen pieces. On a dev machine without bundled engines the
    // panel shows the honest empty-state instead of the start button.
    expect(find.text('موتور تحلیل'), findsOneWidget);
    expect(find.text('حرکت‌ها'), findsOneWidget);
    expect(find.text('بازی جدید'), findsOneWidget);
    expect(find.text('کپی FEN'), findsOneWidget);
    final enginesAvailable = find.text('شروع تحلیل').evaluate().isNotEmpty;
    if (!enginesAvailable) {
      expect(find.text('افزودن موتور در تنظیمات'), findsOneWidget);
    }

    // Sidebar: first items are built inside the viewport.
    expect(find.text('تحلیل بازی'), findsWidgets);
    expect(find.text('بازی‌های من'), findsOneWidget);
  });

  testWidgets('settings screen lists engine section', (tester) async {
    await bootApp(tester);

    // The sidebar ListView is lazy: scroll to reveal the Settings item.
    await tester.fling(find.byType(ListView).first, const Offset(0, -400), 2000);
    await tester.pumpAndSettle();

    await tester.tap(find.text('تنظیمات').last);
    await tester.pumpAndSettle();

    expect(find.text('موتورهای شطرنج (UCI)'), findsOneWidget);
    expect(find.text('افزودن موتور سفارشی'), findsOneWidget);
    expect(find.text('تم تخته'), findsOneWidget);
    expect(find.text('صدای حرکت مهره‌ها'), findsOneWidget);
  });
}
