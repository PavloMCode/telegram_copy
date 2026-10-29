import 'package:flutter/material.dart';
import '../navigation/main_section.dart';
import '../theme/app_theme.dart';
import '../data/demo_data.dart';
import 'chat_screen.dart';
import 'create_conversation_screen.dart';
import '../services/auth_api.dart';
import '../widgets/app_drawer.dart';
import '../widgets/search_app_bar.dart';
import '../widgets/group_scope.dart';
import '../services/local_group_store.dart';
import 'group_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.userName = 'My Name',
    this.phone = '+380 99 123 45 67',
    this.authApi,
    required this.onSectionSelected,
  });

  final String userName;
  final String phone;
  final AuthApi? authApi;
  final ValueChanged<MainSection> onSectionSelected;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
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
      );
    });
    final chats = [...localChats, ...demoChats]
        .where(
          (chat) =>
              chat.name.toLowerCase().contains(query) ||
              chat.message.toLowerCase().contains(query),
        )
        .toList();
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: SearchAppBar(
        title: 'Chats',
        hintText: 'Search chats',
        controller: _searchController,
        titleStyle: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
        onChanged: (_) => setState(() {}),
      ),
      drawer: AppDrawer(
        selectedSection: MainSection.chats,
        onSectionSelected: widget.onSectionSelected,
      ),
      body: SafeArea(
        top: false,
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
                itemBuilder: (context, index) => _tile(context, chats[index]),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New message',
        shape: const CircleBorder(),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 2,
        onPressed: () => _open(const NewChatScreen()),
        child: const Icon(Icons.edit, size: 25),
      ),
    );
  }

  Widget _tile(BuildContext context, DemoChat chat) {
    final colors = AppTheme.colorsOf(context);
    final group = _groups?.find(chat.id);
    final secondary = colors.onSurfaceVariant;
    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: () => _open(
          group == null
              ? ChatScreen(chatId: chat.id, chatName: chat.name)
              : GroupChatScreen(store: _groups!, groupId: group.id),
        ),
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
                            Icons.group,
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
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
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
                      style: TextStyle(
                        fontSize: 15,
                        color: colors.onSurfaceVariant,
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
                        style: TextStyle(fontSize: 12, color: secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (chat.unread > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 23),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: chat.muted
                            ? colors.surfaceContainerHighest
                            : colors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${chat.unread}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: chat.muted
                              ? colors.onSurfaceVariant
                              : colors.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
