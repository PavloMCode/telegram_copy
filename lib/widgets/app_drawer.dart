import 'package:flutter/material.dart';
import '../navigation/main_section.dart';
import '../screens/chat_screen.dart';
import 'drawer_profile_header.dart';
import 'group_scope.dart';
import 'auth_session_scope.dart';
import 'account_data_scope.dart';
import '../services/local_auth_api.dart';
import '../screens/accounts_screen.dart';

/// Standard M3 destinations with the existing account header and actions.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.selectedSection,
    required this.onSectionSelected,
  });
  final MainSection selectedSection;
  final ValueChanged<MainSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final api = AuthSessionScope.maybeOf(context);
    final selected = switch (selectedSection) {
      MainSection.chats => 0,
      MainSection.contacts => 1,
      MainSection.settings => 3,
    };
    return SizedBox(
      width: 304,
      child: NavigationDrawer(
        selectedIndex: selected,
        onDestinationSelected: (index) {
          Scaffold.of(context).closeDrawer();
          if (index == 2) {
            final screen = GroupScope.wrap(
              context,
              const ChatScreen(chatId: 'saved', chatName: 'Saved Messages'),
            );
            Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => screen));
          } else {
            onSectionSelected(switch (index) {
              0 => MainSection.chats,
              1 => MainSection.contacts,
              _ => MainSection.settings,
            });
          }
        },
        children: [
          const DrawerProfileHeader(),
          const SizedBox(height: 12),
          if (api is LocalAuthApi)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 28),
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Accounts'),
              onTap: () {
                final activeId = AccountDataScope.maybeOf(context)!.accountId;
                Scaffold.of(context).closeDrawer();
                final screen = GroupScope.wrap(
                  context,
                  AccountsScreen(api: api, activeId: activeId),
                );
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => screen),
                );
              },
            ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: Flexible(
              child: Text(
                'Chats',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: Flexible(
              child: Text(
                'Contacts',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: Flexible(
              child: Text(
                'Saved Messages',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: Divider(),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: Flexible(
              child: Text(
                'Settings',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
