import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ShortcutsHelp extends StatelessWidget {
  const ShortcutsHelp({super.key});

  static const List<(String, String)> _rowKeys = <(String, String)>[
    ('keyboard.space', 'keyboard.space_desc'),
    ('keyboard.enter', 'keyboard.enter_desc'),
    ('1 - 5', 'keyboard.switch_type_desc'),
    ('keyboard.arrow_right', 'keyboard.arrow_right_desc'),
    ('keyboard.arrow_left', 'keyboard.arrow_left_desc'),
    ('keyboard.arrow_up', 'keyboard.arrow_up_desc'),
    ('keyboard.arrow_down', 'keyboard.arrow_down_desc'),
    ('keyboard.escape', 'keyboard.escape_desc'),
    ('keyboard.ctrl_z', 'keyboard.ctrl_z_desc'),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text('keyboard.shortcuts_title'.tr()),
          children: <Widget>[
            for (final (String keysKey, String descKey) in _rowKeys)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 96,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color:
                                Theme.of(context).colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        keysKey.startsWith('keyboard.') ? keysKey.tr() : keysKey,
                        textDirection: ui.TextDirection.ltr,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(descKey.tr())),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
