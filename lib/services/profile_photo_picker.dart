import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/painting.dart';

/// Null means the picker was cancelled; failures are presented by the caller.
Future<Uint8List?> pickProfilePhoto() async {
  final photo = await FilePicker.pickFile(type: FileType.image);
  if (photo == null) return null;
  final bytes = await photo.readAsBytes();
  final image = await decodeImageFromList(bytes);
  image.dispose();
  return bytes;
}
