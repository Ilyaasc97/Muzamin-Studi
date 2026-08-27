import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../controllers/timing_session.dart';

class PreloadScriptDialog extends StatefulWidget {
  const PreloadScriptDialog({super.key, required this.session});

  final TimingSession session;

  @override
  State<PreloadScriptDialog> createState() => _PreloadScriptDialogState();
}

class _PreloadScriptDialogState extends State<PreloadScriptDialog> {
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.session.preloadedScript.isNotEmpty) {
      _textController.text = widget.session.preloadedScript.join('\n');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickTextFile() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(label: 'Text files', extensions: <String>['txt', 'csv']),
        ],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes, allowMalformed: true);
      setState(() {
        _textController.text = content;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = _textController.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_stories_rounded, color: scheme.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text('script.preload_title'.tr())),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickTextFile,
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: Text('script.import_txt'.tr()),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'script.line_count'.tr(namedArgs: {'count': lines.length.toString()}),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _textController,
              maxLines: 8,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'script.script_hint'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'script.auto_link_info'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.session.hasPreloadedScript)
          TextButton(
            onPressed: () {
              widget.session.clearPreloadedScript();
              Navigator.pop(context);
            },
            child: Text(
              'script.clear'.tr(),
              style: TextStyle(color: scheme.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: lines.isEmpty
              ? null
              : () {
                  widget.session.setPreloadedScript(lines);
                  Navigator.pop(context);
                },
          child: Text('script.load'.tr()),
        ),
      ],
    );
  }
}
