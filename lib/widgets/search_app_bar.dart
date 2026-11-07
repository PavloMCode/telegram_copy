import 'gradient_surfaces.dart';
import 'package:flutter/material.dart';

/// Shared search presentation. Losing focus never clears the caller's query.
class SearchAppBar extends StatefulWidget implements PreferredSizeWidget {
  const SearchAppBar({
    super.key,
    required this.title,
    required this.hintText,
    required this.controller,
    required this.onChanged,
    this.titleStyle,
  });
  final String title;
  final String hintText;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextStyle? titleStyle;
  @override
  Size get preferredSize => const Size.fromHeight(72);
  @override
  State<SearchAppBar> createState() => _SearchAppBarState();
}

class _SearchAppBarState extends State<SearchAppBar> {
  final _focusNode = FocusNode();
  bool _searching = false;
  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _close() {
    _focusNode.unfocus();
    widget.controller.clear();
    widget.onChanged('');
    setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) => AppBar(
    flexibleSpace: const GradientHeader(),
    toolbarHeight: 72,
    titleSpacing: 8,
    leading: _searching
        ? IconButton(
            tooltip: 'Close search',
            icon: const Icon(Icons.arrow_back),
            onPressed: _close,
          )
        : null,
    title: _searching
        ? SearchBar(
            controller: widget.controller,
            focusNode: _focusNode,
            autoFocus: true,
            hintText: widget.hintText,
            constraints: const BoxConstraints(minHeight: 48),
            onTapOutside: (_) => _focusNode.unfocus(),
            onChanged: widget.onChanged,
            trailing: [
              IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close),
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged('');
                  _focusNode.requestFocus();
                },
              ),
            ],
          )
        : Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
    actions: [
      if (!_searching)
        IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search),
          onPressed: () => setState(() => _searching = true),
        ),
    ],
  );
}
