import 'package:flutter/material.dart';
import 'app_gradients.dart';

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
    final colors =
        ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: brightness,
        ).copyWith(
          primary: brightness == Brightness.light
              ? primaryColor
              : const Color(0xFFA8C7FA),
          onPrimary: brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF062E62),
          primaryContainer: brightness == Brightness.light
              ? const Color(0xFFD8E8FF)
              : const Color(0xFF173F70),
          onPrimaryContainer: brightness == Brightness.light
              ? const Color(0xFF12375E)
              : const Color(0xFFD8E8FF),
          secondary: brightness == Brightness.light
              ? const Color(0xFF006B5E)
              : const Color(0xFF80D5C2),
          onSecondary: brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF00382F),
          secondaryContainer: brightness == Brightness.light
              ? const Color(0xFFD0F2E9)
              : const Color(0xFF164C42),
          onSecondaryContainer: brightness == Brightness.light
              ? const Color(0xFF064B3F)
              : const Color(0xFFB2F0DF),
          tertiary: brightness == Brightness.light
              ? const Color(0xFF7046A6)
              : const Color(0xFFD4B5FF),
          tertiaryContainer: brightness == Brightness.light
              ? const Color(0xFFEEDFFF)
              : const Color(0xFF493162),
          onTertiaryContainer: brightness == Brightness.light
              ? const Color(0xFF482272)
              : const Color(0xFFEEDFFF),
          surface: brightness == Brightness.light
              ? const Color(0xFFF3F6FB)
              : const Color(0xFF101820),
          surfaceContainerLowest: brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF151F2A),
          surfaceContainerLow: brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF1A2633),
          surfaceContainer: brightness == Brightness.light
              ? const Color(0xFFE9F0F8)
              : const Color(0xFF202E3D),
          surfaceContainerHigh: brightness == Brightness.light
              ? const Color(0xFFE0EAF7)
              : const Color(0xFF293A4D),
        );
    final text = ThemeData(
      useMaterial3: true,
      brightness: brightness,
    ).textTheme;
    final fieldShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.outline),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.surface,
      textTheme: text.copyWith(
        bodyLarge: text.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
        bodySmall: text.bodySmall?.copyWith(height: 1.4),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ).copyWith(backgroundBuilder: AppGradients.buttonLayer),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: const ButtonStyle(backgroundBuilder: AppGradients.buttonLayer),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: const ButtonStyle(backgroundBuilder: AppGradients.buttonLayer),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 1,
        shape: GradientBorder(
          base: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          gradient: AppGradients.action(colors),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: GradientBorder(
          base: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          gradient: AppGradients.panel(colors),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        elevation: 0,
        shape: GradientBorder(
          base: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          gradient: AppGradients.panel(colors),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainerLow,
        modalBackgroundColor: colors.surfaceContainerLow,
        showDragHandle: true,
        shape: GradientBorder(
          gradient: AppGradients.panel(colors),
          base: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: colors.surfaceContainerLow,
        indicatorColor: colors.secondaryContainer,
        indicatorShape: GradientBorder(
          base: const StadiumBorder(),
          gradient: AppGradients.header(colors),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surfaceContainerLow,
        indicatorColor: colors.secondaryContainer,
        useIndicator: true,
        indicatorShape: GradientBorder(
          base: const StadiumBorder(),
          gradient: AppGradients.header(colors),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
        elevation: const WidgetStatePropertyAll(0),
        textStyle: WidgetStatePropertyAll(
          text.bodyLarge?.copyWith(color: colors.onSurface),
        ),
        hintStyle: WidgetStatePropertyAll(
          text.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface,
        selectedColor: colors.secondaryContainer,
        side: BorderSide(color: colors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: fieldShape,
        enabledBorder: fieldShape,
        focusedBorder: fieldShape.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: fieldShape.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: fieldShape.copyWith(
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        errorMaxLines: 3,
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
  Color get secondaryText => onSurfaceVariant;
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

  Color get outgoingMessageBackground => primaryContainer;
  Color get replyBackground => primary.withValues(alpha: 0.08);
  Color get reactionBackground => primary.withValues(alpha: 0.08);
  Color get messageTimestamp => onSurface.withValues(alpha: 0.75);
  Color get sentReceipt => onSurface.withValues(alpha: 0.65);
  Color get disabledBackground => onSurface.withValues(alpha: 0.12);
  Color get disabledForeground => onSurface.withValues(alpha: 0.38);

  Color get sendButtonBackground => primary;
}
