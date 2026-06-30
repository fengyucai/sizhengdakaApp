import 'package:flutter/material.dart';

class ReviewTextDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final String? helperText;
  final String initialValue;
  final int maxLines;

  const ReviewTextDialog({
    super.key,
    required this.title,
    required this.hintText,
    this.helperText,
    this.initialValue = '',
    this.maxLines = 3,
  });

  @override
  State<ReviewTextDialog> createState() => _ReviewTextDialogState();
}

class _ReviewTextDialogState extends State<ReviewTextDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: widget.maxLines,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: widget.hintText,
          helperText: widget.helperText,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('提交'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
}
