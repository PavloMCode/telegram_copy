import 'dart:io';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';

final class StoredPlatformFile extends PlatformFile {
  StoredPlatformFile(this.name, this.localPath, this.size);
  @override
  final String name;
  final String localPath;
  final int? size;
  @override
  Uri get uri => Uri.file(localPath);
  @override
  XFile get xFile => XFile(localPath, name: name);
  @override
  int? lengthSync() => size;
  @override
  Future<int?> length() => File(localPath).length();
  @override
  Future<Uint8List> readAsBytes() => File(localPath).readAsBytes();
  @override
  Stream<Uint8List> readAsByteStream() =>
      File(localPath).openRead().map(Uint8List.fromList);
}
