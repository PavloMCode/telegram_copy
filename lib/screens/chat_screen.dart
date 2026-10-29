import 'dart:async';
import 'package:flutter/material.dart';
import '../services/local_account_store.dart';
import '../services/stored_platform_file.dart';
import '../services/group_media_files.dart';
import '../models/local_group.dart';
import '../widgets/account_data_scope.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../data/demo_data.dart';
import '../widgets/contact_actions.dart';
import '../widgets/contact_scope.dart';
import '../services/local_contact_store.dart';
import '../widgets/contact_call_dialog.dart';
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
import '../widgets/chat_list_actions.dart';
import '../widgets/chat/gif_attachment.dart';
import '../widgets/chat/forward_message.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  const ChatScreen({super.key, required this.chatId, required this.chatName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Message> _messages = [];
  final List<_Attachment> _pendingFiles = [];
  bool _pickingFiles = false;
  bool _forwarding = false;
  int _forwardVersion = 0;
  bool _deletingChat = false;
  LocalAccountStore? _data;
  bool _restoring = false;
  Timer? _draftTimer;
  LocalContactStore? _contacts;
  bool _ownsContacts = false;
  int _clearVersion = 0;
  bool _contactActionBusy = false;
  bool get _blocked => _contacts?.isBlocked(widget.chatId) ?? false;
  bool _showEmoji = false;
  String? _replyPreview;
  String? _forwardedFrom;
  _Message? _pendingForward;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messageController.addListener(_scheduleDraft);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final data = AccountDataScope.maybeOf(context);
    if (data?.database != null && !identical(data, _data)) {
      _data = data;
      _forwardVersion = data!.forwardVersion(widget.chatId);
      _restoring = true;
      _restore(data);
    } else if (data != null &&
        identical(data, _data) &&
        data.forwardVersion(widget.chatId) != _forwardVersion) {
      _forwardVersion = data.forwardVersion(widget.chatId);
      _restoring = true;
      _restore(data, messagesOnly: true);
    }
    final inherited = ContactScope.maybeOf(context);
    final store = inherited ?? _contacts ?? LocalContactStore();
    if (!identical(store, _contacts)) {
      _contacts?.removeListener(_onContactChanged);
      if (_ownsContacts) _contacts?.dispose();
      _contacts = store;
      _ownsContacts = inherited == null;
      _clearVersion = store.clearVersion(widget.chatId);
      store.addListener(_onContactChanged);
    }
  }

  void _onContactChanged() {
    if (!mounted) return;
    setState(() {
      final version = _contacts!.clearVersion(widget.chatId);
      if (version != _clearVersion) {
        _clearVersion = version;
        _messages.clear();
        _replyPreview = null;
        _forwardedFrom = null;
        _pendingForward = null;
      }
      if (_blocked) _showEmoji = false;
    });
  }

  Future<void> _contactAction(ContactAction action) async {
    if (_contactActionBusy) return;
    setState(() => _contactActionBusy = true);
    try {
      await performContactAction(context, _contacts!, widget.chatId, action);
    } finally {
      if (mounted) setState(() => _contactActionBusy = false);
    }
  }

  Future<void> _restore(
    LocalAccountStore data, {
    bool messagesOnly = false,
  }) async {
    try {
      final messages = await data.messages(widget.chatId);
      final draft = messagesOnly ? null : await data.draft(widget.chatId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages.map(_Message.fromJson));
        if (draft != null && _messageController.text.isEmpty) {
          _messageController.text = draft['text'] as String? ?? '';
          _replyPreview = draft['reply'] as String?;
          if (_pendingForward == null && draft['forward'] != null) {
            _pendingForward = _Message.fromJson(
              Map<String, dynamic>.from(draft['forward'] as Map),
            );
          }
          _forwardedFrom = _pendingForward?.forwardedFrom;
          _pendingFiles.addAll(
            (draft['files'] as List? ?? []).map(
              (f) => _Attachment.fromJson(Map<String, dynamic>.from(f as Map)),
            ),
          );
        }
        _restoring = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _restoring = false);
        _storageError();
      }
    }
  }

  void _storageError() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save local chat data. Please try again.'),
        ),
      );
    }
  }

  Future<void> _persist() async {
    if (_data == null || _restoring || _deletingChat) return;
    try {
      await _data!.saveConversation(
        widget.chatId,
        widget.chatName,
        _messages.map((m) => m.toJson()).toList(),
      );
      await _saveDraft();
    } catch (_) {
      _storageError();
    }
  }

  void _scheduleDraft() {
    if (_data == null || _restoring || _deletingChat) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_saveDraft().catchError((Object _) => _storageError())),
    );
  }

  Future<void> _saveDraft() async {
    if (_data == null || _restoring || _deletingChat) return;
    final draft = {
      'text': _messageController.text,
      'reply': _replyPreview,
      'files': _pendingFiles.map((f) => f.toJson()).toList(),
      'forward': _pendingForward?.toJson(),
    };
    await _data!.saveDraft(widget.chatId, draft);
  }

  String _preview(_Message message) => message.text.isNotEmpty
      ? message.text
      : message.files.map((file) => file.file.name).join(', ');

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _contacts?.removeListener(_onContactChanged);
    if (_ownsContacts) _contacts?.dispose();
    _draftTimer?.cancel();
    unawaited(_saveDraft().catchError((Object _) {}));
    _messageController.removeListener(_scheduleDraft);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _draftTimer?.cancel();
      unawaited(_saveDraft().catchError((Object _) => _storageError()));
    }
  }

  void _sendMessage() {
    if (_deletingChat) return;
    final text = _messageController.text.trim();
    if ((text.isEmpty && _pendingFiles.isEmpty && _pendingForward == null) ||
        _blocked ||
        _restoring ||
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
    unawaited(_persist());
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
      final files = await FilePicker.pickFiles(
        type: type,
        allowedExtensions: type == FileType.custom ? ['gif'] : null,
      );
      final attachments = <_Attachment>[];
      for (var file in files) {
        if (type == FileType.custom) await validateGif(file);
        if (_data != null) {
          final saved = await saveGroupMedia(
            _data!.accountId,
            widget.chatId,
            file,
            GroupMediaKind.file,
          );
          file = StoredPlatformFile(saved.name, saved.path, saved.size);
        }
        final size = file.lengthSync() ?? await file.length();
        attachments.add(_Attachment(file, size));
      }
      if (!mounted || _blocked) return;
      setState(() => _pendingFiles.addAll(attachments));
      _scheduleDraft();
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
    unawaited(_persist());
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
      _scheduleDraft();
    } else if (action == 'forward') {
      if (!context.mounted) return;
      await _forwardMessage(context, message);
    } else if (action == 'delete') {
      setState(() => _messages.remove(message));
      unawaited(_persist());
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
    unawaited(_persist());
  }

  Future<void> _forwardMessage(BuildContext context, _Message message) async {
    if (_forwarding) return;
    setState(() => _forwarding = true);
    try {
      await forwardChatMessage(
        context,
        sourceId: widget.chatId,
        origin: message.forwardedFrom ?? widget.chatName,
        text: message.text,
        attachments: [
          for (final attachment in message.files)
            ForwardAttachment(attachment.file, GroupMediaKind.file),
        ],
      );
    } finally {
      if (mounted) setState(() => _forwarding = false);
    }
  }

  Widget _attachmentCard(BuildContext context, _Attachment attachment) {
    if (attachment.file.name.toLowerCase().endsWith('.gif')) {
      return GifAttachment(
        file: attachment.file,
        sourceId: attachment.file.path ?? attachment.file.name,
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final saved = widget.chatId == 'saved';
    final contact =
        (AccountDataScope.maybeOf(context)?.contacts ?? DemoContacts.all)
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
                  final screen = ContactScope.wrap(
                    context,
                    GroupScope.wrap(
                      context,
                      ContactAccountScreen(contact: contact, fromChat: true),
                    ),
                    fallback: _contacts,
                  );
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => screen),
                  );
                },
          name: widget.chatName,
          status: _blocked
              ? 'Contact blocked'
              : saved
              ? 'Your personal space'
              : 'Local chat · offline',
          icon: saved ? Icons.bookmark_border : null,
        ),
        actions: [
          if (contact != null)
            IconButton(
              tooltip: 'Call ${contact.name}',
              onPressed: _blocked
                  ? null
                  : () => showContactCallDialog(context, contact.name),
              icon: const Icon(Icons.call_outlined),
            ),
          PopupMenuButton<String>(
            tooltip: 'Chat options',
            enabled: !_contactActionBusy && !_restoring,
            onSelected: (value) async {
              if (value == 'pin_chat' || value == 'delete_chat') {
                setState(() {
                  _contactActionBusy = true;
                  _deletingChat = value == 'delete_chat';
                });
                _draftTimer?.cancel();
                final deleted = await performChatListAction(
                  context,
                  widget.chatId,
                  value,
                );
                if (!mounted || !context.mounted) return;
                if (deleted) {
                  Navigator.pop(context);
                  return;
                }
                setState(() {
                  _contactActionBusy = false;
                  _deletingChat = false;
                });
                return;
              }
              await _contactAction(
                value == 'clear'
                    ? ContactAction.clearHistory
                    : _blocked
                    ? ContactAction.unblock
                    : ContactAction.block,
              );
            },
            itemBuilder: (_) => [
              if (AccountDataScope.maybeOf(context)?.loaded == true)
                ...chatListMenuItems(
                  pinned: AccountDataScope.maybeOf(
                    context,
                  )!.isChatPinned(widget.chatId),
                ),
              ...contactActionMenuItems(
                context,
                blocked: _blocked,
                canBlock: contact != null,
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
                      subtitle: _data == null
                          ? 'Messages are kept only while this screen is open.'
                          : 'Messages are saved on this device.',
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
                            onDeleted: () {
                              setState(() => _pendingFiles.remove(attachment));
                              _scheduleDraft();
                            },
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
                  onPressed: _contactActionBusy
                      ? null
                      : () => _contactAction(ContactAction.unblock),
                  child: const Text('Unblock user'),
                ),
              )
            else
              ChatComposer(
                controller: _messageController,
                showEmoji: _showEmoji,
                pickingFiles: _pickingFiles || _restoring,
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
    String? id,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
  final String id;
  String text;
  bool edited = false;
  final bool isOwn = true;
  bool isRead = false;
  final DateTime time;
  final List<_Attachment> files;
  final String? replyPreview;
  final String? forwardedFrom;
  String? reaction;
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'time': time.toIso8601String(),
    'edited': edited,
    'reaction': reaction,
    'reply': replyPreview,
    'forwarded': forwardedFrom,
    'files': files.map((f) => f.toJson()).toList(),
  };
  factory _Message.fromJson(Map<String, dynamic> json) {
    final message = _Message(
      json['text'] as String,
      DateTime.parse(json['time'] as String),
      id: json['id'] as String,
      replyPreview: json['reply'] as String?,
      forwardedFrom: json['forwarded'] as String?,
      files: (json['files'] as List? ?? [])
          .map((f) => _Attachment.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList(),
    );
    message.edited = json['edited'] as bool? ?? false;
    message.reaction = json['reaction'] as String?;
    return message;
  }
}

class _Attachment {
  const _Attachment(this.file, this.size);
  // Keep the actual file handle available for a future streamed upload.
  final PlatformFile file;
  final int? size;

  Map<String, dynamic> toJson() => {
    'name': file.name,
    'path': file.path,
    'size': size,
  };
  factory _Attachment.fromJson(Map<String, dynamic> json) => _Attachment(
    StoredPlatformFile(
      json['name'] as String,
      json['path'] as String,
      json['size'] as int?,
    ),
    json['size'] as int?,
  );

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
