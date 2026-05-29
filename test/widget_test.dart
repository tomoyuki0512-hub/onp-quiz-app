import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_deleter/main.dart';

void main() {
  const channel = MethodChannel('com.example.photo_deleter/burst');

  setUp(() {
    // プラットフォームチャンネルをモックして、テスト中に
    // MissingPluginException が出ないようにする。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'requestPermission':
          return 'denied';
        case 'getBurstGroups':
          return <Object?>[];
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('アクセス拒否時は許可を促す画面を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(const PhotoDeleterApp());
    await tester.pumpAndSettle();

    expect(find.text('フォトライブラリへのアクセスが必要です'), findsOneWidget);
  });
}
