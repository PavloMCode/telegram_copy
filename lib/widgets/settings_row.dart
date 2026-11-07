import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_gradients.dart';
import 'gradient_surfaces.dart';

/// Shared settings row: its height is a minimum and grows with text scaling.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.showChevron = false,
    this.height = 72,
    this.horizontalPadding = 16,
    this.card = true,
    this.switchValue,
    this.onSwitchChanged,
    this.switchKey,
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
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final text = Theme.of(context).textTheme;
    final (tint, ink) = switch (icon) {
      Icons.security_outlined ||
      Icons.notifications_outlined ||
      Icons.notifications ||
      Icons.volume_up_outlined ||
      Icons.vibration => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      Icons.lock_outline ||
      Icons.block_outlined ||
      Icons.edit_notifications ||
      Icons.manage_accounts_outlined => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      _ => (colors.primaryContainer, colors.onPrimaryContainer),
    };
    final leading = CircleAvatar(
      radius: 18,
      backgroundColor: tint,
      child: Icon(icon, size: 20, color: ink),
    );
    final label = Text(title, style: text.titleSmall);
    final description = Text(
      subtitle,
      style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
    );
    final padding = EdgeInsets.symmetric(
      horizontal: horizontalPadding,
      vertical: 10,
    );
    return Material(
      color: card ? colors.surfaceContainerLow : Colors.transparent,
      shape: card
          ? GradientBorder(
              base: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              gradient: AppGradients.panel(colors),
            )
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: MaterialGradient(
        enabled: card,
        gradient: AppGradients.panel(colors),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: switchValue != null
              ? SwitchListTile(
                  key: switchKey,
                  value: switchValue!,
                  onChanged: onSwitchChanged,
                  contentPadding: padding,
                  secondary: leading,
                  title: label,
                  subtitle: description,
                )
              : ListTile(
                  contentPadding: padding,
                  minLeadingWidth: 36,
                  horizontalTitleGap: 16,
                  leading: leading,
                  title: label,
                  subtitle: description,
                  trailing:
                      trailing ??
                      (showChevron
                          ? Icon(
                              Icons.chevron_right,
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
