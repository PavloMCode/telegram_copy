import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/local_group.dart';
import '../services/local_group_store.dart';
import '../services/group_media_files.dart';
import '../services/profile_photo_picker.dart';
import '../data/demo_data.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/group_media_tile.dart';

class GroupDetailsScreen extends StatefulWidget {
  const GroupDetailsScreen({
    super.key,
    required this.store,
    required this.groupId,
  });
  final LocalGroupStore store;
  final String groupId;
  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  bool _busy = false;
  GroupMediaKind? _filter;

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is GroupException
              ? error.message
              : 'Could not save locally. Please try again.',
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(LocalGroup group) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _GroupEditor(store: widget.store, groupId: group.id),
      ),
    );
  }

  Future<void> _add(LocalGroup group) async {
    final candidates = (widget.store.contactList?.call() ?? DemoContacts.all)
        .where((c) => group.roleOf(c.id) == null)
        .toList();
    final selected = <String>{};
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, update) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Add members',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              if (candidates.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('All available contacts are already members.'),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final contact in candidates)
                      CheckboxListTile(
                        title: Text(contact.name),
                        subtitle: Text(contact.phone),
                        value: selected.contains(contact.id),
                        onChanged: (value) => update(() {
                          if (value == true) {
                            selected.add(contact.id);
                          } else {
                            selected.remove(contact.id);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(sheetContext, selected.toList()),
                  child: const Text('Add selected members'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _run(() => widget.store.addMembers(group.id, result));
  }

  Future<void> _memberActions(LocalGroup group, GroupMember member) async {
    if (member.id == widget.store.userId ||
        !group.canManage(widget.store.userId)) {
      return;
    }
    final owner = group.roleOf(widget.store.userId) == GroupRole.owner;
    if (member.role == GroupRole.owner ||
        !owner && member.role == GroupRole.admin) {
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                member.name,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            if (owner) ...[
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(
                  member.role == GroupRole.admin
                      ? 'Remove admin role'
                      : 'Make admin',
                ),
                onTap: () => Navigator.pop(sheetContext, 'role'),
              ),
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('Transfer ownership'),
                onTap: () => Navigator.pop(sheetContext, 'owner'),
              ),
            ],
            ListTile(
              leading: Icon(
                Icons.person_remove_outlined,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: const Text('Remove member'),
              onTap: () => Navigator.pop(sheetContext, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final confirmed = await showConfirmationDialog(
      context,
      title: action == 'remove'
          ? 'Remove member?'
          : action == 'owner'
          ? 'Transfer ownership?'
          : 'Change role?',
      message: action == 'owner'
          ? '${member.name} will become the owner. You will remain an administrator.'
          : action == 'remove'
          ? 'Remove ${member.name} from this group?'
          : 'Change the administrator role for ${member.name}?',
      confirmLabel: action == 'remove' ? 'Remove' : 'Confirm',
      destructive: action != 'role',
    );
    if (!mounted || !confirmed) return;
    await _run(
      () => action == 'remove'
          ? widget.store.removeMember(group.id, member.id)
          : widget.store.setRole(
              group.id,
              member.id,
              action == 'owner'
                  ? GroupRole.owner
                  : member.role == GroupRole.admin
                  ? GroupRole.member
                  : GroupRole.admin,
            ),
    );
  }

  Future<void> _leaveOrDelete(LocalGroup group, {required bool delete}) async {
    if (_busy) return;
    if (!delete && group.roleOf(widget.store.userId) == GroupRole.owner) {
      _error(
        const GroupException(
          'Transfer ownership to another member before leaving, or delete the group.',
        ),
      );
      return;
    }
    final confirmed = await showConfirmationDialog(
      context,
      title: delete ? 'Delete group?' : 'Leave group?',
      message: delete
          ? 'This local group, its messages and saved media will be deleted from this device.'
          : 'This group and its local history will be removed from your chat list.',
      confirmLabel: delete ? 'Delete group' : 'Leave group',
    );
    if (!mounted || !confirmed) return;
    await _run(() async {
      if (delete) {
        await widget.store.delete(group.id);
      } else {
        await widget.store.leave(group.id);
      }
      if (mounted) Navigator.pop(context);
      // File cleanup must not keep a deleted group's route open.
      unawaited(
        removeGroupMedia(
          widget.store.userId,
          group.id,
        ).catchError((Object _) {}),
      );
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final group = widget.store.find(widget.groupId);
      if (group == null) {
        return Scaffold(appBar: AppBar(title: const Text('Group settings')));
      }
      final colors = Theme.of(context).colorScheme;
      final manage = group.canManage(widget.store.userId);
      final owner = group.roleOf(widget.store.userId) == GroupRole.owner;
      final media = group.media
          .where((item) => _filter == null || item.kind == _filter)
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: const Text('Group settings'),
          actions: [
            if (manage)
              IconButton(
                tooltip: 'Edit group',
                onPressed: _busy ? null : () => _edit(group),
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundImage: group.photo == null
                    ? null
                    : MemoryImage(group.photo!),
                child: group.photo == null
                    ? const Icon(Icons.group_outlined, size: 40)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              group.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              '${group.members.length} members · ${group.roleOf(widget.store.userId)!.name}',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            if (group.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(group.description),
              ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Members',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (manage)
                  TextButton.icon(
                    onPressed: _busy ? null : () => _add(group),
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Add members'),
                  ),
              ],
            ),
            for (final member in group.members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(
                    member.name.isEmpty
                        ? '?'
                        : member.name.characters.first.toUpperCase(),
                  ),
                ),
                title: Text(
                  member.id == widget.store.userId
                      ? '${member.name} (you)'
                      : member.name,
                ),
                subtitle: Text(member.role.name),
                trailing:
                    manage &&
                        member.id != widget.store.userId &&
                        member.role != GroupRole.owner &&
                        (owner || member.role == GroupRole.member)
                    ? IconButton(
                        tooltip: 'Manage ${member.name}',
                        icon: const Icon(Icons.more_vert),
                        onPressed: _busy
                            ? null
                            : () => _memberActions(group, member),
                      )
                    : null,
              ),
            const Divider(height: 32),
            Text(
              'Shared media',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                for (final (kind, label) in [
                  (GroupMediaKind.photo, 'Photos'),
                  (GroupMediaKind.video, 'Videos'),
                  (GroupMediaKind.voice, 'Voice'),
                  (GroupMediaKind.file, 'Files'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _filter == kind,
                    onSelected: (_) => setState(() => _filter = kind),
                  ),
              ],
            ),
            if (media.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No saved media yet.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            for (final item in media) GroupMediaTile(media: item),
            const Divider(height: 32),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _leaveOrDelete(group, delete: false),
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Leave group'),
            ),
            if (owner)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  ),
                  onPressed: _busy
                      ? null
                      : () => _leaveOrDelete(group, delete: true),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete group'),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _GroupEditor extends StatefulWidget {
  const _GroupEditor({required this.store, required this.groupId});
  final LocalGroupStore store;
  final String groupId;
  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  Uint8List? _photo;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final group = widget.store.find(widget.groupId)!;
    _name = TextEditingController(text: group.name);
    _description = TextEditingController(text: group.description);
    _photo = group.photo;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _busy = true);
    try {
      final photo = await pickProfilePhoto();
      if (mounted && photo != null) setState(() => _photo = photo);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open photo.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.store.update(
        widget.groupId,
        name: _name.text,
        description: _description.text,
        photo: _photo,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is GroupException
                  ? error.message
                  : 'Could not save the group.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit group')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundImage: _photo == null ? null : MemoryImage(_photo!),
              child: _photo == null
                  ? const Icon(Icons.group_outlined, size: 40)
                  : null,
            ),
          ),
          TextButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Change group photo'),
          ),
          if (_photo != null)
            TextButton(
              onPressed: _busy ? null : () => setState(() => _photo = null),
              child: const Text('Remove photo'),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            maxLength: 128,
            decoration: const InputDecoration(labelText: 'Group name'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Please enter a name'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _description,
            minLines: 2,
            maxLines: 4,
            maxLength: 255,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save changes'),
          ),
        ],
      ),
    ),
  );
}
