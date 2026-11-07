import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_frontend/screens/settings_screen_account.dart';
import 'package:telegram_frontend/theme/app_theme.dart';

class _PhotoPicker extends FilePickerPlatform {
  PlatformFile? photo;
  bool fail = false;
  FileType? requestedType;
  int calls = 0;

  @override
  Future<PlatformFile?> pickFile({
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
    calls++;
    requestedType = type;
    if (fail) throw Exception('Picker unavailable');
    return photo;
  }
}

final class _Photo extends PlatformFile {
  _Photo(this.bytes);
  final Uint8List bytes;

  @override
  String get name => 'avatar.png';

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FilePickerPlatform original;
  late _PhotoPicker picker;
  final photoBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAABmJLR0QA/wD/AP+gvaeT'
    'AAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH5gMQFwcdLl4wmwAAAAtJREFUCNdj'
    'YAACAAAFAAHiJgWbAAAAAElFTkSuQmCC',
  );

  setUp(() {
    original = FilePickerPlatform.instance;
    picker = _PhotoPicker();
    FilePickerPlatform.instance = picker;
  });
  tearDown(() => FilePickerPlatform.instance = original);

  Future<void> openAccount(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        home: const SettingsScreenAccount(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choosePhoto(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Change profile photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Photo'));
    // Decoding uses the image engine, so allow its real asynchronous work.
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 200; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
      }
      throw TimeoutException('Photo selection did not finish');
    });
    await tester.pumpAndSettle();
  }

  CircleAvatar avatar(WidgetTester tester) =>
      tester.widget<CircleAvatar>(find.byType(CircleAvatar));

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('Photo menu contains only photos in $mode', (tester) async {
      await openAccount(tester, mode: mode);
      await tester.tap(find.byTooltip('Change profile photo'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Photo'), findsOneWidget);
      expect(find.text('Video'), findsNothing);
      expect(find.text('File'), findsNothing);
      expect(
        AppTheme.colorsOf(tester.element(find.text('Photo'))).brightness,
        mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
      );
      Navigator.of(tester.element(find.text('Photo'))).pop();
      await tester.pumpAndSettle();
      expect(picker.calls, 0);
      expect(avatar(tester).foregroundImage, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Selected photo appears on the avatar and cancellation keeps it',
    (tester) async {
      picker.photo = _Photo(photoBytes);
      await openAccount(tester);
      await choosePhoto(tester);
      expect(picker.requestedType, FileType.image);
      expect(find.byType(BottomSheet), findsNothing);
      final image = avatar(tester).foregroundImage;
      expect(image, isA<MemoryImage>());
      expect((image! as MemoryImage).bytes, photoBytes);
      expect(find.byIcon(Icons.person_outline_rounded), findsNothing);

      picker.photo = null;
      await choosePhoto(tester);
      expect(avatar(tester).foregroundImage, image);
      expect(
        find.text('Could not open photo. Please try again.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Picker failure and invalid image preserve the selected avatar', (
    tester,
  ) async {
    picker.photo = _Photo(photoBytes);
    await openAccount(tester);
    await choosePhoto(tester);
    final image = avatar(tester).foregroundImage;
    expect(image, isA<MemoryImage>());

    picker.fail = true;
    await choosePhoto(tester);
    expect(avatar(tester).foregroundImage, image);
    expect(
      find.text('Could not open photo. Please try again.'),
      findsOneWidget,
    );

    picker.fail = false;
    picker.photo = _Photo(Uint8List.fromList([1, 2, 3]));
    await choosePhoto(tester);
    expect(avatar(tester).foregroundImage, image);
    expect(tester.takeException(), isNull);
  });
}
