import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'chat_screen.dart';

// These contacts match the demo conversations on the home screen.
const _contacts = [
  (id: 'anna', name: 'Anna', status: 'last seen recently'),
  (id: 'maksym', name: 'Maksym', status: 'last seen recently'),
  (id: 'olena', name: 'Olena', status: 'last seen recently'),
  (id: 'andrii', name: 'Andrii', status: 'last seen recently'),
];

void _openConversation(BuildContext context, String id, String name) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => ChatScreen(chatId: id, chatName: name),
    ),
    (route) => route.isFirst,
  );
}

class NewChatScreen extends StatelessWidget {
  const NewChatScreen({super.key});

  @override
  Widget build(BuildContext context) => const _ContactPicker();
}

class NewGroupScreen extends StatelessWidget {
  const NewGroupScreen({super.key});

  @override
  Widget build(BuildContext context) => const _ContactPicker(group: true);
}

class _ContactPicker extends StatefulWidget {
  const _ContactPicker({this.group = false});

  final bool group;

  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  final _search = TextEditingController();
  final _selected = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final query = _search.text.trim().toLowerCase();
    final contacts = _contacts
        .where((contact) => contact.name.toLowerCase().contains(query))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group ? 'New group' : 'New message'),
        bottom: widget.group
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${_selected.length} members selected',
                    style: TextStyle(color: colors.onPrimary),
                  ),
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: widget.group
                      ? 'Who would you like to add?'
                      : 'Search contacts',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () => setState(_search.clear),
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            if (widget.group && _selected.isNotEmpty)
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final contact in _contacts)
                      if (_selected.contains(contact.id))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InputChip(
                            label: Text(contact.name),
                            onDeleted: () =>
                                setState(() => _selected.remove(contact.id)),
                          ),
                        ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  if (!widget.group && query.isEmpty) ...[
                    ListTile(
                      leading: Icon(
                        Icons.group_outlined,
                        color: colors.primary,
                      ),
                      title: const Text('New group'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const NewGroupScreen(),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.campaign_outlined,
                        color: colors.primary,
                      ),
                      title: const Text('New channel'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const NewChannelScreen(),
                        ),
                      ),
                    ),
                    const Divider(),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Text(
                      'Contacts',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (contacts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No contacts found')),
                    ),
                  for (final contact in contacts)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                        child: Text(contact.name.characters.first),
                      ),
                      title: Text(contact.name),
                      subtitle: Text(contact.status),
                      trailing: widget.group
                          ? Icon(
                              _selected.contains(contact.id)
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: _selected.contains(contact.id)
                                  ? colors.primary
                                  : colors.outline,
                            )
                          : null,
                      onTap: () {
                        if (widget.group) {
                          setState(() {
                            if (!_selected.add(contact.id)) {
                              _selected.remove(contact.id);
                            }
                          });
                        } else {
                          _openConversation(context, contact.id, contact.name);
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.group
          ? FloatingActionButton(
              tooltip: 'Next',
              onPressed: _selected.isEmpty
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              _ConversationDetails(members: List.of(_selected)),
                        ),
                      );
                    },
              backgroundColor: _selected.isEmpty
                  ? colors.surfaceContainerHighest
                  : colors.primary,
              foregroundColor: _selected.isEmpty
                  ? colors.onSurfaceVariant
                  : colors.onPrimary,
              child: const Icon(Icons.arrow_forward),
            )
          : null,
    );
  }
}

class NewChannelScreen extends StatelessWidget {
  const NewChannelScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const _ConversationDetails(channel: true);
}

class _ConversationDetails extends StatefulWidget {
  const _ConversationDetails({this.channel = false, this.members = const []});

  final bool channel;
  final List<String> members;

  @override
  State<_ConversationDetails> createState() => _ConversationDetailsState();
}

class _ConversationDetailsState extends State<_ConversationDetails> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  Uint8List? _photo;
  bool _picking = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final image = await decodeImageFromList(bytes);
      image.dispose();
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open photo. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _next() {
    if (!_form.currentState!.validate()) return;
    if (widget.channel) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => _ChannelTypeScreen(name: _name.text.trim()),
        ),
      );
    } else {
      _openConversation(
        context,
        'local-group-${DateTime.now().microsecondsSinceEpoch}',
        _name.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.channel ? 'New channel' : 'New group')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            children: [
              Center(
                child: Semantics(
                  button: true,
                  label: 'Choose photo',
                  child: InkWell(
                    onTap: _picking ? null : _pickPhoto,
                    customBorder: const CircleBorder(),
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.onPrimaryContainer,
                      backgroundImage: _photo == null
                          ? null
                          : MemoryImage(_photo!),
                      child: _picking
                          ? const CircularProgressIndicator()
                          : _photo == null
                          ? const Icon(Icons.add_a_photo_outlined, size: 32)
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _name,
                maxLength: 128,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: widget.channel ? 'Channel name' : 'Group name',
                ),
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
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.channel
                    ? 'You can provide an optional description for your channel. Subscribers will see it on the channel profile.'
                    : 'Give your group a name and a photo. You can change them later.',
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
              ),
              if (!widget.channel) ...[
                const SizedBox(height: 28),
                Text(
                  '${widget.members.length} members',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                for (final contact in _contacts)
                  if (widget.members.contains(contact.id))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Text(contact.name.characters.first),
                      ),
                      title: Text(contact.name),
                      subtitle: Text(contact.status),
                    ),
              ],
              const SizedBox(height: 24),
              Text(
                'Demo mode · This conversation opens locally. Details are not saved to a server.',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: widget.channel ? 'Next' : 'Create group',
        onPressed: _picking ? null : _next,
        child: Icon(widget.channel ? Icons.arrow_forward : Icons.check),
      ),
    );
  }
}

enum _ChannelType { public, private }

class _ChannelTypeScreen extends StatefulWidget {
  const _ChannelTypeScreen({required this.name});

  final String name;

  @override
  State<_ChannelTypeScreen> createState() => _ChannelTypeScreenState();
}

class _ChannelTypeScreenState extends State<_ChannelTypeScreen> {
  final _form = GlobalKey<FormState>();
  final _link = TextEditingController();
  _ChannelType _type = _ChannelType.public;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Channel type')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            children: [
              Text(
                'Channel type',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              for (final type in _ChannelType.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _type == type
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: _type == type ? colors.primary : colors.outline,
                  ),
                  title: Text(
                    type == _ChannelType.public
                        ? 'Public channel'
                        : 'Private channel',
                  ),
                  subtitle: Text(
                    type == _ChannelType.public
                        ? 'Anyone can find your channel in search and join.'
                        : 'People can join only if they are added or have an invite link.',
                  ),
                  onTap: () => setState(() => _type = type),
                ),
              const Divider(height: 32),
              if (_type == _ChannelType.public) ...[
                TextFormField(
                  controller: _link,
                  maxLength: 32,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Public link',
                    prefixText: 't.me/',
                  ),
                  validator: (value) =>
                      RegExp(
                        r'^[a-zA-Z][a-zA-Z0-9_]{4,31}$',
                      ).hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Use 5–32 letters, numbers or underscores. Start with a letter.',
                ),
                Text(
                  'This is a preview. Link availability is not checked and the address is not reserved.',
                  style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
                ),
              ] else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.link, color: colors.primary),
                  title: const Text('Invite link'),
                  subtitle: const Text(
                    'An invite link will be available when the server is connected.',
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create channel',
        onPressed: () {
          if (_type == _ChannelType.public && !_form.currentState!.validate()) {
            return;
          }
          _openConversation(
            context,
            'local-channel-${DateTime.now().microsecondsSinceEpoch}',
            widget.name,
          );
        },
        child: const Icon(Icons.check),
      ),
    );
  }
}
