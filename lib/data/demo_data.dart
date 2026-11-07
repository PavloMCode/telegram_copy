import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DemoContact {
  const DemoContact(this.id, this.name, this.phone);
  final String id;
  final String name;
  final String phone;
  String get status => 'last seen recently';
}

abstract final class DemoContacts {
  static const anna = DemoContact('anna', 'Anna', '+380991234561');
  static const maksym = DemoContact('maksym', 'Maksym', '+380991234562');
  static const olena = DemoContact('olena', 'Olena', '+380991234563');
  static const andrii = DemoContact('andrii', 'Andrii', '+380991234564');
  static const all = [anna, maksym, olena, andrii];
}

final demoChats = List<DemoChat>.unmodifiable([
  DemoChat(
    'saved',
    'Saved Messages',
    'Your notes, links and favourite messages',
    '12:42',
    '★',
    AppTheme.avatarBlue,
    pinned: true,
    sent: true,
  ),
  DemoChat(
    'study',
    'Study Group',
    'Olena: See you at the next lecture!',
    '12:35',
    'SG',
    AppTheme.avatarPurple,
    unread: 12,
    pinned: true,
    group: true,
  ),
  DemoChat(
    DemoContacts.anna.id,
    DemoContacts.anna.name,
    'Are we meeting at 3?',
    '12:28',
    'A',
    AppTheme.avatarPeach,
    unread: 2,
  ),
  DemoChat(
    DemoContacts.maksym.id,
    DemoContacts.maksym.name,
    'Thanks! I’ll check it out',
    '11:54',
    'M',
    AppTheme.avatarMint,
    sent: true,
  ),
  DemoChat(
    'flutter',
    'Flutter Community',
    'New resources for your next project',
    '11:20',
    'FC',
    AppTheme.avatarTeal,
    unread: 128,
    muted: true,
    group: true,
  ),
  DemoChat('olena', 'Olena', 'Photo', '10:46', 'O', AppTheme.avatarPink),
  DemoChat(
    'project',
    'Messenger Project',
    'You: Updated the home screen',
    'Yesterday',
    'MP',
    AppTheme.avatarSlate,
    muted: true,
    group: true,
    sent: true,
  ),
  DemoChat(
    DemoContacts.andrii.id,
    DemoContacts.andrii.name,
    'Sounds good 👍',
    'Yesterday',
    'A',
    AppTheme.avatarGold,
    sent: true,
  ),
]);

class DemoChat {
  const DemoChat(
    this.id,
    this.name,
    this.message,
    this.time,
    this.initials,
    this.color, {
    this.unread = 0,
    this.pinned = false,
    this.muted = false,
    this.group = false,
    this.sent = false,
  });
  final String id;
  final String name;
  final String message;
  final String time;
  final String initials;
  final Color color;
  final int unread;
  final bool pinned;
  final bool muted;
  final bool group;
  final bool sent;
}
