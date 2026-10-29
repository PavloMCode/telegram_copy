import 'package:flutter/material.dart';
import '../navigation/main_section.dart';
import '../services/auth_api.dart';
import '../widgets/profile_scope.dart';
import '../widgets/group_scope.dart';
import '../services/local_group_store.dart';
import '../services/local_contact_store.dart';
import '../widgets/contact_scope.dart';
import '../widgets/database_scope.dart';
import '../widgets/account_data_scope.dart';
import '../services/local_account_store.dart';
import 'contacts_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import '../widgets/auth_session_scope.dart';

/// Main sections share one route; detail screens are pushed above it.
class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    this.userName = 'My Name',
    this.phone = '+380 99 123 45 67',
    this.authApi,
    this.profile,
  });

  final String userName;
  final String phone;
  final AuthApi? authApi;
  final AuthProfile? profile;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  MainSection _section = MainSection.chats;
  late final LocalGroupStore _groups;
  late final LocalContactStore _contacts;
  late final LocalAccountStore _data;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final profile =
        widget.profile ?? AuthProfile(widget.userName, widget.phone);
    final database = DatabaseScope.maybeOf(context);
    _data = LocalAccountStore(profile, database: database);
    _data.load();
    _groups = LocalGroupStore(
      profile,
      database: database,
      contactList: () => _data.contacts,
    );
    _groups.load();
    _contacts = LocalContactStore(
      accountId: profile.phone,
      database: database,
      onClear: _data.clearConversation,
    );
    _contacts.load();
  }

  @override
  void dispose() {
    _groups.dispose();
    _contacts.dispose();
    _data.dispose();
    super.dispose();
  }

  void _selectSection(MainSection section) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_section == section) return;
    setState(() => _section = section);
  }

  @override
  Widget build(BuildContext context) => AuthSessionScope(
    api: widget.authApi,
    child: AccountDataScope(
      store: _data,
      child: ContactScope(
        store: _contacts,
        child: GroupScope(
          store: _groups,
          child: ProfileScope(
            profile:
                widget.profile ?? AuthProfile(widget.userName, widget.phone),
            child: IndexedStack(
              index: _section.index,
              children: [
                for (final section in MainSection.values)
                  // Hidden sections must not duplicate the active section's FAB hero.
                  HeroMode(
                    enabled: _section == section,
                    child: switch (section) {
                      MainSection.chats => HomeScreen(
                        userName: widget.profile?.name ?? widget.userName,
                        phone: widget.profile?.phone ?? widget.phone,
                        authApi: widget.authApi,
                        onSectionSelected: _selectSection,
                      ),
                      MainSection.contacts => ContactsScreen(
                        onSectionSelected: _selectSection,
                      ),
                      MainSection.settings => SettingsScreen(
                        authApi: widget.authApi,
                        onSectionSelected: _selectSection,
                      ),
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
