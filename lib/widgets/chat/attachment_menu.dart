import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'chat_layout.dart';

Future<FileType?> showAttachmentMenu(
  BuildContext context, {
  bool includeAudio = false,
}) {
  return showModalBottomSheet<FileType>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      final colors = AppTheme.colorsOf(sheetContext);
      Widget option(String label, IconData icon, Color color, FileType type) {
        return SizedBox(
          width: 88,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filled(
                tooltip: label,
                style: IconButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: AppTheme.attachmentForeground,
                  fixedSize: const Size(64, 64),
                  shape: const CircleBorder(),
                ),
                onPressed: () => Navigator.pop(sheetContext, type),
                icon: Icon(icon, size: 30),
              ),
              const SizedBox(height: ChatLayout.space12),
              Text(
                label,
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }

      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Attach',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose what to share',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: ChatLayout.space24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: ChatLayout.space16,
                children: [
                  option(
                    'GIF',
                    Icons.gif_box_outlined,
                    AppTheme.photoAttachment,
                    FileType.custom,
                  ),
                  option(
                    'Photo',
                    Icons.photo_library_outlined,
                    AppTheme.photoAttachment,
                    FileType.image,
                  ),
                  option(
                    'Video',
                    Icons.videocam_outlined,
                    AppTheme.videoAttachment,
                    FileType.video,
                  ),
                  option(
                    'File',
                    Icons.insert_drive_file_outlined,
                    AppTheme.fileAttachment,
                    FileType.any,
                  ),
                  if (includeAudio)
                    option(
                      'Voice / audio',
                      Icons.mic_none_rounded,
                      AppTheme.videoAttachment,
                      FileType.audio,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Selected files will appear above the message field.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    },
  );
}
