import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../data/demo_data.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/chat/chat_layout.dart';
import '../widgets/chat/chat_composer.dart';
import '../widgets/chat/attachment_menu.dart';
import '../widgets/chat/message_bubble.dart';
import '../widgets/chat/chat_header_title.dart';
import '../widgets/chat/chat_date_separator.dart';
import '../widgets/chat/chat_empty_state.dart';
import '../widgets/chat/chat_emoji_panel.dart';
import '../widgets/chat/message_actions.dart';
import '../widgets/chat/chat_reply_banner.dart';
import '../widgets/group_scope.dart';
import 'contact_account_screen.dart';

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
    final type = await showAttachmentMenu(context);
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
    final action = await showChatMessageActions(
      context,
      position,
      reaction: message.reaction,
      canEdit: !_blocked && message.isOwn && message.forwardedFrom == null,
      canReply: !_blocked,
      emptyText: message.text.isEmpty,
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
      if (!mounted || !context.mounted) return;
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
        _blocked) {
      return;
    }
    setState(() {
      message.text = result;
      message.edited = true;
    });
  }

  Future<void> _forwardMessage(BuildContext context, _Message message) async {
    final chats = {for (final chat in demoChats) chat.id: chat.name};
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
      padding: const EdgeInsets.only(bottom: ChatLayout.space8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            child: const Icon(Icons.insert_drive_file_outlined),
          ),
          const SizedBox(width: ChatLayout.space12),
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
    final confirmed = await showConfirmationDialog(
      context,
      title: block ? 'Block user?' : 'Clear history?',
      message: block
          ? 'Sending messages will be disabled for this session. You can unblock the user at any time.'
          : 'All messages in this local session will be removed.',
      confirmLabel: block ? 'Block' : 'Clear',
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

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final saved = widget.chatId == 'saved';
    final contact = DemoContacts.all
        .where((contact) => contact.id == widget.chatId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: ChatLayout.appBarHeight,
        titleSpacing: ChatLayout.space16,
        actionsPadding: const EdgeInsets.only(right: ChatLayout.space16),
        title: ChatHeaderTitle(
          onTap: contact == null
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  final screen = GroupScope.wrap(
                    context,
                    ContactAccountScreen(contact: contact, fromChat: true),
                  );
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => screen),
                  );
                },
          name: widget.chatName,
          status: _blocked
              ? 'Blocked in this session'
              : saved
              ? 'Your personal space'
              : 'Local chat · offline',
          icon: saved ? Icons.bookmark_border : null,
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
                  ? ChatEmptyState(
                      title: saved
                          ? 'Your saved messages'
                          : 'Start a conversation',
                      subtitle:
                          'Messages are kept only while this screen is open.',
                      icon: saved
                          ? Icons.bookmark_border
                          : Icons.waving_hand_outlined,
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
                              ChatDateSeparator(time: message.time),
                            ChatMessageBubble(
                              text: message.text,
                              time: message.time,
                              isOwn: message.isOwn,
                              isRead: message.isRead,
                              edited: message.edited,
                              forwardedFrom: message.forwardedFrom,
                              replyPreview: message.replyPreview,
                              reaction: message.reaction,
                              attachments: [
                                for (final attachment in message.files)
                                  _attachmentCard(context, attachment),
                              ],
                              onAction: (position) => _showMessageActions(
                                context,
                                message,
                                position,
                              ),
                              onRemoveReaction: () =>
                                  _toggleReaction(message, message.reaction!),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            if ((_replyPreview != null || _forwardedFrom != null) && !_blocked)
              ChatReplyBanner(
                title: _replyPreview != null
                    ? 'Ответ на сообщение'
                    : 'Forwarded from $_forwardedFrom',
                preview:
                    _replyPreview ??
                    (_pendingForward == null ? '' : _preview(_pendingForward!)),
                forward: _replyPreview == null,
                onCancel: () => setState(() {
                  if (_replyPreview != null) {
                    _replyPreview = null;
                  } else {
                    _forwardedFrom = null;
                    _pendingForward = null;
                  }
                }),
              ),
            if (_pendingFiles.isNotEmpty && !_blocked)
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
              ChatComposer(
                controller: _messageController,
                showEmoji: _showEmoji,
                pickingFiles: _pickingFiles,
                hasPendingContent:
                    _pendingFiles.isNotEmpty || _pendingForward != null,
                onToggleEmoji: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _showEmoji = !_showEmoji);
                },
                onInputTap: () {
                  if (_showEmoji) setState(() => _showEmoji = false);
                },
                onAttach: () => _showAttachmentMenu(context),
                onSend: _sendMessage,
              ),
            if (_showEmoji && !_blocked)
              ChatEmojiPanel(controller: _messageController),
          ],
        ),
      ),
    );
  }
}

/// A rounded body with a 10 × 8 tail reserved inside the bubble's bounds.
class _Message {
  _Message(
    this.text,
    this.time, {
    this.files = const [],
    this.replyPreview,
    this.forwardedFrom,
  });
  String text;
  bool edited = false;
  final bool isOwn = true;
  bool isRead = false;
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
