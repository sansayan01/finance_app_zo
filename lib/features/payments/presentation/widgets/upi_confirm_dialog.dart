import 'package:flutter/material.dart';

class UpiConfirmDialog extends StatefulWidget {
  final String title;
  final String? initialReason;

  const UpiConfirmDialog({
    super.key,
    required this.title,
    this.initialReason,
  });

  @override
  State<UpiConfirmDialog> createState() => _UpiConfirmDialogState();
}

class _UpiConfirmDialogState extends State<UpiConfirmDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialReason ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Enter reason...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
