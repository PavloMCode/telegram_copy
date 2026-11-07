import 'package:flutter/material.dart';
import '../theme/app_gradients.dart';

/// Each route owns its background, so transitions never reveal a previous page.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.scaffoldKey,
    this.appBar,
    this.body,
    this.drawer,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
  });
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? drawer;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: AppGradients.background(
        Theme.of(context).colorScheme,
        base: backgroundColor,
      ),
    ),
    child: Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.transparent,
      appBar: appBar,
      body: body,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    ),
  );
}

class GradientHeader extends StatelessWidget {
  const GradientHeader({super.key});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: AppGradients.header(Theme.of(context).colorScheme),
    ),
    child: const SizedBox.expand(),
  );
}

class GradientMark extends StatelessWidget {
  const GradientMark({super.key, required this.radius, required this.child});
  final double radius;
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: AppGradients.action(Theme.of(context).colorScheme),
    ),
    child: CircleAvatar(
      radius: radius,
      backgroundColor: Colors.transparent,
      child: child,
    ),
  );
}

/// Paint on the component's own Material, including its padding, without
/// changing the size, hit area, ink responses or native child layout.
class MaterialGradient extends StatefulWidget {
  const MaterialGradient({
    super.key,
    required this.gradient,
    required this.shape,
    required this.child,
    this.enabled = true,
  });
  final Gradient gradient;
  final ShapeBorder shape;
  final Widget child;
  final bool enabled;
  @override
  State<MaterialGradient> createState() => _MaterialGradientState();
}

class _MaterialGradientState extends State<MaterialGradient> {
  _GradientInkFeature? _feature;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didUpdateWidget(MaterialGradient oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  void _update() {
    _feature?.dispose();
    _feature = null;
    if (!widget.enabled) return;
    final controller = Material.of(context);
    if (controller is RenderBox) {
      _feature = _GradientInkFeature(
        controller: controller,
        referenceBox: controller as RenderBox,
        gradient: widget.gradient,
        shape: widget.shape,
        direction: Directionality.of(context),
        onRemoved: () => _feature = null,
      );
    }
  }

  @override
  void dispose() {
    _feature?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _GradientInkFeature extends InkFeature {
  _GradientInkFeature({
    required super.controller,
    required super.referenceBox,
    required this.gradient,
    required this.shape,
    required this.direction,
    super.onRemoved,
  }) {
    controller.addInkFeature(this);
  }
  final Gradient gradient;
  final ShapeBorder shape;
  final TextDirection direction;
  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    final rect = Offset.zero & referenceBox.size;
    canvas.save();
    canvas.transform(transform.storage);
    canvas.clipPath(shape.getOuterPath(rect, textDirection: direction));
    canvas.drawRect(
      rect,
      Paint()..shader = gradient.createShader(rect, textDirection: direction),
    );
    canvas.restore();
  }
}

class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.child,
    this.color,
    this.elevation,
    this.clipBehavior,
    this.shape,
  });
  final Widget child;
  final Color? color;
  final double? elevation;
  final Clip? clipBehavior;
  final ShapeBorder? shape;
  @override
  Widget build(BuildContext context) => Card(
    color: color,
    elevation: elevation,
    clipBehavior: clipBehavior ?? Clip.antiAlias,
    shape: shape,
    child: MaterialGradient(
      gradient: AppGradients.panel(Theme.of(context).colorScheme),
      shape:
          shape ??
          Theme.of(context).cardTheme.shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: child,
    ),
  );
}

class GradientAlertDialog extends StatelessWidget {
  const GradientAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.icon,
  });
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final Widget? icon;
  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: icon,
    title: MaterialGradient(
      gradient: AppGradients.panel(Theme.of(context).colorScheme),
      shape:
          Theme.of(context).dialogTheme.shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: title ?? const SizedBox.shrink(),
    ),
    content: content,
    actions: actions,
  );
}

class GradientFab extends StatelessWidget {
  const GradientFab({
    super.key,
    this.tooltip,
    required this.onPressed,
    this.child,
  }) : label = null,
       icon = null;
  const GradientFab.extended({
    super.key,
    this.tooltip,
    required this.onPressed,
    required this.label,
    this.icon,
  }) : child = null;
  final String? tooltip;
  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? label;
  final Widget? icon;
  @override
  Widget build(BuildContext context) {
    Widget decorate(Widget child) => onPressed == null
        ? child
        : MaterialGradient(
            gradient: AppGradients.action(Theme.of(context).colorScheme),
            shape:
                Theme.of(context).floatingActionButtonTheme.shape ??
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: child,
          );
    return label == null
        ? FloatingActionButton(
            tooltip: tooltip,
            onPressed: onPressed,
            child: decorate(child ?? const SizedBox.shrink()),
          )
        : FloatingActionButton.extended(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: icon,
            label: decorate(label!),
          );
  }
}

Future<T?> showGradientBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool? showDragHandle,
  bool useSafeArea = false,
  bool isScrollControlled = false,
  ShapeBorder? shape,
  Color? backgroundColor,
  BoxConstraints? constraints,
  bool isDismissible = true,
  bool enableDrag = true,
}) => showModalBottomSheet<T>(
  context: context,
  showDragHandle: showDragHandle,
  useSafeArea: useSafeArea,
  isScrollControlled: isScrollControlled,
  shape: shape,
  backgroundColor: backgroundColor,
  constraints: constraints,
  isDismissible: isDismissible,
  enableDrag: enableDrag,
  clipBehavior: Clip.antiAlias,
  builder: (sheetContext) => MaterialGradient(
    gradient: AppGradients.panel(Theme.of(sheetContext).colorScheme),
    shape:
        shape ??
        Theme.of(sheetContext).bottomSheetTheme.shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
    child: builder(sheetContext),
  ),
);
