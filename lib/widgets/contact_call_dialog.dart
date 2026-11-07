import 'gradient_surfaces.dart';
import 'package:flutter/material.dart';

Future<void> showContactCallDialog(BuildContext context, String name) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => GradientAlertDialog(
        icon: const Icon(Icons.call_outlined),
        title: Text('Call $name'),
        content: const Text(
          'Calls are not available in this frontend demo yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
