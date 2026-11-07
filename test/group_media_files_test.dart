import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:telegram_frontend/models/local_group.dart';
import 'package:telegram_frontend/services/group_media_files.dart';
import 'package:telegram_frontend/services/stored_platform_file.dart';
import 'package:telegram_frontend/widgets/chat/gif_attachment.dart';

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
    'Animated GIF copy and serialized metadata preserve all frames offline',
    () async {
      final single = base64Decode(
        'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
      );
      final animated = Uint8List.fromList([
        ...single.take(single.length - 1),
        ...single.skip(19),
      ]);
      final source = File('${temporary.path}/source.gif');
      await source.writeAsBytes(animated);
      final picked = StoredPlatformFile(
        'animation.GIF',
        source.path,
        animated.length,
      );
      await validateGif(picked);
      final saved = await saveGroupMedia(
        'admin',
        'anna',
        picked,
        GroupMediaKind.gif,
      );
      final restored = GroupMedia.fromJson(
        jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>,
      );
      await source.delete();
      expect(restored.kind, GroupMediaKind.gif);
      final bytes = await File(restored.path).readAsBytes();
      expect(bytes, animated);
      final codec = await ui.instantiateImageCodec(bytes);
      expect(codec.frameCount, 2);
      final first = await codec.getNextFrame();
      final second = await codec.getNextFrame();
      first.image.dispose();
      second.image.dispose();
      codec.dispose();
      await expectLater(
        validateGif(_MemoryFile('fake.gif', Uint8List.fromList([1, 2, 3]))),
        throwsFormatException,
      );
    },
  );

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
