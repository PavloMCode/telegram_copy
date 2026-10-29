import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Search presentation shared by the top-level lists. The caller owns the query.
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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  State<SearchAppBar> createState() => _SearchAppBarState();
}

class _SearchAppBarState extends State<SearchAppBar> {
  bool _searching = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _searching) _close();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _close() {
    if (!_searching) return;
    setState(() => _searching = false);
    _focusNode.unfocus();
    widget.controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 8,
      title: _searching
          ? SizedBox(
              height: 42,
              child: TextField(
                focusNode: _focusNode,
                controller: widget.controller,
                // Wait for the outside tap to finish so filtering changes do
                // not move a list item before its tap handler runs.
                onTapOutside: (_) {},
                onTapUpOutside: (_) => _focusNode.unfocus(),
                autofocus: true,
                cursorColor: colors.onPrimary,
                textAlignVertical: TextAlignVertical.center,
                textInputAction: TextInputAction.search,
                style: TextStyle(color: colors.onPrimary, fontSize: 16),
                onChanged: widget.onChanged,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(color: colors.onPrimaryMuted),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 21,
                    color: colors.onPrimarySubtle,
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Close search',
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.onPrimary,
                      size: 21,
                    ),
                    onPressed: _close,
                  ),
                  filled: true,
                  fillColor: colors.searchFill,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: colors.searchOutline),
                  ),
                ),
              ),
            )
          : Text(widget.title, style: widget.titleStyle),
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
}
