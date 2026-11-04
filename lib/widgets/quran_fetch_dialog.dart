import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../controllers/timing_session.dart';
import '../models/segment_type.dart';
import '../services/quran_api_service.dart';
import '../services/quran_font_service.dart';

class QuranFetchDialog extends StatefulWidget {
  const QuranFetchDialog({super.key, required this.session});

  final TimingSession session;

  @override
  State<QuranFetchDialog> createState() => _QuranFetchDialogState();
}

class _QuranFetchDialogState extends State<QuranFetchDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static int _lastFromSurahNumber = 1;
  static int _lastToSurahNumber = 1;

  // Tab 1: By Surah & Range
  late SurahInfo _fromSurah;
  late SurahInfo _toSurah;
  late TextEditingController _fromVerseController;
  late TextEditingController _toVerseController;

  // Tab 2: By Page
  late TextEditingController _pageController;

  bool _loading = false;
  String? _error;
  List<FetchedVerse> _fetchedVerses = [];

  @override
  void initState() {
    super.initState();
    _fromSurah = QuranApiService.getSurahByNumber(_lastFromSurahNumber) ?? QuranApiService.surahs[0];
    _toSurah = QuranApiService.getSurahByNumber(_lastToSurahNumber) ?? QuranApiService.surahs[0];
    _tabController = TabController(length: 2, vsync: this);
    _fromVerseController = TextEditingController(text: '1');
    _toVerseController = TextEditingController(text: '${_toSurah.totalVerses}');
    _pageController = TextEditingController(text: '${widget.session.activePage ?? 1}');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fromVerseController.dispose();
    _toVerseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchByRange() async {
    final fromVerse = int.tryParse(_fromVerseController.text.trim()) ?? 1;
    final toVerse = int.tryParse(_toVerseController.text.trim()) ?? _toSurah.totalVerses;

    if (_toSurah.number < _fromSurah.number) {
      setState(() => _error = 'quran.error_surah_order'.tr());
      return;
    }

    if (fromVerse < 1 || fromVerse > _fromSurah.totalVerses) {
      setState(() => _error = 'quran.error_from_verse'.tr(namedArgs: {'max': '${_fromSurah.totalVerses}'}));
      return;
    }

    if (toVerse < 1 || toVerse > _toSurah.totalVerses) {
      setState(() => _error = 'quran.error_to_verse'.tr(namedArgs: {'max': '${_toSurah.totalVerses}'}));
      return;
    }

    if (_fromSurah.number == _toSurah.number && toVerse < fromVerse) {
      setState(() => _error = 'quran.error_verse_order'.tr());
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _fetchedVerses = [];
    });

    try {
      final results = await QuranApiService.instance.fetchVersesByRange(
        fromSurahNumber: _fromSurah.number,
        fromVerse: fromVerse,
        toSurahNumber: _toSurah.number,
        toVerse: toVerse,
      );
      setState(() {
        _lastFromSurahNumber = _fromSurah.number;
        _lastToSurahNumber = _toSurah.number;
        _fetchedVerses = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'تعذر جلب الآيات: $e';
        _loading = false;
      });
    }
  }

  Future<void> _fetchByPage() async {
    final page = int.tryParse(_pageController.text.trim()) ?? 1;
    if (page < 1 || page > 604) {
      setState(() => _error = 'رقم الصفحة يجب أن يكون بين 1 و 604');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _fetchedVerses = [];
    });

    try {
      final results = await QuranApiService.instance.fetchVersesByPage(page);
      setState(() {
        _fetchedVerses = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'تعذر جلب صفحة المصحف: $e';
        _loading = false;
      });
    }
  }

  void _applyToSession() {
    if (_fetchedVerses.isEmpty) return;

    // تلقيم الآيات بكامل بياناتها (الصفحات، الخطوط، أرقام الآيات) إلى الجلسة
    widget.session.setPreloadedVerses(_fetchedVerses);
    widget.session.setActiveType(SegmentType.quran);

    Navigator.of(context).pop(_fetchedVerses.length);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 820,
        height: 620,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // العنوان
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.cloud_download_rounded, color: scheme.onPrimaryContainer, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'quran.auto_fetch_title'.tr(),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'quran.auto_fetch_subtitle'.tr(),
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // التبويبات
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  text: 'quran.tab_by_surah'.tr(),
                ),
                Tab(
                  icon: const Icon(Icons.auto_stories_rounded, size: 18),
                  text: 'quran.tab_by_page'.tr(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // منطقة الإدخال حسب التبويب
            SizedBox(
              height: 74,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // تبويب حسب السورة ونطاق الآيات
                  Row(
                    children: [
                      // من سورة
                      Expanded(
                        flex: 5,
                        child: _SurahSearchField(
                          key: ValueKey('from_surah_${_fromSurah.number}'),
                          label: 'quran.from_surah'.tr(),
                          selectedSurah: _fromSurah,
                          onSelected: (s) {
                            setState(() {
                              _fromSurah = s;
                              _fromVerseController.text = '1';
                              if (_toSurah.number < s.number) {
                                _toSurah = s;
                                _toVerseController.text = '${s.totalVerses}';
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      // من آية
                      SizedBox(
                        width: 70,
                        child: TextFormField(
                          controller: _fromVerseController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: 'quran.from_verse'.tr(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
                      ),
                      // إلى سورة
                      Expanded(
                        flex: 5,
                        child: _SurahSearchField(
                          key: ValueKey('to_surah_${_toSurah.number}'),
                          label: 'quran.to_surah'.tr(),
                          selectedSurah: _toSurah,
                          onSelected: (s) {
                            setState(() {
                              _toSurah = s;
                              if (s.number < _fromSurah.number) {
                                _fromSurah = s;
                                _fromVerseController.text = '1';
                              }
                              _toVerseController.text = '${s.totalVerses}';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      // إلى آية
                      SizedBox(
                        width: 70,
                        child: TextFormField(
                          controller: _toVerseController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: 'quran.to_verse'.tr(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // زر جلب الآيات
                      FilledButton.icon(
                        onPressed: _loading ? null : _fetchByRange,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        icon: _loading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.search_rounded, size: 18),
                        label: Text('quran.fetch_btn'.tr()),
                      ),
                    ],
                  ),

                  // تبويب حسب الصفحة
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pageController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'quran.mushaf_page_label'.tr(),
                            hintText: '1 - 604',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _loading ? null : _fetchByPage,
                        icon: _loading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.search_rounded, size: 18),
                        label: Text('quran.fetch_btn'.tr()),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: scheme.onErrorContainer, fontSize: 12.5),
                ),
              ),

            const SizedBox(height: 10),
            // شريط حالة النتائج
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _fetchedVerses.isEmpty
                      ? 'quran.ready_to_fetch'.tr()
                      : 'quran.fetched_count'.tr(namedArgs: {'count': _fetchedVerses.length.toString()}),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _fetchedVerses.isNotEmpty ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                if (_fetchedVerses.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _fetchedVerses = []),
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: Text('common.clear'.tr()),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // قائمة المعاينة
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: _fetchedVerses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.format_quote_rounded, size: 48, color: scheme.outline),
                            const SizedBox(height: 8),
                            Text(
                              'quran.preview_placeholder'.tr(),
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _fetchedVerses.length,
                          separatorBuilder: (_, __) => const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final v = _fetchedVerses[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: scheme.surface.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // شريط معلومات الآية العلوي
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: scheme.primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${v.surahName} : ${v.verseNumber}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: scheme.primary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      if (v.page != null)
                                        Text(
                                          '${'edit.page'.tr()}: ${v.page}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: scheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // نص الآية موسّط
                                  Text(
                                    v.textArabic,
                                    textAlign: TextAlign.center,
                                    textDirection: ui.TextDirection.rtl,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontFamily: v.fontFamily ?? QuranFontService.getFontFamilyForPage(v.page),
                                      height: 1.8,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              ),
            ),
            const SizedBox(height: 14),

            // أزرار العمليات السفلية
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('common.cancel'.tr()),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _fetchedVerses.isEmpty ? null : _applyToSession,
                  icon: const Icon(Icons.playlist_add_check_rounded),
                  label: Text('quran.load_to_studio_btn'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// حقل اختيار وبحث ذكي للسورة يدعم القائمة المنسدلة بالنقرة العادية مع نافذة بحث مضمنة
class _SurahSearchField extends StatefulWidget {
  const _SurahSearchField({
    super.key,
    required this.label,
    required this.selectedSurah,
    required this.onSelected,
  });

  final String label;
  final SurahInfo selectedSurah;
  final ValueChanged<SurahInfo> onSelected;

  @override
  State<_SurahSearchField> createState() => _SurahSearchFieldState();
}

class _SurahSearchFieldState extends State<_SurahSearchField> {
  final MenuController _menuController = MenuController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '') // إزالة التشكيل
        .replaceAll(RegExp(r'[إأآا]'), 'ا') // توحيد الهمزات
        .replaceAll('ة', 'ه') // توحيد التاء المربوطة
        .replaceAll('ى', 'ي'); // توحيد الألف المقصورة
  }

  List<SurahInfo> get _filteredSurahs {
    if (_searchQuery.trim().isEmpty) {
      return QuranApiService.surahs;
    }
    final q = _normalize(_searchQuery.trim());
    final cleanQ = q.replaceAll(RegExp(r'^\d+[\.\s\-]*'), '').trim();

    return QuranApiService.surahs.where((s) {
      final normArabic = _normalize(s.nameArabic);
      final normEnglish = s.nameEnglish.toLowerCase();
      final numStr = s.number.toString();

      if (numStr == q || numStr.startsWith(q)) return true;
      if (normArabic.contains(q) || normEnglish.contains(q)) return true;
      if (cleanQ.isNotEmpty &&
          (normArabic.contains(cleanQ) || normEnglish.contains(cleanQ))) {
        return true;
      }
      return false;
    }).toList();
  }

  void _openMenu() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
    _menuController.open();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        elevation: const WidgetStatePropertyAll(8),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
        ),
      ),
      menuChildren: [
        SizedBox(
          width: 290,
          height: 330,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // حقل البحث السريع في أعلى القائمة
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن سورة (اسم أو رقم)...',
                    hintStyle: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: scheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                ),
              ),
              const Divider(height: 1),
              // قائمة السور
              Expanded(
                child: _filteredSurahs.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد سورة مطابقة',
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _filteredSurahs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final s = _filteredSurahs[index];
                          final isSelected =
                              s.number == widget.selectedSurah.number;
                          return InkWell(
                            onTap: () {
                              widget.onSelected(s);
                              _menuController.close();
                            },
                            child: Container(
                              color: isSelected
                                  ? scheme.primary.withValues(alpha: 0.12)
                                  : null,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              child: Row(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? scheme.primary
                                          : scheme.primary
                                              .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${s.number}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? scheme.onPrimary
                                            : scheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          s.nameArabic,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            color: isSelected
                                                ? scheme.primary
                                                : null,
                                          ),
                                        ),
                                        Text(
                                          '${s.nameEnglish} • ${s.totalVerses} آية',
                                          style: TextStyle(
                                              fontSize: 10.5,
                                              color: scheme.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check_rounded,
                                        size: 16, color: scheme.primary),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
      builder: (context, controller, child) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: InkWell(
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                _openMenu();
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              isFocused: controller.isOpen,
              decoration: InputDecoration(
                labelText: widget.label,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                prefixIcon: const Icon(Icons.menu_book_rounded, size: 18),
                suffixIcon: Icon(
                  controller.isOpen
                      ? Icons.arrow_drop_up_rounded
                      : Icons.arrow_drop_down_rounded,
                  size: 24,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              child: Text(
                '${widget.selectedSurah.number}. ${widget.selectedSurah.nameArabic}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }
}
