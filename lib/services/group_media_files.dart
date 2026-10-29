import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/local_group.dart';

Future<Directory> _groupDirectory(String userId, String groupId) async {
  if (!RegExp(r'^local-group-[0-9]+$').hasMatch(groupId)) {
    throw const FormatException('Invalid group ID');
  }
  final root = await getApplicationDocumentsDirectory();
  final account = sha256.convert(utf8.encode(userId)).toString();
  return Directory('${root.path}/local_groups/$account/$groupId');
}

Future<GroupMedia> saveGroupMedia(
  String userId,
  String groupId,
  PlatformFile picked,
  GroupMediaKind kind,
) async {
  final directory = await _groupDirectory(userId, groupId);
  await directory.create(recursive: true);
  final extension = (picked.extension ?? 'bin').replaceAll(
    RegExp(r'[^a-zA-Z0-9]'),
    '',
  );
  final destination = File(
    '${directory.path}/${DateTime.now().microsecondsSinceEpoch}.$extension',
  );
  try {
    await picked
        .readAsByteStream()
        .map<List<int>>((chunk) => chunk)
        .pipe(destination.openWrite());
    return GroupMedia(
      name: picked.name,
      path: destination.path,
      size: await destination.length(),
      kind: kind,
    );
  } catch (_) {
    if (await destination.exists()) await destination.delete();
    rethrow;
  }
}

Future<void> removeGroupMedia(String userId, String groupId) async {
  final directory = await _groupDirectory(userId, groupId);
  if (await directory.exists()) await directory.delete(recursive: true);
}

Future<bool> exportGroupMedia(GroupMedia media) async {
  final bytes = await File(media.path).readAsBytes();
  return await FilePicker.saveFile(fileName: media.name, bytes: bytes) != null;
}
