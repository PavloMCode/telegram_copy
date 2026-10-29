import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/chat/chat_layout.dart';
import '../widgets/chat/attachment_menu.dart';
import '../widgets/chat/message_actions.dart';
import '../widgets/chat/chat_reply_banner.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/chat/message_bubble.dart';
import '../widgets/chat/chat_header_title.dart';
import '../widgets/chat/chat_date_separator.dart';
import '../widgets/chat/chat_empty_state.dart';
import '../widgets/chat/chat_emoji_panel.dart';
import '../models/local_group.dart';
import '../services/local_group_store.dart';
import '../services/group_media_files.dart';
import '../widgets/chat/chat_composer.dart';
import '../widgets/group_media_tile.dart';
import 'group_details_screen.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    super.key,
    required this.store,
    required this.groupId,
  });
  final LocalGroupStore store;
  final String groupId;
  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  String? _replyPreview;
  final _draft = <GroupMedia>[];
  bool _busy = false;
  bool _emoji = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is GroupException
              ? error.message
              : 'Could not save locally. Please try again.',
        ),
      ),
    );
  }

  Future<void> _attach() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _emoji = false);
    final type = await showAttachmentMenu(context, includeAudio: true);
    if (!mounted || type == null) return;
    final kind = switch (type) {
      FileType.image => GroupMediaKind.photo,
      FileType.video => GroupMediaKind.video,
      FileType.audio => GroupMediaKind.voice,
      _ => GroupMediaKind.file,
    };
    setState(() => _busy = true);
    try {
      final files = await FilePicker.pickFiles(type: type);
      for (final file in files) {
        final media = await saveGroupMedia(
          widget.store.userId,
          widget.groupId,
          file,
          kind,
        );
        if (!mounted) return;
        setState(() => _draft.add(media));
      }
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_busy || _controller.text.trim().isEmpty && _draft.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.store.send(
        widget.groupId,
        _controller.text,
        _draft,
        replyPreview: _replyPreview,
      );
      if (!mounted) return;
      setState(() {
        _controller.clear();
        _draft.clear();
        _replyPreview = null;
        _emoji = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _details() async {
    FocusScope.of(context).unfocus();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GroupDetailsScreen(store: widget.store, groupId: widget.groupId),
      ),
    );
    if (!mounted) return;
    if (widget.store.find(widget.groupId) == null) Navigator.pop(context);
  }

  String _preview(GroupMessage message) => message.text.isNotEmpty
      ? message.text
      : message.media.map((media) => media.name).join(', ');

  Future<void> _persist(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      _error(error);
    }
  }

  Future<void> _editMessage(GroupMessage message) async {
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
              onPressed: draft.trim().isEmpty && message.media.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, draft.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null || result == message.text) return;
    await _persist(
      () => widget.store.editMessage(widget.groupId, message.id, result),
    );
  }

  Future<void> _messageActions(GroupMessage message, Offset position) async {
    if (_busy) return;
    final action = await showChatMessageActions(
      context,
      position,
      reaction: message.reaction,
      canForward: false,
      emptyText: message.text.isEmpty,
    );
    if (!mounted ||
        action == null ||
        !(widget.store
                .find(widget.groupId)
                ?.messages
                .any((m) => m.id == message.id) ??
            false)) {
      return;
    }
    switch (action) {
      case 'copy':
        await Clipboard.setData(
          ClipboardData(
            text: message.text.isEmpty
                ? message.media.map((m) => m.name).join('\n')
                : message.text,
          ),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      case 'reply':
        setState(() {
          _replyPreview = _preview(message);
          _emoji = false;
        });
      case 'edit':
        await _editMessage(message);
      case 'delete':
        await _persist(
          () => widget.store.deleteMessage(widget.groupId, message.id),
        );
      default:
        await _persist(
          () => widget.store.react(widget.groupId, message.id, action),
        );
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Clear history?',
      message: 'All messages in this local group history will be removed.',
      confirmLabel: 'Clear',
    );
    if (!mounted || !confirmed) return;
    await _persist(() => widget.store.clearHistory(widget.groupId));
    if (mounted) setState(() => _replyPreview = null);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final group = widget.store.find(widget.groupId);
      if (group == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Group')),
          body: const Center(child: Text('This group is no longer available.')),
        );
      }
      final colors = AppTheme.colorsOf(context);
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: ChatLayout.appBarHeight,
          titleSpacing: ChatLayout.space16,
          actionsPadding: const EdgeInsets.only(right: ChatLayout.space16),
          title: ChatHeaderTitle(
            name: group.name,
            status: '${group.members.length} members · local group',
            photo: group.photo == null ? null : MemoryImage(group.photo!),
            icon: Icons.group_outlined,
            onTap: _details,
          ),
          actions: [
            IconButton(
              tooltip: 'Group settings',
              onPressed: _details,
              icon: const Icon(Icons.info_outline),
            ),
            PopupMenuButton<String>(
              tooltip: 'Chat options',
              onSelected: (value) {
                if (value == 'settings') _details();
                if (value == 'clear') _clearHistory();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.group_outlined, size: 21),
                      SizedBox(width: 12),
                      Text('Group settings'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: colors.error, size: 21),
                      const SizedBox(width: 12),
                      Text(
                        'Clear history',
                        style: TextStyle(color: colors.error),
                      ),
                    ],
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
                child: group.messages.isEmpty
                    ? const ChatEmptyState(
                        title: 'Start a conversation',
                        subtitle:
                            'Group messages and attachments are saved on this device.',
                        icon: Icons.group_outlined,
                      )
                    : ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                        itemCount: group.messages.length,
                        itemBuilder: (context, index) {
                          final chronological =
                              group.messages.length - 1 - index;
                          final message = group.messages[chronological];
                          final previous = chronological > 0
                              ? group.messages[chronological - 1]
                              : null;
                          final startsDay =
                              previous == null ||
                              !DateUtils.isSameDay(
                                message.sentAt,
                                previous.sentAt,
                              );
                          return Column(
                            children: [
                              if (startsDay)
                                ChatDateSeparator(time: message.sentAt),
                              ChatMessageBubble(
                                key: ValueKey('group-message-${message.id}'),
                                text: message.text,
                                time: message.sentAt,
                                edited: message.edited,
                                replyPreview: message.replyPreview,
                                reaction: message.reaction,
                                attachments: [
                                  for (final media in message.media)
                                    GroupMediaTile(media: media, compact: true),
                                ],
                                onAction: (position) =>
                                    _messageActions(message, position),
                                onRemoveReaction: () => _persist(
                                  () => widget.store.react(
                                    widget.groupId,
                                    message.id,
                                    message.reaction!,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              if (_replyPreview != null)
                ChatReplyBanner(
                  title: 'Ответ на сообщение',
                  preview: _replyPreview!,
                  onCancel: () => setState(() => _replyPreview = null),
                ),
              if (_draft.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: colors.surfaceContainerLow,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ChatLayout.space12,
                    vertical: ChatLayout.space8,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 110),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: ChatLayout.space8,
                        runSpacing: ChatLayout.space8,
                        children: [
                          for (final media in _draft)
                            InputChip(
                              avatar: const Icon(
                                Icons.insert_drive_file_outlined,
                                size: 18,
                              ),
                              label: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 180,
                                ),
                                child: Text(
                                  media.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              tooltip: '${media.name} · ${media.sizeLabel}',
                              onDeleted: _busy
                                  ? null
                                  : () => setState(() => _draft.remove(media)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ChatComposer(
                controller: _controller,
                showEmoji: _emoji,
                pickingFiles: _busy,
                hasPendingContent: _draft.isNotEmpty,
                onToggleEmoji: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _emoji = !_emoji);
                },
                onInputTap: () {
                  if (_emoji) setState(() => _emoji = false);
                },
                onAttach: _attach,
                onSend: _send,
              ),
              if (_emoji) ChatEmojiPanel(controller: _controller),
            ],
          ),
        ),
      );
    },
  );
}
