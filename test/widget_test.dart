import 'package:flutter_test/flutter_test.dart';
import 'package:photo_deleter/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PhotoDeleterApp());
    expect(find.text('バースト写真クリーナー'), findsOneWidget);
  });
}
