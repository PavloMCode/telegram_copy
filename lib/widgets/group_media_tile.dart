import 'dart:io';
import 'package:flutter/material.dart';
import '../models/local_group.dart';
import '../services/group_media_files.dart';
import '../services/stored_platform_file.dart';
import 'chat/gif_attachment.dart';

class GroupMediaTile extends StatelessWidget {
  const GroupMediaTile({super.key, required this.media, this.compact = false});
  final GroupMedia media;
  final bool compact;

  Future<void> _export(BuildContext context) async {
    try {
      final saved = await exportGroupMedia(media);
      if (!context.mounted || !saved) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('File saved.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this saved file.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (media.kind == GroupMediaKind.gif ||
        media.name.toLowerCase().endsWith('.gif')) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GifAttachment(
            file: StoredPlatformFile(media.name, media.path, media.size),
            sourceId: media.path,
          ),
          if (!compact)
            TextButton.icon(
              onPressed: () => _export(context),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Save GIF'),
            ),
        ],
      );
    }
    final tile = ListTile(
      contentPadding: EdgeInsets.zero,
      leading: media.kind == GroupMediaKind.photo
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(media.path),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined),
              ),
            )
          : Icon(switch (media.kind) {
              GroupMediaKind.video => Icons.videocam_outlined,
              GroupMediaKind.voice => Icons.mic_none_rounded,
              _ => Icons.insert_drive_file_outlined,
            }),
      title: Text(media.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${media.kind.name} · ${media.sizeLabel}'),
      trailing: IconButton(
        tooltip: 'Save file',
        icon: const Icon(Icons.download_outlined),
        onPressed: () => _export(context),
      ),
      onTap: media.kind == GroupMediaKind.photo
          ? () => showDialog<void>(
              context: context,
              builder: (dialogContext) => Dialog(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        tooltip: 'Close photo',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    Flexible(
                      child: InteractiveViewer(
                        child: Image.file(
                          File(media.path),
                          errorBuilder: (_, _, _) => const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Photo is unavailable.'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : () => _export(context),
    );
    if (!compact) return tile;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: tile.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              child: Icon(switch (media.kind) {
                GroupMediaKind.photo => Icons.image_outlined,
                GroupMediaKind.video => Icons.videocam_outlined,
                GroupMediaKind.voice => Icons.mic_none_rounded,
                GroupMediaKind.file => Icons.insert_drive_file_outlined,
                GroupMediaKind.gif => Icons.gif_box_outlined,
              }),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    '${media.sizeLabel} · Local attachment',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Save file',
              onPressed: () => _export(context),
              icon: const Icon(Icons.download_outlined, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
