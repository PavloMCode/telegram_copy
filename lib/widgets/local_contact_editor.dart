import 'package:flutter/material.dart';
import '../data/demo_data.dart';

Future<DemoContact?> showLocalContactEditor(
  BuildContext context, {
  DemoContact? contact,
}) => showDialog<DemoContact>(
  context: context,
  builder: (_) => _ContactEditorDialog(contact: contact),
);

class _ContactEditorDialog extends StatefulWidget {
  const _ContactEditorDialog({this.contact});
  final DemoContact? contact;
  @override
  State<_ContactEditorDialog> createState() => _ContactEditorDialogState();
}

class _ContactEditorDialogState extends State<_ContactEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.contact?.name);
    _phone = TextEditingController(text: widget.contact?.phone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.contact == null ? 'Add contact' : 'Edit contact'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              maxLength: 128,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
              validator: (value) =>
                  RegExp(
                    r'^\+[1-9][0-9]{6,14}$',
                  ).hasMatch((value ?? '').replaceAll(RegExp(r'[ ()-]'), ''))
                  ? null
                  : 'Enter a phone number with country code',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              DemoContact(
                widget.contact?.id ??
                    'contact-${DateTime.now().microsecondsSinceEpoch}',
                _name.text.trim(),
                _phone.text.trim(),
              ),
            );
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
