import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:telegram_frontend/screens/chat_screen.dart';
import 'package:telegram_frontend/services/auth_api.dart';
import 'package:telegram_frontend/services/local_account_store.dart';
import 'package:telegram_frontend/services/local_database.dart';
import 'package:telegram_frontend/theme/app_theme.dart';
import 'package:telegram_frontend/widgets/account_data_scope.dart';
import 'package:telegram_frontend/widgets/chat/chat_composer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late LocalDatabase database;
  late LocalAccountStore data;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('telegram-chat-test-');
    sqfliteFfiInit();
    database = await LocalDatabase.open(
      path: '${directory.path}/app.sqlite',
      factory: databaseFactoryFfiNoIsolate,
    );
    data = LocalAccountStore(
      const AuthProfile('Admin', '+380991234567'),
      database: database,
    );
    await data.load();
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();
  }

  testWidgets(
    'Direct messages and unsent drafts restore after screen disposal',
    (tester) async {
      Widget app() => MaterialApp(
        theme: AppTheme.light,
        home: AccountDataScope(
          store: data,
          child: const ChatScreen(chatId: 'anna', chatName: 'Anna'),
        ),
      );
      await tester.pumpWidget(app());
      await drain(tester);
      expect(
        tester.widget<ChatComposer>(find.byType(ChatComposer)).pickingFiles,
        isFalse,
      );
      await tester.enterText(find.byType(TextField), 'Saved message');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await drain(tester);
      await tester.enterText(find.byType(TextField), 'Unsent draft');
      await drain(tester);
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
      await tester.pumpWidget(app());
      await drain(tester);
      expect(find.text('Saved message'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Unsent draft',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
    },
  );
}
