import 'package:flutter/material.dart';
import '../services/local_database.dart';

class DatabaseScope extends InheritedWidget {
  const DatabaseScope({
    super.key,
    required this.database,
    required super.child,
  });
  final LocalDatabase? database;
  static LocalDatabase? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DatabaseScope>()?.database;
  @override
  bool updateShouldNotify(DatabaseScope oldWidget) =>
      oldWidget.database != database;
}
