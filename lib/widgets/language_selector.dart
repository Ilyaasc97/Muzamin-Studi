import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../config/app_localization.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale;
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<Locale>(
      tooltip: 'language.select_language'.tr(),
      initialValue: currentLocale,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language_rounded, size: 17, color: scheme.primary),
            const SizedBox(width: 6),
            Text(
              AppLocalization.getLanguageName(currentLocale.languageCode),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
      onSelected: (Locale newLocale) async {
        if (newLocale != currentLocale) {
          await context.setLocale(newLocale);
        }
      },
      itemBuilder: (BuildContext context) {
        return AppLocalization.supportedLocales.map((Locale locale) {
          final isSelected = locale == currentLocale;
          return PopupMenuItem<Locale>(
            value: locale,
            child: Row(
              children: [
                Text(
                  AppLocalization.getLanguageName(locale.languageCode),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? scheme.primary
                        : scheme.onSurface,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                ],
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
