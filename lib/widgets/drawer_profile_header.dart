import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'profile_scope.dart';

/// Shared, adaptive profile header for every main section.
class DrawerProfileHeader extends StatelessWidget {
  const DrawerProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final profile = ProfileScope.of(context);
    final dark = colors.brightness == Brightness.dark;
    final initials = profile.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            Color.lerp(colors.primary, colors.primaryContainer, 0.22)!,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 164),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: dark
                        ? 'Switch to light theme'
                        : 'Switch to dark theme',
                    style: IconButton.styleFrom(
                      backgroundColor: colors.onPrimary.withValues(alpha: 0.12),
                      foregroundColor: colors.onPrimary,
                      minimumSize: const Size(44, 44),
                      shape: const CircleBorder(),
                    ),
                    onPressed: () => AppTheme.selectedMode.value = dark
                        ? ThemeMode.light
                        : ThemeMode.dark,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        key: ValueKey(dark),
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.onPrimary.withValues(alpha: 0.28),
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: colors.primaryContainer,
                        child: initials.isEmpty
                            ? Icon(
                                Icons.person_outline_rounded,
                                size: 32,
                                color: colors.onPrimaryContainer,
                              )
                            : Text(
                                initials,
                                style: TextStyle(
                                  color: colors.onPrimaryContainer,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                              color: colors.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            profile.phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.3,
                              color: colors.onPrimary.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
