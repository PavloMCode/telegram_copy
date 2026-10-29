import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../models/local_group.dart';
import '../../services/group_media_files.dart';
import '../../services/local_account_store.dart';
import '../../services/local_group_store.dart';
import '../../services/stored_platform_file.dart';
import '../account_data_scope.dart';
import '../contact_scope.dart';
import '../group_scope.dart';
import '../confirmation_dialog.dart';

class ForwardAttachment {
  const ForwardAttachment(this.file, this.kind);
  final PlatformFile file;
  final GroupMediaKind kind;
}

class ForwardRecipient {
  const ForwardRecipient(
    this.id,
    this.name, {
    this.group = false,
    this.channel = false,
  });
  final String id;
  final String name;
  final bool group;
  final bool channel;
}

Future<void> sendForwardedMessage({
  required LocalAccountStore data,
  required LocalGroupStore? groups,
  required ForwardRecipient recipient,
  required String text,
  required String origin,
  required List<ForwardAttachment> attachments,
}) async {
  final copies = <GroupMedia>[];
  try {
    for (final attachment in attachments) {
      copies.add(
        await saveGroupMedia(
          data.accountId,
          recipient.id,
          attachment.file,
          attachment.file.name.toLowerCase().endsWith('.gif')
              ? GroupMediaKind.gif
              : attachment.kind,
        ),
      );
    }
    if (recipient.group) {
      if (groups == null) throw StateError('Group is unavailable');
      await groups.send(recipient.id, text, copies, forwardedFrom: origin);
    } else {
      final now = DateTime.now();
      await data.appendForwardedMessage(recipient.id, recipient.name, {
        'id': now.microsecondsSinceEpoch.toString(),
        'text': text,
        'time': now.toIso8601String(),
        'forwarded': origin,
        'files': [
          for (final copy in copies)
            {'name': copy.name, 'path': copy.path, 'size': copy.size},
        ],
      });
    }
  } catch (_) {
    for (final copy in copies) {
      try {
        await File(copy.path).delete();
      } catch (_) {
        /* Preserve the original send error. */
      }
    }
    rethrow;
  }
}

Future<void> forwardChatMessage(
  BuildContext context, {
  required String sourceId,
  required String origin,
  required String text,
  required List<ForwardAttachment> attachments,
  LocalGroupStore? fallbackGroups,
}) async {
  final data = AccountDataScope.maybeOf(context);
  final groups = GroupScope.maybeOf(context) ?? fallbackGroups;
  final contacts = ContactScope.maybeOf(context);
  try {
    if (data == null) throw StateError('Account is unavailable');
    await data.load();
    await groups?.load();
    await contacts?.load();
    if (data.error != null || groups?.loadError != null) {
      throw StateError('Could not load recipients');
    }
    if (!context.mounted) return;
    final recipients = <String, ForwardRecipient>{
      'saved': const ForwardRecipient('saved', 'Saved Messages'),
      for (final c in data.contacts) c.id: ForwardRecipient(c.id, c.name),
      for (final entry in data.conversations.entries)
        if (!data.isChatDeleted(entry.key) &&
            groups?.find(entry.key) == null &&
            data.contact(entry.key) == null &&
            entry.key != 'saved')
          entry.key: ForwardRecipient(
            entry.key,
            entry.value['name'] as String? ?? entry.key,
          ),
      for (final g in groups?.groups ?? <LocalGroup>[])
        if (!g.isChannel || g.canManage(groups!.userId))
          g.id: ForwardRecipient(
            g.id,
            g.name,
            group: true,
            channel: g.isChannel,
          ),
    };
    recipients.removeWhere(
      (id, recipient) => id == sourceId || contacts?.isBlocked(id) == true,
    );
    final recipient = await showModalBottomSheet<ForwardRecipient>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _ForwardPicker(recipients: recipients.values.toList()),
    );
    if (recipient == null || !context.mounted) return;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Forward message?',
      message: 'Send this message to ${recipient.name}?',
      confirmLabel: 'Forward',
      destructive: false,
    );
    if (!confirmed || !context.mounted) return;
    if (contacts?.isBlocked(recipient.id) == true) {
      throw StateError('Contact is blocked');
    }
    await sendForwardedMessage(
      data: data,
      groups: groups,
      recipient: recipient,
      text: text,
      origin: origin,
      attachments: attachments,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Forwarded to ${recipient.name}.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not forward this message. Please try again.'),
        ),
      );
    }
  }
}

ForwardAttachment forwardedGroupMedia(GroupMedia media) => ForwardAttachment(
  StoredPlatformFile(media.name, media.path, media.size),
  media.kind,
);

class _ForwardPicker extends StatefulWidget {
  const _ForwardPicker({required this.recipients});
  final List<ForwardRecipient> recipients;
  @override
  State<_ForwardPicker> createState() => _ForwardPickerState();
}

class _ForwardPickerState extends State<_ForwardPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final recipients = widget.recipients
        .where(
          (r) => r.name.toLowerCase().contains(_query.trim().toLowerCase()),
        )
        .toList();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            children: [
              Text(
                'Forward to…',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search recipients',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: recipients.isEmpty
                    ? const Center(child: Text('No recipients found'))
                    : ListView(
                        children: [
                          for (final r in recipients)
                            ListTile(
                              leading: Icon(
                                r.channel
                                    ? Icons.campaign_outlined
                                    : r.group
                                    ? Icons.group_outlined
                                    : Icons.person_outline,
                              ),
                              title: Text(r.name),
                              subtitle: Text(
                                r.channel
                                    ? 'Channel'
                                    : r.group
                                    ? 'Group'
                                    : 'Private chat',
                              ),
                              onTap: () => Navigator.pop(context, r),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
