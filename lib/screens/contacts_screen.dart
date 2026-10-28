import 'package:flutter/material.dart';
import '../navigation/main_section.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import 'contact_account_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, required this.onSectionSelected});

  final ValueChanged<MainSection> onSectionSelected;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  // Placeholder contacts until the address book is connected.
  static final _contacts = List.generate(
    5,
    (_) => (name: 'Name Surname', phone: '+1234567890'),
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final query = _searchController.text.trim().toLowerCase();
    final contacts = _contacts
        .where(
          (contact) =>
              contact.name.toLowerCase().contains(query) ||
              contact.phone.contains(query),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: _isSearching
            ? SizedBox(
                height: 42,
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  cursorColor: colors.onPrimary,
                  style: TextStyle(color: colors.onPrimary, fontSize: 16),
                  textAlignVertical: TextAlignVertical.center,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search contacts',
                    hintStyle: TextStyle(color: colors.onPrimaryMuted),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: colors.onPrimarySubtle,
                      size: 21,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Close search',
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.onPrimary,
                        size: 21,
                      ),
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        setState(() {
                          _searchController.clear();
                          _isSearching = false;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: colors.searchFill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: colors.searchOutline),
                    ),
                  ),
                ),
              )
            : const Text('Contacts'),
        actions: [
          if (!_isSearching)
            IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _isSearching = true),
            ),
        ],
      ),
      drawer: AppDrawer(
        selectedSection: MainSection.contacts,
        onSectionSelected: widget.onSectionSelected,
      ),
      body: Column(
        children: [
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Text(
                      'No contacts found',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(top: 8, bottom: 88),
                    itemCount: contacts.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 84,
                      endIndent: 16,
                      color: colors.subtleDivider,
                    ),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        horizontalTitleGap: 16,
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundColor: colors.primaryContainer,
                          child: Icon(
                            Icons.person,
                            size: 30,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          contact.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          contact.phone,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.secondaryText,
                          ),
                        ),
                        trailing: IconButton(
                          onPressed: () {},
                          icon: Icon(
                            Icons.phone_outlined,
                            color: colors.primary,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ContactAccountScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Contact actions',
        onPressed: () => _showContactActions(context),
        child: const Icon(Icons.more_vert),
      ),
    );
  }

  void _showContactActions(BuildContext context) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.colorsOf(context).surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final colors = AppTheme.colorsOf(sheetContext);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Row(
              children: [
                _contactAction(
                  'Add contact',
                  Icons.person_add_outlined,
                  colors.primary,
                  () {},
                ),
                _contactAction(
                  'Remove contact',
                  Icons.person_remove_outlined,
                  colors.onSurfaceVariant,
                  () {},
                ),
                _contactAction(
                  'Block contact',
                  Icons.person_off_outlined,
                  colors.error,
                  () {},
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _contactAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Expanded(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showChatBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final colors = AppTheme.colorsOf(context);
        return AlertDialog(
          title: const Text("Are you sure?"),
          content: const Text("You will block this user"),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Block"),
            ),
          ],
        );
      },
    );
  }
}
