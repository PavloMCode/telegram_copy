import 'package:flutter/material.dart';

/// Единый источник палитры, цветовых ролей и темы приложения.
abstract final class AppTheme {
  /// Material 3 Dark Blue: светлая и тёмная схемы строятся из этого цвета.
  static const Color primaryColor = Color(0xFF1565C0);

  static const Color transparent = Colors.transparent;
  static const Color avatarForeground = Colors.white;
  static const Color attachmentForeground = Colors.white;

  static const Color avatarBlue = Color(0xFF5AA9E6);
  static const Color avatarPurple = Color(0xFF8B78C5);
  static const Color avatarPeach = Color(0xFFDF9671);
  static const Color avatarMint = Color(0xFF6DB6A1);
  static const Color avatarTeal = Color(0xFF58A5C9);
  static const Color avatarPink = Color(0xFFC580A5);
  static const Color avatarSlate = Color(0xFF7A9AC9);
  static const Color avatarGold = Color(0xFFB69B65);

  static const Color photoAttachment = Color(0xFF9C6ADE);
  static const Color videoAttachment = Color(0xFFE66B7A);
  static const Color fileAttachment = Color(0xFF00796B);
  static const Color readReceipt = Color(0xFF6BA587);
  static const Color messageShadow = Color(0x0A000000);

  /// system — тема устройства; light / dark — фиксированная тема.
  static const ThemeMode mode = ThemeMode.system;
  static final selectedMode = ValueNotifier<ThemeMode>(mode);
  static Future<void> Function(ThemeMode)? persistMode;
  static Future<void> setMode(ThemeMode value) async {
    await persistMode?.call(value);
    selectedMode.value = value;
  }

  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  /// Схема общей темы, унаследованной от MaterialApp.
  static ColorScheme colorsOf(BuildContext context) =>
      Theme.of(context).colorScheme;

  static ThemeData _build(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: 0.25),
        selectionHandleColor: colors.primary,
      ),
    );
  }
}

/// Дополнительные роли используют текущую светлую или тёмную схему.
/// Прозрачности и смешивание цветов меняются только здесь.
extension AppColorRoles on ColorScheme {
  Color get secondaryText => onSurfaceVariant.withValues(alpha: 0.8);
  Color get subtleDivider => outlineVariant.withValues(alpha: 0.5);
  Color get inputOutline => outlineVariant.withValues(alpha: 0.6);
  Color get cardShadow => shadow.withValues(alpha: 0.08);

  Color get onPrimaryMuted => onPrimary.withValues(alpha: 0.7);
  Color get onPrimarySubtle => onPrimary.withValues(alpha: 0.8);
  Color get searchFill => onPrimary.withValues(alpha: 0.12);
  Color get searchOutline => onPrimary.withValues(alpha: 0.4);

  Color get createActionBackground => createActionForeground.withValues(
    alpha: brightness == Brightness.dark ? 0.12 : 0.1,
  );
  Color get createActionForeground =>
      brightness == Brightness.dark ? primary : AppTheme.primaryColor;

  Color get outgoingMessageBackground =>
      Color.lerp(primaryContainer, surface, 0.2)!;
  Color get replyBackground => primary.withValues(alpha: 0.08);
  Color get reactionBackground => primary.withValues(alpha: 0.08);
  Color get messageTimestamp => onSurface.withValues(alpha: 0.75);
  Color get sentReceipt => onSurface.withValues(alpha: 0.65);
  Color get disabledBackground => onSurface.withValues(alpha: 0.12);
  Color get disabledForeground => onSurface.withValues(alpha: 0.38);

  // У кнопки отправки сохраняется исходный синий цвет.
  Color get sendButtonBackground => AppTheme.primaryColor;
}
