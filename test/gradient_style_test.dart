import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_frontend/theme/app_theme.dart';
import 'package:telegram_frontend/widgets/gradient_surfaces.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

LinearGradient gradientIn(Finder button, WidgetTester tester) {
  final ink = tester.widget<Ink>(
    find
        .descendant(
          of: button,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Ink &&
                widget.decoration is ShapeDecoration &&
                (widget.decoration! as ShapeDecoration).gradient != null,
          ),
        )
        .first,
  );
  return (ink.decoration! as ShapeDecoration).gradient! as LinearGradient;
}

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'Gradients retain contrast, variants and disabled behaviour in ${theme.brightness}',
      (tester) async {
        var taps = 0;
        final colors = theme.colorScheme;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: AppScaffold(
              appBar: AppBar(
                flexibleSpace: const GradientHeader(),
                title: const Text('Actions'),
              ),
              body: Column(
                children: [
                  FilledButton(
                    key: const ValueKey('primary'),
                    onPressed: () => taps++,
                    child: const Text('Continue'),
                  ),
                  FilledButton.tonal(
                    key: const ValueKey('tonal'),
                    onPressed: () {},
                    child: const Text('Change photo'),
                  ),
                  const FilledButton(
                    key: ValueKey('disabled'),
                    onPressed: null,
                    child: Text('Unavailable'),
                  ),
                  FilledButton(
                    key: const ValueKey('danger'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.error,
                      foregroundColor: colors.onError,
                    ),
                    onPressed: () {},
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ),
          ),
        );
        final primary = gradientIn(
          find.byKey(const ValueKey('primary')),
          tester,
        );
        expect(primary.colors.first, colors.primary);
        expect(primary.colors.last, colors.secondary);
        for (final stop in primary.colors) {
          expect(contrast(stop, colors.onPrimary), greaterThanOrEqualTo(4.5));
        }
        final tonal = gradientIn(find.byKey(const ValueKey('tonal')), tester);
        expect(tonal.colors.first, colors.secondaryContainer);
        for (final stop in tonal.colors) {
          expect(
            contrast(stop, colors.onSecondaryContainer),
            greaterThanOrEqualTo(4.5),
          );
        }
        final danger = gradientIn(find.byKey(const ValueKey('danger')), tester);
        expect(danger.colors.first, colors.error);
        for (final stop in danger.colors) {
          expect(contrast(stop, colors.onError), greaterThanOrEqualTo(4.5));
        }
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('disabled')),
            matching: find.byType(Ink),
          ),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('primary')));
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
