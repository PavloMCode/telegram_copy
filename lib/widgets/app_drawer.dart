import 'package:flutter/material.dart';
import '../navigation/main_section.dart';
import '../screens/chat_screen.dart';
import '../theme/app_theme.dart';
import 'drawer_profile_header.dart';

abstract final class _DrawerLayout {
  static const width = 280.0;
  static const itemHeight = 52.0;
  static const iconSize = 22.0;
  static const horizontalPadding = 16.0;
  static const selectedRadius = 12.0;
  static const headerGap = 12.0;
}

/// Shared drawer for the three top-level sections.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final MainSection selectedSection;
  final ValueChanged<MainSection> onSectionSelected;

  void _select(BuildContext context, MainSection section) {
    Scaffold.of(context).closeDrawer();
    onSectionSelected(section);
  }

  void _openSavedMessages(BuildContext context) {
    Scaffold.of(context).closeDrawer();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const ChatScreen(chatId: 'saved', chatName: 'Saved Messages'),
      ),
    );
  }

  Widget _drawerItem(
    ColorScheme colors, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool selected = false,
  }) => Padding(
    // Split the 16 px inset between the background and its content.
    padding: const EdgeInsets.symmetric(
      horizontal: _DrawerLayout.horizontalPadding / 2,
    ),
    child: SizedBox(
      height: _DrawerLayout.itemHeight,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: _DrawerLayout.horizontalPadding / 2,
        ),
        minLeadingWidth: _DrawerLayout.iconSize,
        horizontalTitleGap: _DrawerLayout.horizontalPadding,
        minTileHeight: _DrawerLayout.itemHeight,
        minVerticalPadding: 0,
        visualDensity: VisualDensity.standard,
        titleAlignment: ListTileTitleAlignment.center,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_DrawerLayout.selectedRadius),
        ),
        selected: selected,
        selectedTileColor: colors.primaryContainer,
        selectedColor: colors.onPrimaryContainer,
        iconColor: colors.onSurfaceVariant,
        textColor: colors.onSurface,
        leading: Icon(icon, size: _DrawerLayout.iconSize),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Drawer(
      width: _DrawerLayout.width,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          const DrawerProfileHeader(),
          const SizedBox(height: _DrawerLayout.headerGap),
          _drawerItem(
            colors,
            title: 'Chats',
            icon: Icons.chat_bubble_outline_rounded,
            selected: selectedSection == MainSection.chats,
            onTap: () => _select(context, MainSection.chats),
          ),
          _drawerItem(
            colors,
            title: 'Contacts',
            icon: Icons.person_outline,
            selected: selectedSection == MainSection.contacts,
            onTap: () => _select(context, MainSection.contacts),
          ),
          _drawerItem(
            colors,
            title: 'Saved Messages',
            icon: Icons.bookmark_border,
            onTap: () => _openSavedMessages(context),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(
              height: 1,
              thickness: 1,
              indent: _DrawerLayout.horizontalPadding,
              endIndent: _DrawerLayout.horizontalPadding,
              color: colors.subtleDivider,
            ),
          ),
          _drawerItem(
            colors,
            title: 'Settings',
            icon: Icons.settings_outlined,
            selected: selectedSection == MainSection.settings,
            onTap: () => _select(context, MainSection.settings),
          ),
        ],
      ),
    );
  }
}
