import '../widgets/gradient_surfaces.dart';
import 'package:flutter/material.dart';
import '../navigation/main_section.dart';
import '../theme/app_theme.dart';
import '../theme/app_gradients.dart';
import '../data/demo_data.dart';
import 'chat_screen.dart';
import 'create_conversation_screen.dart';
import '../services/auth_api.dart';
import '../widgets/app_drawer.dart';
import '../widgets/search_app_bar.dart';
import '../widgets/account_data_scope.dart';
import '../widgets/group_scope.dart';
import '../services/local_group_store.dart';
import 'group_chat_screen.dart';
import '../widgets/chat_list_actions.dart';

enum _ChatFilter { all, unread, groups, channels }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.userName = 'My Name',
    this.phone = '+380 99 123 45 67',
    this.authApi,
    required this.onSectionSelected,
    this.onConversationSelected,
    this.selectedChatId,
  });

  final String userName;
  final String phone;
  final AuthApi? authApi;
  final ValueChanged<MainSection> onSectionSelected;
  final void Function(String id, Widget screen)? onConversationSelected;
  final String? selectedChatId;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  _ChatFilter _filter = _ChatFilter.all;
  LocalGroupStore? _groups;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final groups = GroupScope.maybeOf(context);
    if (_groups != groups) {
      _groups?.removeListener(_onGroupsChanged);
      _groups = groups;
      _groups?.addListener(_onGroupsChanged);
    }
  }

  void _onGroupsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _groups?.removeListener(_onGroupsChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _open(Widget screen) {
    FocusScope.of(context).unfocus();
    final wrapped = GroupScope.wrap(context, screen);
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => wrapped));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final data = AccountDataScope.maybeOf(context);
    final query = _searchController.text.trim().toLowerCase();
    final localChats = (_groups?.groups ?? []).reversed.map((group) {
      final last = group.messages.isEmpty ? null : group.messages.last;
      return DemoChat(
        group.id,
        group.name,
        last == null
            ? '${group.members.length} members'
            : last.text.isNotEmpty
            ? last.text
            : last.media.map((m) => m.name).join(', '),
        last == null ? '' : TimeOfDay.fromDateTime(last.sentAt).format(context),
        group.name.characters.first.toUpperCase(),
        AppTheme.avatarBlue,
        group: true,
        pinned: data?.isChatPinned(group.id) ?? false,
      );
    });
    final directChats = demoChats.map((chat) {
      final summary = data?.conversations[chat.id];
      final contact = data?.contact(chat.id);
      return DemoChat(
        chat.id,
        contact?.name ?? chat.name,
        summary?['preview'] as String? ?? chat.message,
        chat.time,
        chat.initials,
        chat.color,
        unread: summary == null ? chat.unread : 0,
        pinned: data?.isChatPinned(chat.id) ?? chat.pinned,
        muted: chat.muted,
        group: chat.group,
        sent: chat.sent,
      );
    });
    final extraChats =
        (data?.conversations.entries ??
                <MapEntry<String, Map<String, dynamic>>>[])
            .where(
              (entry) =>
                  !demoChats.any((chat) => chat.id == entry.key) &&
                  !data!.isChatDeleted(entry.key) &&
                  _groups?.find(entry.key) == null,
            )
            .map(
              (entry) => DemoChat(
                entry.key,
                data?.contact(entry.key)?.name ?? entry.value['name'] as String,
                entry.value['preview'] as String? ?? '',
                '',
                '?',
                AppTheme.avatarBlue,
                pinned: data?.isChatPinned(entry.key) ?? false,
              ),
            );
    final chats = [...localChats, ...extraChats, ...directChats]
        .where(
          (chat) =>
              !(data?.isChatDeleted(chat.id) ?? false) &&
              (chat.name.toLowerCase().contains(query) ||
                  chat.message.toLowerCase().contains(query)) &&
              switch (_filter) {
                _ChatFilter.all => true,
                _ChatFilter.unread => chat.unread > 0,
                _ChatFilter.groups =>
                  chat.group && !(_groups?.find(chat.id)?.isChannel ?? false),
                _ChatFilter.channels =>
                  _groups?.find(chat.id)?.isChannel ?? false,
              },
        )
        .toList();
    final orderedChats = [
      ...chats.where((chat) => chat.pinned),
      ...chats.where((chat) => !chat.pinned),
    ];
    return AppScaffold(
      backgroundColor: colors.surface,
      appBar: SearchAppBar(
        title: 'Chats',
        hintText: 'Search chats',
        controller: _searchController,
        titleStyle: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
        onChanged: (_) => setState(() {}),
      ),
      drawer: MediaQuery.sizeOf(context).width >= 840
          ? null
          : AppDrawer(
              selectedSection: MainSection.chats,
              onSectionSelected: widget.onSectionSelected,
            ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final filter in _ChatFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        showCheckmark: true,
                        labelStyle: TextStyle(
                          color: _filter == filter
                              ? colors.onSecondaryContainer
                              : colors.onSurfaceVariant,
                          fontWeight: _filter == filter
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        shape: _filter == filter
                            ? GradientBorder(
                                base: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                gradient: AppGradients.header(colors),
                              )
                            : null,
                        label: Text(switch (filter) {
                          _ChatFilter.all => 'All',
                          _ChatFilter.unread => 'Unread',
                          _ChatFilter.groups => 'Groups',
                          _ChatFilter.channels => 'Channels',
                        }),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: chats.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No chats found',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 8, bottom: 88),
                      itemCount: chats.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 88,
                        endIndent: 16,
                        color: colors.subtleDivider,
                      ),
                      itemBuilder: (context, index) =>
                          _tile(context, orderedChats[index]),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: MediaQuery.sizeOf(context).width >= 600
          ? GradientFab.extended(
              tooltip: 'New message',
              onPressed: () => _open(const NewChatScreen()),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('New message'),
            )
          : GradientFab(
              tooltip: 'New message',
              onPressed: () => _open(const NewChatScreen()),
              child: const Icon(Icons.edit, size: 25),
            ),
    );
  }

  Widget _tile(BuildContext context, DemoChat chat) {
    final colors = AppTheme.colorsOf(context);
    final group = _groups?.find(chat.id);
    final isSelected = widget.selectedChatId == chat.id;
    final secondary = isSelected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    return Material(
      color: isSelected ? colors.primaryContainer : Colors.transparent,
      child: InkWell(
        onLongPress: () async {
          final data = AccountDataScope.maybeOf(context);
          if (data == null || !data.loaded || data.error != null) return;
          final action = await showGradientBottomSheet<String>(
            context: context,
            showDragHandle: true,
            useSafeArea: true,
            builder: (sheetContext) => SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.push_pin_outlined),
                    title: Text(chat.pinned ? 'Unpin chat' : 'Pin chat'),
                    onTap: () => Navigator.pop(sheetContext, 'pin_chat'),
                  ),
                  if (group == null)
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: const Text('Delete chat'),
                      onTap: () => Navigator.pop(sheetContext, 'delete_chat'),
                    ),
                ],
              ),
            ),
          );
          if (context.mounted && action != null) {
            await performChatListAction(context, chat.id, action);
          }
        },
        onTap: () {
          final screen = group == null
              ? ChatScreen(chatId: chat.id, chatName: chat.name)
              : GroupChatScreen(store: _groups!, groupId: group.id);
          if (widget.onConversationSelected != null) {
            widget.onConversationSelected!(chat.id, screen);
          } else {
            _open(screen);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: group?.photo == null
                    ? null
                    : MemoryImage(group!.photo!),
                radius: 26,
                backgroundColor: chat.color,
                foregroundColor: AppTheme.avatarForeground,
                child: group?.photo != null
                    ? null
                    : chat.id == 'saved'
                    ? const Icon(Icons.bookmark_border, size: 30)
                    : Text(
                        chat.initials,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (chat.group) ...[
                          Icon(
                            group?.isChannel == true
                                ? Icons.campaign_outlined
                                : Icons.group,
                            size: 17,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            chat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? colors.onPrimaryContainer
                                      : colors.onSurface,
                                ),
                          ),
                        ),
                        if (chat.muted) ...[
                          const SizedBox(width: 5),
                          Icon(Icons.volume_off, size: 15, color: secondary),
                        ],
                        if (chat.pinned) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.push_pin_rounded,
                            size: 14,
                            color: secondary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      chat.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? colors.onPrimaryContainer
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (chat.sent) ...[
                        const Icon(
                          Icons.done_all,
                          size: 17,
                          color: AppTheme.readReceipt,
                        ),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        chat.time,
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (chat.unread > 0)
                    Badge(
                      largeSize: 24,
                      backgroundColor: chat.muted
                          ? colors.surfaceContainerHighest
                          : colors.primary,
                      textColor: chat.muted
                          ? colors.onSurfaceVariant
                          : colors.onPrimary,
                      label: Text(chat.unread > 99 ? '99+' : '${chat.unread}'),
                    )
                  else
                    const SizedBox(height: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
