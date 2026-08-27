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

  // Tab 1: By Surah & Range
  SurahInfo _selectedSurah = QuranApiService.surahs[1]; // Default Al-Baqarah
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
    _tabController = TabController(length: 2, vsync: this);
    _fromVerseController = TextEditingController(text: '1');
    _toVerseController = TextEditingController(text: '${_selectedSurah.totalVerses.clamp(1, 10)}');
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
    final from = int.tryParse(_fromVerseController.text.trim()) ?? 1;
    final to = int.tryParse(_toVerseController.text.trim()) ?? _selectedSurah.totalVerses;

    if (from < 1 || to < from || to > _selectedSurah.totalVerses) {
      setState(() => _error = 'نطاق الآيات غير صحيح (يجب أن يكون بين 1 و ${_selectedSurah.totalVerses})');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _fetchedVerses = [];
    });

    try {
      final results = await QuranApiService.instance.fetchVersesByRange(
        surahNumber: _selectedSurah.number,
        fromVerse: from,
        toVerse: to,
      );
      setState(() {
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
        width: 720,
        height: 600,
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
              height: 70,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // تبويب حسب السورة ونطاق الآيات
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<SurahInfo>(
                          initialValue: _selectedSurah,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'quran.select_surah'.tr(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: QuranApiService.surahs.map((s) {
                            return DropdownMenuItem<SurahInfo>(
                              value: s,
                              child: Text(
                                '${s.number}. ${s.nameArabic} (${s.nameEnglish}) - ${s.totalVerses} آية',
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (s) {
                            if (s != null) {
                              setState(() {
                                _selectedSurah = s;
                                _fromVerseController.text = '1';
                                _toVerseController.text = '${s.totalVerses.clamp(1, 15)}';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _fromVerseController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'quran.from_verse'.tr(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _toVerseController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'quran.to_verse'.tr(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _loading ? null : _fetchByRange,
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
