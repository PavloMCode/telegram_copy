import 'package:flutter/material.dart';

/// One visible, labelled primary action for a form or a selection step.
class FormAction extends StatelessWidget {
  const FormAction({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        heightFactor: 1,
        child: SizedBox(
          width: 440,
          child: Tooltip(
            message: label,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            ),
          ),
        ),
      ),
    ),
  );
}
