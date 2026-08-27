import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../controllers/timing_session.dart';
import '../models/segment_type.dart';

class TypeSelectorChips extends StatelessWidget {
  const TypeSelectorChips({super.key, required this.session});

  final TimingSession session;

  void _showSetPageDialog(BuildContext context) {
    final controller = TextEditingController(
      text: session.activePage != null ? session.activePage.toString() : '',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_stories_rounded, size: 20),
            const SizedBox(width: 8),
            Text('edit.page_title'.tr()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'edit.page_number'.tr(),
                hintText: '10',
                prefixIcon: const Icon(Icons.menu_book_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              session.setActivePage(null);
              Navigator.pop(ctx);
            },
            child: Text('common.clear'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              session.setActivePage(parsed);
              Navigator.pop(ctx);
            },
            child: Text('settings.save'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final active = session.activeType;
        final activePage = session.activePage;

        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.category_rounded,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'segment_types.title'.tr(),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const Spacer(),

                    // محدد ومعدل رقم الصفحة السريع
                    InkWell(
                      onTap: () => _showSetPageDialog(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: activePage != null
                              ? scheme.primaryContainer.withValues(alpha: 0.5)
                              : scheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: activePage != null
                                ? scheme.primary.withValues(alpha: 0.5)
                                : scheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_stories_rounded,
                              size: 13,
                              color: activePage != null
                                  ? scheme.primary
                                  : Theme.of(context).hintColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              activePage != null
                                  ? '${'edit.page'.tr()}: $activePage'
                                  : 'edit.set_page'.tr(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: activePage != null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: activePage != null
                                    ? scheme.primary
                                    : Theme.of(context).hintColor,
                              ),
                            ),
                            if (activePage != null) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                iconSize: 13,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                tooltip: '+1',
                                icon: const Icon(Icons.add_rounded),
                                onPressed: () => session.incrementPage(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SegmentType.values.map((type) {
                    final isSelected = type == active;
                    final brightness = Theme.of(context).brightness;
                    final isLight = brightness == Brightness.light;
                    final color = type.colorFor(brightness);

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: InkWell(
                        onTap: () => session.setActiveType(type),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? type.bgBadgeFor(brightness)
                                : scheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? color
                                  : scheme.outlineVariant.withValues(alpha: isLight ? 0.6 : 0.35),
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color
                                      : scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${type.hotkeyNumber}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? (isLight ? Colors.white : Colors.black87)
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                type.icon,
                                size: 16,
                                color: isSelected ? color : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                type.nameKey.tr(),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected ? color : scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
