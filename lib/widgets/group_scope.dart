import 'package:flutter/material.dart';
import '../services/local_group_store.dart';
import 'profile_scope.dart';

class GroupScope extends InheritedWidget {
  const GroupScope({super.key, required this.store, required super.child});
  final LocalGroupStore store;
  static LocalGroupStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GroupScope>()?.store;
  static Widget wrap(BuildContext context, Widget child) {
    final store = maybeOf(context);
    final content = ProfileScope(
      profile: ProfileScope.of(context),
      child: child,
    );
    return store == null ? content : GroupScope(store: store, child: content);
  }

  @override
  bool updateShouldNotify(GroupScope oldWidget) => oldWidget.store != store;
}
