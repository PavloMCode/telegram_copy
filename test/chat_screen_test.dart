import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_frontend/screens/chat_screen.dart';
import 'package:telegram_frontend/theme/app_theme.dart';

class _Picker extends FilePickerPlatform {
  List<PlatformFile> files = [];
  bool fail = false;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (fail) throw Exception('Picker unavailable');
    return files;
  }
}

final class _TestFile extends PlatformFile {
  _TestFile(this.name);
  @override
  final String name;
  @override
  int? lengthSync() => 2048;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Picker picker;
  late FilePickerPlatform original;

  setUp(() {
    original = FilePickerPlatform.instance;
    picker = _Picker();
    FilePickerPlatform.instance = picker;
  });
  tearDown(() => FilePickerPlatform.instance = original);

  Future<void> openChat(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: AppTheme.mode,
        home: const ChatScreen(chatId: 'anna', chatName: 'Anna'),
      ),
    );
  }

  Future<void> attachFiles(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Attach files'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('File'));
    await tester.pumpAndSettle();
  }

  testWidgets('Reaction can be added, replaced and removed', (tester) async {
    await openChat(tester);
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Hello'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('👍'));
    await tester.pumpAndSettle();
    expect(find.text('👍 1'), findsOneWidget);
    await tester.longPress(find.text('Hello'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('❤️'));
    await tester.pumpAndSettle();
    expect(find.text('👍 1'), findsNothing);
    expect(find.text('❤️ 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove reaction'));
    await tester.pumpAndSettle();
    expect(find.text('❤️ 1'), findsNothing);
  });

  testWidgets('Files can be removed from draft and sent without text', (
    tester,
  ) async {
    picker.files = [_TestFile('notes.pdf'), _TestFile('photo.png')];
    await openChat(tester);
    await attachFiles(tester);
    expect(find.byType(InputChip), findsNWidgets(2));
    final chip = tester.widget<InputChip>(find.byType(InputChip).first);
    chip.onDeleted!();
    await tester.pumpAndSettle();
    expect(find.text('notes.pdf'), findsNothing);
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsNothing);
    expect(find.text('photo.png'), findsOneWidget);
    expect(find.text('2.0 KB · Local attachment'), findsOneWidget);
    await tester.longPress(find.text('photo.png'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete message'));
    await tester.pumpAndSettle();
    expect(find.text('photo.png'), findsNothing);
  });

  testWidgets('Picker cancellation and failure preserve draft', (tester) async {
    await openChat(tester);
    await tester.enterText(find.byType(TextField), 'My caption');
    await attachFiles(tester);
    expect(find.byType(InputChip), findsNothing);
    expect(find.text('My caption'), findsOneWidget);
    picker.fail = true;
    await attachFiles(tester);
    expect(
      find.text('Could not attach files. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('My caption'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.attach_file),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Caption and long file name fit a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    picker.files = [
      _TestFile('a_very_long_filename_for_our_project_documentation.pdf'),
    ];
    await openChat(tester);
    await attachFiles(tester);
    await tester.enterText(find.byType(TextField), 'Project files');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('Project files'), findsOneWidget);
    expect(
      find.text('a_very_long_filename_for_our_project_documentation.pdf'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
