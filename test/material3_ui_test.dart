import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telegram_frontend/main.dart';
import 'package:telegram_frontend/screens/chat_screen.dart';
import 'package:telegram_frontend/screens/home_screen.dart';
import 'package:telegram_frontend/services/auth_api.dart';
import 'package:telegram_frontend/services/local_auth_api.dart';
import 'package:telegram_frontend/services/local_group_store.dart';
import 'package:telegram_frontend/theme/app_theme.dart';
import 'package:telegram_frontend/widgets/settings_row.dart';
import 'package:telegram_frontend/widgets/account_data_scope.dart';

const profile = AuthProfile('Alex Morgan', '+441234567890');
const previewKey = ValueKey('material-preview');

void size(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> preview(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('UI_PREVIEWS')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(previewKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/material3-previews');
    await directory.create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    const RepaintBoundary(
      key: previewKey,
      child: TelegramApp(initialProfile: profile),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('UI_PREVIEWS')) return;
    final config = jsonDecode(
      File('.dart_tool/package_config.json').readAsStringSync(),
    );
    final root = Uri.parse(config['flutterRoot'] as String).toFilePath();
    for (final family in ['Roboto', 'MaterialIcons']) {
      final loader = FontLoader(family);
      for (final filename
          in family == 'Roboto'
              ? ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']
              : ['materialicons-regular.otf']) {
        loader.addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '$root/bin/cache/artifacts/material_fonts/$filename',
              ).readAsBytesSync(),
            ),
          ),
        );
      }
      await loader.load();
    }
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppTheme.selectedMode.value = ThemeMode.system;
  });

  testWidgets(
    'Chat filters separate channels, groups and unread conversations',
    (tester) async {
      size(tester, 390, 844);
      final groups = LocalGroupStore(profile);
      await groups.load();
      await groups.createChannel(name: 'Design updates', description: 'News');
      await groups.flush();
      addTearDown(groups.dispose);
      await pumpApp(tester);
      expect(find.byType(Badge), findsWidgets);
      await preview(tester, 'chats-light');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Unread'));
      await tester.pumpAndSettle();
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Maksym'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Groups'));
      await tester.pumpAndSettle();
      expect(find.text('Study Group'), findsOneWidget);
      expect(find.text('Anna'), findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(-180, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Channels'));
      await tester.pumpAndSettle();
      expect(find.text('Design updates'), findsOneWidget);
      expect(find.text('Study Group'), findsNothing);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(NavigationDrawerDestination, 'Settings'),
      );
      await tester.pumpAndSettle();
      await preview(tester, 'settings-light');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wide layout keeps list, selection and conversation together with Back',
    (tester) async {
      size(tester, 1280, 800);
      await pumpApp(tester);
      expect(find.byType(NavigationRail), findsOneWidget);
      await tester.tap(find.text('Anna'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        tester.widget<HomeScreen>(find.byType(HomeScreen)).selectedChatId,
        'anna',
      );
      expect(tester.widget<ChatScreen>(find.byType(ChatScreen)).chatId, 'anna');
      await tester.enterText(
        find.byType(TextField),
        'The refreshed Material 3 workspace',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      await preview(tester, 'workspace-light');
      await tester.tap(find.text('Maksym'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChatScreen>(find.byType(ChatScreen)).chatId,
        'maksym',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Select a conversation'), findsOneWidget);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(NavigationDrawerDestination, 'Saved Messages'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Settings rows grow with large text on narrow screens', (
    tester,
  ) async {
    size(tester, 320, 800);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(NavigationDrawerDestination, 'Settings'),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(SettingsRow).first).height,
      greaterThan(72),
    );
    await preview(tester, 'settings-large-text');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dark surfaces keep the chat and drawer readable', (
    tester,
  ) async {
    size(tester, 390, 844);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester);
    await preview(tester, 'chats-dark');
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await preview(tester, 'drawer-dark');
    expect(
      tester
          .widget<NavigationDrawer>(find.byType(NavigationDrawer))
          .selectedIndex,
      0,
    );
    await tester.tap(
      find.widgetWithText(NavigationDrawerDestination, 'Settings'),
    );
    await tester.pumpAndSettle();
    await preview(tester, 'settings-dark');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chat header and message metadata fit double text scaling', (
    tester,
  ) async {
    size(tester, 320, 800);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const ChatScreen(chatId: 'anna', chatName: 'Anna'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(TextField)).width, greaterThan(250));
    await tester.enterText(find.byType(TextField), 'A readable message');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    await preview(tester, 'chat-large-text');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reversible pin action offers Undo without changing messages', (
    tester,
  ) async {
    size(tester, 390, 844);
    await pumpApp(tester);
    final data = AccountDataScope.maybeOf(
      tester.element(find.byType(HomeScreen)),
    )!;
    expect(data.isChatPinned('anna'), isFalse);
    await tester.longPress(find.text('Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin chat'));
    await tester.pumpAndSettle();
    expect(data.isChatPinned('anna'), isTrue);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(data.isChatPinned('anna'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login fields keep their values while gradient themes change', (
    tester,
  ) async {
    size(tester, 390, 844);
    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: TelegramApp(authApi: LocalAuthApi()),
      ),
    );
    await tester.pumpAndSettle();
    final signIn = find.text('Already have an account? Sign in');
    await tester.scrollUntilVisible(
      signIn,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(signIn);
    await tester.pumpAndSettle();
    expect(find.text(LocalAuthApi.testAdminEmail), findsOneWidget);
    await preview(tester, 'login-light');
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpAndSettle();
    expect(find.text(LocalAuthApi.testAdminEmail), findsOneWidget);
    await preview(tester, 'login-dark');
    expect(tester.takeException(), isNull);
  });
}
