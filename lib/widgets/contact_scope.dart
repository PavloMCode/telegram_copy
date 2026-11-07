import 'package:flutter/material.dart';
import '../services/local_contact_store.dart';

class ContactScope extends InheritedNotifier<LocalContactStore> {
  const ContactScope({
    super.key,
    required LocalContactStore store,
    required super.child,
  }) : super(notifier: store);
  static LocalContactStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ContactScope>()?.notifier;
  static Widget wrap(
    BuildContext context,
    Widget child, {
    LocalContactStore? fallback,
  }) {
    final store = maybeOf(context) ?? fallback;
    return store == null ? child : ContactScope(store: store, child: child);
  }
}
