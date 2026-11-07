import 'package:flutter/material.dart';

/// Shared gradients keep contrast and colour direction consistent across routes.
abstract final class AppGradients {
  static LinearGradient header(ColorScheme colors) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      colors.primaryContainer,
      colors.secondaryContainer,
      colors.tertiaryContainer,
    ],
    stops: const [0, .65, 1],
  );

  static LinearGradient background(ColorScheme colors, {Color? base}) {
    final surface = base ?? colors.surface;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(surface, colors.primaryContainer, .18)!,
        surface,
        Color.lerp(surface, colors.secondaryContainer, .14)!,
        Color.lerp(surface, colors.tertiaryContainer, .12)!,
      ],
      stops: const [0, .4, .75, 1],
    );
  }

  static LinearGradient panel(ColorScheme colors) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(colors.surfaceContainerLow, colors.primaryContainer, .18)!,
      colors.surfaceContainerLow,
      Color.lerp(colors.surfaceContainerLow, colors.secondaryContainer, .14)!,
    ],
  );

  static LinearGradient action(ColorScheme colors, {Color? base}) {
    if (base == colors.error || base == colors.errorContainer) {
      return LinearGradient(
        colors: [base!, Color.lerp(base, colors.error, .45)!],
      );
    }
    if ([
      colors.primaryContainer,
      colors.secondaryContainer,
      colors.tertiaryContainer,
    ].contains(base)) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          base!,
          Color.lerp(base, colors.primaryContainer, .30)!,
          Color.lerp(base, colors.secondaryContainer, .25)!,
        ],
      );
    }
    if (base != null && base != colors.primary) {
      return LinearGradient(
        colors: [base, Color.lerp(base, colors.primary, .25)!],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colors.primary,
        Color.lerp(colors.primary, colors.tertiary, .40)!,
        colors.secondary,
      ],
    );
  }

  /// Native Material buttons retain their own clipping, ink, focus and semantics.
  static Widget buttonLayer(
    BuildContext context,
    Set<WidgetState> states,
    Widget? child,
  ) {
    return _ButtonGradientLayer(
      disabled: states.contains(WidgetState.disabled),
      child: child,
    );
  }
}

class _ButtonGradientLayer extends StatelessWidget {
  const _ButtonGradientLayer({required this.disabled, this.child});
  final bool disabled;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    // Read the native button's resolved Material colour, including tonal and
    // destructive variants, without relying on protected component APIs.
    final material = context.findAncestorWidgetOfExactType<Material>();
    final base = material?.color;
    final shape = material?.shape ?? const StadiumBorder();
    if (disabled || base == null || base.a == 0) {
      return child ?? const SizedBox.shrink();
    }
    return Ink(
      decoration: ShapeDecoration(
        shape: shape,
        gradient: AppGradients.action(
          Theme.of(context).colorScheme,
          base: base,
        ),
      ),
      child: child,
    );
  }
}

/// Paints a gradient inside a native Material shape, without changing layout.
/// Used by cards, sheets, dialogs and FABs, which have no background builder.
class GradientBorder extends OutlinedBorder {
  const GradientBorder({
    required this.base,
    required this.gradient,
    super.side,
  });
  final OutlinedBorder base;
  final Gradient gradient;
  OutlinedBorder get _shape => base.copyWith(side: side);
  @override
  EdgeInsetsGeometry get dimensions => _shape.dimensions;
  @override
  bool get preferPaintInterior => true;
  @override
  GradientBorder copyWith({BorderSide? side}) =>
      GradientBorder(base: base, gradient: gradient, side: side ?? this.side);
  @override
  ShapeBorder scale(double t) => GradientBorder(
    base: base.scale(t) as OutlinedBorder,
    gradient: gradient,
    side: side.scale(t),
  );
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getOuterPath(rect, textDirection: textDirection);
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getInnerPath(rect, textDirection: textDirection);
  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    final path = getOuterPath(rect, textDirection: textDirection);
    if (paint.maskFilter != null) {
      canvas.drawPath(path, paint);
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.from(alpha: paint.color.a, red: 1, green: 1, blue: 1)
          ..shader = gradient.createShader(rect, textDirection: textDirection),
      );
    }
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) =>
      _shape.paint(canvas, rect, textDirection: textDirection);
}
