import '../widgets/gradient_surfaces.dart';
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
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

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
  String? _selectedChatId;
  Widget? _conversation;
  final _wideScaffold = GlobalKey<ScaffoldState>();

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 840;
                final split = constraints.maxWidth >= 1100;
                final sections = IndexedStack(
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
                            selectedChatId: split ? _selectedChatId : null,
                            onConversationSelected: split
                                ? (id, screen) {
                                    setState(() {
                                      _selectedChatId = id;
                                      _conversation = screen;
                                    });
                                  }
                                : null,
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
                );
                if (!wide) return sections;
                final colors = AppTheme.colorsOf(context);
                return AppScaffold(
                  scaffoldKey: _wideScaffold,
                  drawer: AppDrawer(
                    selectedSection: _section,
                    onSectionSelected: _selectSection,
                  ),
                  body: Row(
                    children: [
                      SafeArea(
                        child: NavigationRail(
                          selectedIndex: _section.index,
                          labelType: NavigationRailLabelType.all,
                          onDestinationSelected: (index) =>
                              _selectSection(MainSection.values[index]),
                          leading: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  backgroundColor: colors.primaryContainer,
                                  child: Text(
                                    (widget.profile?.name ?? widget.userName)
                                            .trim()
                                            .isEmpty
                                        ? '?'
                                        : (widget.profile?.name ??
                                                  widget.userName)
                                              .characters
                                              .first
                                              .toUpperCase(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                IconButton(
                                  tooltip: 'Open navigation menu',
                                  onPressed: () =>
                                      _wideScaffold.currentState?.openDrawer(),
                                  icon: const Icon(Icons.menu),
                                ),
                              ],
                            ),
                          ),
                          destinations: const [
                            NavigationRailDestination(
                              icon: Icon(Icons.chat_bubble_outline),
                              selectedIcon: Icon(Icons.chat_bubble),
                              label: Text('Chats'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.person_outline),
                              selectedIcon: Icon(Icons.person),
                              label: Text('Contacts'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.settings_outlined),
                              selectedIcon: Icon(Icons.settings),
                              label: Text('Settings'),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: split && _section == MainSection.chats
                            ? Row(
                                children: [
                                  SizedBox(width: 360, child: sections),
                                  const VerticalDivider(width: 1),
                                  Expanded(
                                    child: PopScope(
                                      canPop: _conversation == null,
                                      onPopInvokedWithResult: (didPop, result) {
                                        if (!didPop) {
                                          setState(() {
                                            _conversation = null;
                                            _selectedChatId = null;
                                          });
                                        }
                                      },
                                      child: Navigator(
                                        pages: [
                                          MaterialPage<void>(
                                            key: const ValueKey(
                                              'conversation-placeholder',
                                            ),
                                            child: AppScaffold(
                                              body: Center(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.forum_outlined,
                                                      size: 56,
                                                      color: colors.primary,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'Select a conversation',
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.titleLarge,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    const Text(
                                                      'Your messages will appear here',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (_conversation != null)
                                            MaterialPage<void>(
                                              key: ValueKey(_selectedChatId),
                                              child: _conversation!,
                                            ),
                                        ],
                                        onDidRemovePage: (page) {
                                          if (page.key ==
                                              ValueKey(_selectedChatId)) {
                                            setState(() {
                                              _conversation = null;
                                              _selectedChatId = null;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : sections,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
