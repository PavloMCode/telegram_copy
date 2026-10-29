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
    'External forward refreshes an open chat without losing its draft or history',
    (tester) async {
      await tester.runAsync(
        () => data.saveConversation('anna', 'Anna', [
          {
            'id': 'old',
            'text': 'Old history',
            'time': '2026-10-29T10:00:00',
            'files': [],
          },
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AccountDataScope(
            store: data,
            child: const ChatScreen(chatId: 'anna', chatName: 'Anna'),
          ),
        ),
      );
      await drain(tester);
      await tester.enterText(find.byType(TextField), 'Keep my draft');
      await drain(tester);
      await tester.runAsync(
        () => data.appendForwardedMessage('anna', 'Anna', {
          'id': 'forward',
          'text': 'Incoming forward',
          'time': '2026-10-29T11:00:00',
          'forwarded': 'Team',
          'files': [],
        }),
      );
      await drain(tester);
      expect(find.text('Incoming forward'), findsOneWidget);
      expect(find.text('Old history'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Keep my draft',
      );
      await tester.tap(find.byTooltip('Send message'));
      await drain(tester);
      expect(
        (await tester.runAsync(
          () => data.messages('anna'),
        ))!.map((m) => m['text']),
        ['Keep my draft', 'Incoming forward', 'Old history'],
      );
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
      expect(tester.takeException(), isNull);
    },
  );

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
