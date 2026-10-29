import 'package:flutter/material.dart';
import '../navigation/main_section.dart';
import '../theme/app_theme.dart';
import '../data/demo_data.dart';
import '../widgets/app_drawer.dart';
import '../widgets/search_app_bar.dart';
import 'contact_account_screen.dart';
import '../widgets/group_scope.dart';
import '../widgets/contact_call_dialog.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, required this.onSectionSelected});

  final ValueChanged<MainSection> onSectionSelected;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final query = _searchController.text.trim().toLowerCase();
    final contacts = DemoContacts.all
        .where(
          (contact) =>
              contact.name.toLowerCase().contains(query) ||
              contact.phone.contains(query),
        )
        .toList();
    return Scaffold(
      appBar: SearchAppBar(
        title: 'Contacts',
        hintText: 'Search contacts',
        controller: _searchController,
        onChanged: (_) => setState(() {}),
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
                          child: Text(
                            contact.name.characters.first.toUpperCase(),
                            style: TextStyle(
                              fontSize: 22,
                              color: colors.onPrimaryContainer,
                            ),
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
                          tooltip: 'Call ${contact.name}',
                          onPressed: () =>
                              showContactCallDialog(context, contact.name),
                          icon: Icon(
                            Icons.phone_outlined,
                            color: colors.primary,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupScope.wrap(
                                context,
                                ContactAccountScreen(contact: contact),
                              ),
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
}
