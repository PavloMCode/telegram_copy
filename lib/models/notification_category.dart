enum NotificationCategory {
  chats('Private chats', 'notify_chats', 'notification_exceptions'),
  groups('Groups', 'notify_groups', 'notification_group_exceptions'),
  channels('Channels', 'notify_channels', 'notification_channel_exceptions');

  const NotificationCategory(this.label, this.settingKey, this.exceptionsKey);
  final String label;
  final String settingKey;
  final String exceptionsKey;
}
