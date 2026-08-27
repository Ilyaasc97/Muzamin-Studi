import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/timing_entry.dart';

class SegmentEditDialog extends StatefulWidget {
  const SegmentEditDialog({super.key, required this.entry});

  final TimingEntry entry;

  @override
  State<SegmentEditDialog> createState() => _SegmentEditDialogState();
}

class _SegmentEditDialogState extends State<SegmentEditDialog> {
  late TextEditingController _numberController;
  late TextEditingController _pageController;
  late TextEditingController _labelController;
  late TextEditingController _arabicTextController;
  late SegmentType _selectedType;

  @override
  void initState() {
    super.initState();
    _numberController =
        TextEditingController(text: widget.entry.verseNumber.toString());
    _pageController = TextEditingController(
      text: widget.entry.page != null ? widget.entry.page.toString() : '',
    );
    _labelController = TextEditingController(text: widget.entry.label ?? '');
    _arabicTextController =
        TextEditingController(text: widget.entry.textArabic ?? '');
    _selectedType = widget.entry.type;
  }

  @override
  void dispose() {
    _numberController.dispose();
    _pageController.dispose();
    _labelController.dispose();
    _arabicTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit_rounded, color: _selectedType.color, size: 20),
          const SizedBox(width: 8),
          Text('edit.title'.tr()),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // اختيار النوع
              Text(
                'edit.type'.tr(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: SegmentType.values.map((type) {
                  final isSelected = type == _selectedType;
                  return ChoiceChip(
                    label: Text(type.nameKey.tr()),
                    avatar: Icon(type.icon, size: 14, color: type.color),
                    selected: isSelected,
                    selectedColor: type.color.withValues(alpha: 0.25),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedType = type);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // الرقم التسلسلي ورقم الصفحة
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _numberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'edit.number'.tr(),
                        prefixIcon: const Icon(Icons.numbers_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _pageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'edit.page_number'.tr(),
                        hintText: '10',
                        prefixIcon: const Icon(Icons.auto_stories_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // العنوان / الوصف
              TextField(
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: 'edit.label'.tr(),
                  hintText: 'edit.label_hint'.tr(),
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 12),

              // النص العربي
              TextField(
                controller: _arabicTextController,
                maxLines: 3,
                textAlign: TextAlign.center,
                textDirection: ui.TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: 17,
                  height: 1.65,
                ),
                decoration: InputDecoration(
                  labelText: 'edit.text_arabic'.tr(),
                  hintText: 'edit.text_arabic_hint'.tr(),
                  prefixIcon: const Icon(Icons.menu_book_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () {
            final parsedNum =
                int.tryParse(_numberController.text.trim()) ?? widget.entry.verseNumber;
            final parsedPage = int.tryParse(_pageController.text.trim());
            final updated = widget.entry.copyWith(
              verseNumber: parsedNum,
              page: parsedPage,
              type: _selectedType,
              label: _labelController.text.trim().isEmpty
                  ? null
                  : _labelController.text.trim(),
              textArabic: _arabicTextController.text.trim().isEmpty
                  ? null
                  : _arabicTextController.text.trim(),
            );
            Navigator.pop(context, updated);
          },
          child: Text('settings.save'.tr()),
        ),
      ],
    );
  }
}
