import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../services/local_auth_api.dart';
import '../widgets/account_data_scope.dart';
import '../widgets/group_scope.dart';
import '../widgets/database_scope.dart';
import 'main_screen.dart';
import 'registration_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key, required this.api, required this.activeId});
  final LocalAuthApi api;
  final String activeId;
  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<({AuthProfile profile, String name, String phone})>? _accounts;
  String? _error;
  bool _busy = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
    }
  }

  Future<void> _load() async {
    final database = DatabaseScope.maybeOf(context);
    try {
      final profiles = await widget.api.signedInProfiles();
      final accounts = <({AuthProfile profile, String name, String phone})>[];
      for (final profile in profiles) {
        final details = await database?.get(profile.phone, 'profile', 'self');
        accounts.add((
          profile: profile,
          name: details?['name'] as String? ?? profile.name,
          phone: details?['phone'] as String? ?? profile.phone,
        ));
      }
      if (mounted) {
        setState(() {
          _accounts = accounts;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load accounts. Please try again.');
      }
    }
  }

  Future<void> _open({String? accountId}) async {
    if (_busy) return;
    final data = AccountDataScope.maybeOf(context);
    final groups = GroupScope.maybeOf(context);
    setState(() => _busy = true);
    try {
      await data?.flush();
      await groups?.flush();
      if (!mounted) return;
      if (accountId == null) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => RegistrationScreen(
              authApi: LocalAuthApi(),
              addingAccount: true,
            ),
          ),
        );
      } else {
        final profile = await widget.api.switchAccount(accountId);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => MainScreen(profile: profile, authApi: widget.api),
          ),
          (_) => false,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AuthException
                  ? error.message
                  : 'Could not switch account. Please try again.',
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
    appBar: AppBar(title: const Text('Accounts')),
    body: _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Try again')),
              ],
            ),
          )
        : _accounts == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              for (final account in _accounts!)
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(account.name),
                  subtitle: Text(account.phone),
                  selected: account.profile.phone == widget.activeId,
                  trailing: account.profile.phone == widget.activeId
                      ? const Icon(Icons.check_circle_outline)
                      : null,
                  onTap: _busy || account.profile.phone == widget.activeId
                      ? null
                      : () => _open(accountId: account.profile.phone),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: const Text('Add account'),
                onTap: _busy ? null : () => _open(),
              ),
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
  );
}
