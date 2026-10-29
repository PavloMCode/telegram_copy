import 'package:flutter/material.dart';
import '../navigation/main_section.dart';
import '../services/auth_api.dart';
import '../widgets/profile_scope.dart';
import '../widgets/group_scope.dart';
import '../services/local_group_store.dart';
import 'contacts_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _groups = LocalGroupStore(
      widget.profile ?? AuthProfile(widget.userName, widget.phone),
    );
    _groups.load();
  }

  @override
  void dispose() {
    _groups.dispose();
    super.dispose();
  }

  void _selectSection(MainSection section) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_section == section) return;
    setState(() => _section = section);
  }

  @override
  Widget build(BuildContext context) => GroupScope(
    store: _groups,
    child: ProfileScope(
      profile: widget.profile ?? AuthProfile(widget.userName, widget.phone),
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
  );
}
