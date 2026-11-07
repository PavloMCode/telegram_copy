import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

Future<void> validateGif(PlatformFile file) async {
  final header = <int>[];
  await for (final chunk in file.readAsByteStream()) {
    header.addAll(chunk.take(6 - header.length));
    if (header.length == 6) break;
  }
  final signature = String.fromCharCodes(header);
  if (signature != 'GIF87a' && signature != 'GIF89a') {
    throw const FormatException('Choose a valid GIF file.');
  }
}

class GifAttachment extends StatefulWidget {
  const GifAttachment({super.key, required this.file, required this.sourceId});
  final PlatformFile file;
  final String sourceId;
  @override
  State<GifAttachment> createState() => _GifAttachmentState();
}

class _GifAttachmentState extends State<GifAttachment> {
  late Future<Uint8List> _bytes;
  @override
  void initState() {
    super.initState();
    _bytes = widget.file.readAsBytes();
  }

  @override
  void didUpdateWidget(GifAttachment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceId != widget.sourceId) {
      _bytes = widget.file.readAsBytes();
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 220,
            height: 180,
            child: FutureBuilder<Uint8List>(
              future: _bytes,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('GIF is unavailable.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Image.memory(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  semanticLabel: 'GIF: ${widget.file.name}',
                  errorBuilder: (_, _, _) =>
                      const Center(child: Text('Could not display GIF.')),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'GIF · ${widget.file.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
