import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Common row for settings, notification preferences and exceptions.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.showChevron = false,
    this.height = 64,
    this.horizontalPadding = 16,
    this.card = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;
  final double height;
  final double horizontalPadding;
  final bool card;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: card
            ? [
                BoxShadow(
                  color: colors.cardShadow,
                  blurRadius: 2,
                  spreadRadius: -1,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Material(
        color: card ? colors.surfaceContainerLow : AppTheme.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: height,
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            minLeadingWidth: 36,
            horizontalTitleGap: 16,
            minTileHeight: height,
            minVerticalPadding: 0,
            visualDensity: VisualDensity.standard,
            titleAlignment: ListTileTitleAlignment.center,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: colors.primaryContainer,
              child: Icon(icon, size: 20, color: colors.onPrimaryContainer),
            ),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
            subtitle: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                color: colors.secondaryText,
              ),
            ),
            trailing:
                trailing ??
                (showChevron
                    ? Icon(
                        Icons.chevron_right,
                        size: 22,
                        color: colors.onSurfaceVariant,
                      )
                    : null),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
