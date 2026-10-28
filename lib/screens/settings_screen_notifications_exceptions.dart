import 'package:flutter/material.dart';
import '../widgets/settings_row.dart';

class SettingsScreenNotificationsExceptions extends StatelessWidget {
  const SettingsScreenNotificationsExceptions({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notification exceptions')),
    body: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        SettingsRow(
          icon: Icons.chat_sharp,
          title: 'All chats',
          subtitle: 'Manage all chats',
          showChevron: true,
          onTap: () {},
        ),
        const SizedBox(height: 8),
        SettingsRow(
          icon: Icons.wechat_outlined,
          title: 'Chats',
          subtitle: 'Manage only chats',
          showChevron: true,
          onTap: () {},
        ),
        const SizedBox(height: 8),
        SettingsRow(
          icon: Icons.group,
          title: 'Groups',
          subtitle: 'Manage only groups',
          showChevron: true,
          onTap: () {},
        ),
        const SizedBox(height: 8),
        SettingsRow(
          icon: Icons.newspaper,
          title: 'Channels',
          subtitle: 'Manage only channels',
          showChevron: true,
          onTap: () {},
        ),
      ],
    ),
  );
}
