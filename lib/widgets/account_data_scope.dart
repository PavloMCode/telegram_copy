import 'package:flutter/material.dart';
import '../services/local_account_store.dart';

class AccountDataScope extends InheritedNotifier<LocalAccountStore> {
  const AccountDataScope({
    super.key,
    required LocalAccountStore store,
    required super.child,
  }) : super(notifier: store);
  static LocalAccountStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountDataScope>()?.notifier;
  static Widget wrap(BuildContext context, Widget child) {
    final store = maybeOf(context);
    return store == null ? child : AccountDataScope(store: store, child: child);
  }
}
