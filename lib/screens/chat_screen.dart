import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';

abstract final class _ChatLayout {
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space24 = 24.0;

  static const appBarHeight = 64.0;
  static const avatarSize = 36.0;
  static const nameFontSize = 16.0;
  static const statusFontSize = 11.0;
  static const bubbleWidthFraction = 0.72;
  static const bubbleRadius = 16.0;
  static const bubbleTailCornerRadius = 6.0;
  static const tailWidth = 10.0;
  static const tailHeight = 8.0;
  static const messageFontSize = 14.0;
  static const timeFontSize = 10.0;
  static const bubbleGap = 6.0;
  static const dateHeight = 24.0;
  static const dateHorizontalPadding = 10.0;
  static const dateRadius = 12.0;
  static const dateFontSize = 10.0;
  static const minComposerHeight = 64.0;
  static const minInputHeight = 48.0;
  static const maxInputLines = 6;
  static const inputRadius = 24.0;
  static const iconSize = 22.0;
  static const sendButtonSize = 44.0;
  static const sendButtonRadius = 22.0;
}

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final _Message? _forwardDraft;

  const ChatScreen({super.key, required this.chatId, required this.chatName})
    : _forwardDraft = null;

  const ChatScreen._forward({
    required this.chatId,
    required this.chatName,
    required _Message message,
  }) : _forwardDraft = message;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Message> _messages = [];
  final List<_Attachment> _pendingFiles = [];
  bool _pickingFiles = false;
  bool _blocked = false;
  bool _showEmoji = false;
  String? _replyPreview;
  String? _forwardedFrom;
  _Message? _pendingForward;

  @override
  void initState() {
    super.initState();
    final draft = widget._forwardDraft;
    if (draft != null) {
      _pendingForward = draft;
      _forwardedFrom = draft.forwardedFrom;
    }
  }

  String _preview(_Message message) => message.text.isNotEmpty
      ? message.text
      : message.files.map((file) => file.file.name).join(', ');

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if ((text.isEmpty && _pendingFiles.isEmpty && _pendingForward == null) ||
        _blocked ||
        _pickingFiles) {
      return;
    }
    setState(() {
      final forward = _pendingForward;
      if (forward != null) {
        _messages.insert(
          0,
          _Message(
            forward.text,
            DateTime.now(),
            files: List.of(forward.files),
            forwardedFrom: forward.forwardedFrom,
          ),
        );
      }
      if (text.isNotEmpty || _pendingFiles.isNotEmpty) {
        _messages.insert(
          0,
          _Message(
            text,
            DateTime.now(),
            files: List.of(_pendingFiles),
            replyPreview: _replyPreview,
          ),
        );
      }
      _pendingFiles.clear();
      _messageController.clear();
      _replyPreview = null;
      _forwardedFrom = null;
      _pendingForward = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showAttachmentMenu(BuildContext context) async {
    if (_pickingFiles || _blocked) return;
    FocusScope.of(context).unfocus();
    setState(() => _showEmoji = false);
    final type = await showModalBottomSheet<FileType>(
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
                const SizedBox(height: _ChatLayout.space12),
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
                const SizedBox(height: _ChatLayout.space24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: _ChatLayout.space16,
                  children: [
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
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Selected files will appear above the message field.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || type == null || _blocked) return;
    await _pickFiles(type: type);
  }

  Future<void> _pickFiles({FileType type = FileType.any}) async {
    if (_pickingFiles || _blocked) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _pickingFiles = true;
      _showEmoji = false;
    });
    try {
      final files = await FilePicker.pickFiles(type: type);
      final attachments = <_Attachment>[];
      for (final file in files) {
        final size = file.lengthSync() ?? await file.length();
        attachments.add(_Attachment(file, size));
      }
      if (!mounted || _blocked) return;
      setState(() => _pendingFiles.addAll(attachments));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not attach files. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingFiles = false);
    }
  }

  void _toggleReaction(_Message message, String emoji) {
    if (!_messages.contains(message)) return;
    setState(() => message.reaction = message.reaction == emoji ? null : emoji);
  }

  Future<void> _showMessageActions(
    BuildContext context,
    _Message message,
    Offset position,
  ) async {
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final localPosition = overlay.globalToLocal(position);
    final colors = AppTheme.colorsOf(context);
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(localPosition.dx, localPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: colors.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (final emoji in ['👍', '❤️', '😂', '🔥', '🎉', '👎'])
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.all(_ChatLayout.space8),
                    backgroundColor: message.reaction == emoji
                        ? colors.primaryContainer
                        : null,
                    shape: const CircleBorder(),
                  ),
                  onPressed: () => Navigator.pop(context, emoji),
                  child: Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (!_blocked && message.isOwn && message.forwardedFrom == null)
          const PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 21),
                SizedBox(width: 12),
                Expanded(child: Text('Edit message')),
              ],
            ),
          ),
        if (!_blocked)
          const PopupMenuItem<String>(
            value: 'reply',
            child: Row(
              children: [
                Icon(Icons.reply_rounded, size: 21),
                SizedBox(width: 12),
                Expanded(child: Text('Reply')),
              ],
            ),
          ),
        const PopupMenuItem<String>(
          value: 'forward',
          child: Row(
            children: [
              Icon(Icons.forward_rounded, size: 21),
              SizedBox(width: 12),
              Expanded(child: Text('Forward')),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy_outlined, size: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message.text.isEmpty ? 'Copy file names' : 'Copy message',
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: colors.error, size: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delete message',
                  style: TextStyle(color: colors.error),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (!mounted || action == null || !_messages.contains(message)) return;
    if (action == 'copy') {
      await Clipboard.setData(
        ClipboardData(
          text: message.text.isEmpty
              ? message.files.map((file) => file.file.name).join('\n')
              : message.text,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
      );
    } else if (action == 'edit') {
      if (!context.mounted) return;
      await _editMessage(context, message);
    } else if (action == 'reply') {
      setState(() => _replyPreview = _preview(message));
    } else if (action == 'forward') {
      if (!context.mounted) return;
      await _forwardMessage(context, message);
    } else if (action == 'delete') {
      setState(() => _messages.remove(message));
    } else {
      _toggleReaction(message, action);
    }
  }

  Future<void> _editMessage(BuildContext context, _Message message) async {
    var draft = message.text;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AlertDialog(
          title: const Text('Edit message'),
          content: SizedBox(
            width: 400,
            child: TextFormField(
              initialValue: message.text,
              autofocus: true,
              minLines: 1,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Message'),
              onChanged: (value) => updateDialog(() => draft = value),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: draft.trim().isEmpty && message.files.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, draft.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (!mounted ||
        result == null ||
        result == message.text ||
        !_messages.contains(message) ||
        _blocked)
      return;
    setState(() {
      message.text = result;
      message.edited = true;
    });
  }

  Future<void> _forwardMessage(BuildContext context, _Message message) async {
    // Demo destinations mirror the local conversations on HomeScreen.
    const chats = <String, String>{
      'saved': 'Saved Messages',
      'study': 'Study Group',
      'anna': 'Anna',
      'maksym': 'Maksym',
      'flutter': 'Flutter Community',
      'olena': 'Olena',
      'project': 'Messenger Project',
      'andrii': 'Andrii',
    };
    final target = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Forward to…',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              for (final chat in chats.entries)
                if (chat.key != widget.chatId)
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(chat.value),
                    onTap: () => Navigator.pop(sheetContext, chat.key),
                  ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || !context.mounted || target == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen._forward(
          chatId: target,
          chatName: chats[target]!,
          message: _Message(
            message.text,
            DateTime.now(),
            files: List.of(message.files),
            forwardedFrom: message.forwardedFrom ?? widget.chatName,
          ),
        ),
      ),
    );
  }

  Widget _attachmentCard(BuildContext context, _Attachment attachment) {
    final colors = AppTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: _ChatLayout.space8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            child: const Icon(Icons.insert_drive_file_outlined),
          ),
          const SizedBox(width: _ChatLayout.space12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  '${attachment.sizeLabel} · Local attachment',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAction(
    BuildContext context, {
    required bool block,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(block ? 'Block user?' : 'Clear history?'),
        content: Text(
          block
              ? 'Sending messages will be disabled for this session. You can unblock the user at any time.'
              : 'All messages in this local session will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              block ? 'Block' : 'Clear',
              style: TextStyle(color: AppTheme.colorsOf(context).error),
            ),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      if (block) {
        _blocked = true;
        _showEmoji = false;
        FocusScope.of(context).unfocus();
      } else {
        _messages.clear();
      }
    });
  }

  void _insertEmoji(String emoji) {
    final value = _messageController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    _messageController.value = TextEditingValue(
      text: value.text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Widget _composer(BuildContext context, ColorScheme colors) {
    final inputIconStyle = IconButton.styleFrom(
      minimumSize: const Size(32, 32),
      fixedSize: const Size(32, 32),
      padding: const EdgeInsets.all(_ChatLayout.space4),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return ConstrainedBox(
      key: const ValueKey('chat-composer'),
      constraints: const BoxConstraints(
        minHeight: _ChatLayout.minComposerHeight,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_ChatLayout.space16),
          ),
          border: Border(
            top: BorderSide(color: colors.subtleDivider, width: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_ChatLayout.space8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: ConstrainedBox(
                  key: const ValueKey('chat-input'),
                  constraints: const BoxConstraints(
                    minHeight: _ChatLayout.minInputHeight,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(
                        _ChatLayout.inputRadius,
                      ),
                      border: Border.all(color: colors.inputOutline),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _ChatLayout.space12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: _ChatLayout.space8,
                            ),
                            child: IconButton(
                              tooltip: _showEmoji ? 'Close emoji' : 'Emoji',
                              style: inputIconStyle,
                              iconSize: _ChatLayout.iconSize,
                              icon: Icon(
                                _showEmoji
                                    ? Icons.close
                                    : Icons.sentiment_satisfied_alt_outlined,
                                color: colors.onSurfaceVariant,
                              ),
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                setState(() => _showEmoji = !_showEmoji);
                              },
                            ),
                          ),
                          const SizedBox(width: _ChatLayout.space8),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              minLines: 1,
                              maxLines: _ChatLayout.maxInputLines,
                              textCapitalization: TextCapitalization.sentences,
                              keyboardType: TextInputType.multiline,
                              textAlignVertical: TextAlignVertical.center,
                              style: const TextStyle(
                                fontSize: _ChatLayout.messageFontSize,
                                height: 1.4,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                filled: false,
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: _ChatLayout.space12,
                                ),
                              ),
                              onTap: () {
                                if (_showEmoji) {
                                  setState(() => _showEmoji = false);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: _ChatLayout.space8),
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: _ChatLayout.space8,
                            ),
                            child: IconButton(
                              tooltip: 'Attach files',
                              style: inputIconStyle,
                              iconSize: _ChatLayout.iconSize,
                              onPressed: _pickingFiles
                                  ? null
                                  : () => _showAttachmentMenu(context),
                              icon: _pickingFiles
                                  ? const SizedBox(
                                      width: _ChatLayout.iconSize,
                                      height: _ChatLayout.iconSize,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      Icons.attach_file,
                                      color: colors.onSurfaceVariant,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _ChatLayout.space8),
              Padding(
                padding: const EdgeInsets.only(
                  bottom:
                      (_ChatLayout.minInputHeight -
                          _ChatLayout.sendButtonSize) /
                      2,
                ),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _messageController,
                  builder: (_, value, _) => IconButton.filled(
                    key: const ValueKey('chat-send'),
                    tooltip: 'Send message',
                    style: IconButton.styleFrom(
                      fixedSize: const Size(
                        _ChatLayout.sendButtonSize,
                        _ChatLayout.sendButtonSize,
                      ),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          _ChatLayout.sendButtonRadius,
                        ),
                      ),
                      backgroundColor: colors.sendButtonBackground,
                      foregroundColor: colors.onPrimary,
                      disabledBackgroundColor: colors.disabledBackground,
                      disabledForegroundColor: colors.disabledForeground,
                    ),
                    onPressed:
                        _pickingFiles ||
                            (value.text.trim().isEmpty &&
                                _pendingFiles.isEmpty &&
                                _pendingForward == null)
                        ? null
                        : _sendMessage,
                    icon: const Icon(
                      Icons.send_rounded,
                      size: _ChatLayout.iconSize,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final saved = widget.chatId == 'saved';
    final name = widget.chatName.trim();
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: _ChatLayout.appBarHeight,
        titleSpacing: _ChatLayout.space16,
        actionsPadding: const EdgeInsets.only(right: _ChatLayout.space16),
        title: Row(
          children: [
            CircleAvatar(
              radius: _ChatLayout.avatarSize / 2,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: saved
                  ? const Icon(Icons.bookmark_border)
                  : Text(
                      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                    ),
            ),
            const SizedBox(width: _ChatLayout.space12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: _ChatLayout.nameFontSize,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _blocked
                        ? 'Blocked in this session'
                        : saved
                        ? 'Your personal space'
                        : 'Local chat · offline',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _ChatLayout.statusFontSize,
                      height: 1.2,
                      color: colors.onPrimaryMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Chat options',
            onSelected: (value) {
              if (value == 'clear') _confirmAction(context, block: false);
              if (value == 'block') {
                if (_blocked) {
                  setState(() => _blocked = false);
                } else {
                  _confirmAction(context, block: true);
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline, color: colors.error),
                  title: Text(
                    'Clear history',
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ),
              if (!saved)
                PopupMenuItem(
                  value: 'block',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _blocked ? Icons.lock_open : Icons.block,
                      color: _blocked ? colors.primary : colors.error,
                    ),
                    title: Text(
                      _blocked ? 'Unblock user' : 'Block user',
                      style: TextStyle(
                        color: _blocked ? colors.primary : colors.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 280),
                        margin: const EdgeInsets.all(_ChatLayout.space24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: _ChatLayout.space16,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              saved
                                  ? Icons.bookmark_border
                                  : Icons.waving_hand_outlined,
                              size: 40,
                              color: colors.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              saved
                                  ? 'Your saved messages'
                                  : 'Start a conversation',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: _ChatLayout.space4),
                            Text(
                              'Messages are kept only while this screen is open.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                      itemCount: _messages.length,
                      itemBuilder: (_, index) {
                        final message = _messages[index];
                        final previous = index + 1 < _messages.length
                            ? _messages[index + 1]
                            : null;
                        final startsDay =
                            previous == null ||
                            DateUtils.dateOnly(previous.time) !=
                                DateUtils.dateOnly(message.time);
                        return Column(
                          children: [
                            if (startsDay)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: _ChatLayout.space12,
                                ),
                                child: SizedBox(
                                  height: _ChatLayout.dateHeight,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: colors.secondaryContainer,
                                      borderRadius: BorderRadius.circular(
                                        _ChatLayout.dateRadius,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal:
                                            _ChatLayout.dateHorizontalPadding,
                                      ),
                                      child: Center(
                                        widthFactor: 1,
                                        child: Text(
                                          DateUtils.isSameDay(
                                                message.time,
                                                DateTime.now(),
                                              )
                                              ? 'Today'
                                              : '${message.time.day}/${message.time.month}/${message.time.year}',
                                          style: TextStyle(
                                            color: colors.onSecondaryContainer,
                                            fontSize: _ChatLayout.dateFontSize,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Align(
                              alignment: message.isOwn
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: GestureDetector(
                                onLongPressStart: (details) =>
                                    _showMessageActions(
                                      context,
                                      message,
                                      details.globalPosition,
                                    ),
                                onSecondaryTapUp: (details) =>
                                    _showMessageActions(
                                      context,
                                      message,
                                      details.globalPosition,
                                    ),
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.sizeOf(context).width *
                                        _ChatLayout.bubbleWidthFraction,
                                  ),
                                  margin: const EdgeInsets.only(
                                    bottom: _ChatLayout.bubbleGap,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: _ChatLayout.space12,
                                    vertical: _ChatLayout.space8,
                                  ),
                                  decoration: ShapeDecoration(
                                    color: message.isOwn
                                        ? colors.outgoingMessageBackground
                                        : colors.surfaceContainer,
                                    shape: _MessageBubbleBorder(
                                      isOwn: message.isOwn,
                                    ),
                                    shadows: const [
                                      BoxShadow(
                                        color: AppTheme.messageShadow,
                                        offset: Offset(0, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: IntrinsicWidth(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (final attachment in message.files)
                                          _attachmentCard(context, attachment),
                                        if (message.forwardedFrom != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: _ChatLayout.space4,
                                            ),
                                            child: Text(
                                              'Forwarded from ${message.forwardedFrom}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colors.onSurfaceVariant,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        if (message.replyPreview != null)
                                          Container(
                                            width: double.infinity,
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: colors.replyBackground,
                                              borderRadius: BorderRadius.all(
                                                Radius.circular(10),
                                              ),
                                              border: Border(
                                                left: BorderSide(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                  width: 3,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Reply',
                                                  style: TextStyle(
                                                    color:
                                                        colors.onSurfaceVariant,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  height: _ChatLayout.space4,
                                                ),
                                                Text(
                                                  message.replyPreview!,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: colors.onSurface,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (message.text.isNotEmpty)
                                          Text(
                                            message.text,
                                            style: TextStyle(
                                              fontSize:
                                                  _ChatLayout.messageFontSize,
                                              color: colors.onSurface,
                                              height: 1.4,
                                            ),
                                          ),
                                        const SizedBox(
                                          height: _ChatLayout.space4,
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${message.edited ? 'edited · ' : ''}${message.time.hour.toString().padLeft(2, '0')}:${message.time.minute.toString().padLeft(2, '0')}',
                                                style: TextStyle(
                                                  fontSize:
                                                      _ChatLayout.timeFontSize,
                                                  height: 1.2,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      colors.messageTimestamp,
                                                ),
                                              ),
                                              if (message.isOwn) ...[
                                                const SizedBox(width: 4),
                                                Tooltip(
                                                  message: message.isRead
                                                      ? 'Read'
                                                      : 'Sent',
                                                  child: Icon(
                                                    message.isRead
                                                        ? Icons.done_all_rounded
                                                        : Icons.done_rounded,
                                                    size: _ChatLayout.space12,
                                                    color: message.isRead
                                                        ? colors.primary
                                                        : colors.sentReceipt,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (message.reaction != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: _ChatLayout.space4,
                                            ),
                                            child: ActionChip(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              shape: const StadiumBorder(),
                                              label: Text(
                                                '${message.reaction} 1',
                                              ),
                                              tooltip: 'Remove reaction',
                                              backgroundColor:
                                                  colors.reactionBackground,
                                              labelStyle: TextStyle(
                                                color: colors.onSurface,
                                              ),
                                              side: BorderSide.none,
                                              onPressed: () => _toggleReaction(
                                                message,
                                                message.reaction!,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            if ((_replyPreview != null || _forwardedFrom != null) && !_blocked)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      _replyPreview != null
                          ? Icons.reply_rounded
                          : Icons.forward_rounded,
                      color: colors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(
                          left: _ChatLayout.space12,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: colors.primary, width: 3),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _replyPreview != null
                                  ? 'Ответ на сообщение'
                                  : 'Forwarded from $_forwardedFrom',
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _replyPreview ??
                                  (_pendingForward == null
                                      ? ''
                                      : _preview(_pendingForward!)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 14,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Cancel reply or forwarding',
                      icon: const Icon(Icons.close, size: 20),
                      color: colors.onSurfaceVariant,
                      onPressed: () => setState(() {
                        if (_replyPreview != null) {
                          _replyPreview = null;
                        } else {
                          _forwardedFrom = null;
                          _pendingForward = null;
                        }
                      }),
                    ),
                  ],
                ),
              ),
            if (_pendingFiles.isNotEmpty && !_blocked)
              Container(
                width: double.infinity,
                color: colors.surfaceContainerLow,
                padding: const EdgeInsets.symmetric(
                  horizontal: _ChatLayout.space12,
                  vertical: _ChatLayout.space8,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 110),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: _ChatLayout.space8,
                      runSpacing: _ChatLayout.space8,
                      children: [
                        for (final attachment in _pendingFiles)
                          InputChip(
                            avatar: const Icon(
                              Icons.insert_drive_file_outlined,
                              size: 18,
                            ),
                            label: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                attachment.file.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            tooltip:
                                '${attachment.file.name} · ${attachment.sizeLabel}',
                            onDeleted: () => setState(
                              () => _pendingFiles.remove(attachment),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_blocked)
              Container(
                color: colors.surface,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  onPressed: () => setState(() => _blocked = false),
                  child: const Text('Unblock user'),
                ),
              )
            else
              _composer(context, colors),
            if (_showEmoji && !_blocked)
              Container(
                width: double.infinity,
                color: colors.surfaceContainerLow,
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (final emoji in [
                      '😀',
                      '😊',
                      '😂',
                      '❤️',
                      '👍',
                      '🎉',
                      '👋',
                      '🔥',
                    ])
                      TextButton(
                        onPressed: () => _insertEmoji(emoji),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A rounded body with a 10 × 8 tail reserved inside the bubble's bounds.
class _MessageBubbleBorder extends ShapeBorder {
  const _MessageBubbleBorder({required this.isOwn});

  final bool isOwn;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(
    left: isOwn ? 0 : _ChatLayout.tailWidth,
    right: isOwn ? _ChatLayout.tailWidth : 0,
  );

  @override
  ShapeBorder scale(double t) => this;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final bodyRect = Rect.fromLTRB(
      rect.left + (isOwn ? 0 : _ChatLayout.tailWidth),
      rect.top,
      rect.right - (isOwn ? _ChatLayout.tailWidth : 0),
      rect.bottom,
    );
    final body = Path()
      ..addRRect(
        BorderRadius.only(
          topLeft: const Radius.circular(_ChatLayout.bubbleRadius),
          topRight: const Radius.circular(_ChatLayout.bubbleRadius),
          bottomLeft: Radius.circular(
            isOwn
                ? _ChatLayout.bubbleRadius
                : _ChatLayout.bubbleTailCornerRadius,
          ),
          bottomRight: Radius.circular(
            isOwn
                ? _ChatLayout.bubbleTailCornerRadius
                : _ChatLayout.bubbleRadius,
          ),
        ).toRRect(bodyRect),
      );
    final edge = isOwn ? bodyRect.right : bodyRect.left;
    final direction = isOwn ? 1.0 : -1.0;
    final tail = Path()
      ..moveTo(
        edge - direction * _ChatLayout.bubbleTailCornerRadius,
        rect.bottom - _ChatLayout.tailHeight,
      )
      ..quadraticBezierTo(
        edge + direction * 2,
        rect.bottom - _ChatLayout.space4,
        edge + direction * _ChatLayout.tailWidth,
        rect.bottom,
      )
      ..quadraticBezierTo(
        edge + direction * 2,
        rect.bottom,
        edge - direction * _ChatLayout.bubbleTailCornerRadius,
        rect.bottom,
      )
      ..close();
    return Path.combine(PathOperation.union, body, tail);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
}

class _Message {
  _Message(
    this.text,
    this.time, {
    this.files = const [],
    this.replyPreview,
    this.forwardedFrom,
    this.isOwn = true,
    this.isRead = false,
  });
  String text;
  bool edited = false;
  final bool isOwn;
  bool isRead;
  final DateTime time;
  final List<_Attachment> files;
  final String? replyPreview;
  final String? forwardedFrom;
  String? reaction;
}

class _Attachment {
  const _Attachment(this.file, this.size);
  // Keep the actual file handle available for a future streamed upload.
  final PlatformFile file;
  final int? size;

  String get sizeLabel {
    final bytes = size;
    if (bytes == null) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
