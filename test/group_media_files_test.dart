import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:telegram_frontend/models/local_group.dart';
import 'package:telegram_frontend/services/group_media_files.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.directory);
  final String directory;
  @override
  Future<String> getApplicationDocumentsPath() async => directory;
}

final class _MemoryFile extends PlatformFile {
  _MemoryFile(this.name, this.bytes);
  @override
  final String name;
  final Uint8List bytes;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late PathProviderPlatform original;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('telegram-group-media-');
    original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(temporary.path);
  });
  tearDown(() async {
    PathProviderPlatform.instance = original;
    await temporary.delete(recursive: true);
  });

  test(
    'Photo, video and audio bytes are copied and deleting one group preserves others',
    () async {
      final saved = <GroupMedia>[];
      for (final (kind, name) in [
        (GroupMediaKind.photo, 'photo.png'),
        (GroupMediaKind.video, 'video.mp4'),
        (GroupMediaKind.voice, 'voice.m4a'),
      ]) {
        final bytes = Uint8List.fromList([1, 2, 3, kind.index]);
        final media = await saveGroupMedia(
          'admin',
          'local-group-123',
          _MemoryFile(name, bytes),
          kind,
        );
        saved.add(media);
        expect(await File(media.path).readAsBytes(), bytes);
        expect(media.size, bytes.length);
        expect(media.kind, kind);
      }
      final other = await saveGroupMedia(
        'admin',
        'local-group-456',
        _MemoryFile('notes.txt', Uint8List.fromList([5])),
        GroupMediaKind.file,
      );
      await removeGroupMedia('admin', 'local-group-123');
      for (final media in saved) {
        expect(await File(media.path).exists(), isFalse);
      }
      expect(await File(other.path).exists(), isTrue);
      await expectLater(
        removeGroupMedia('admin', '../other'),
        throwsFormatException,
      );
      expect(await File(other.path).exists(), isTrue);
    },
  );
}
