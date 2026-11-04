<div align="center">

# 🎙️ Muzamin Studio | أستوديو مُزامِن
**Islamic Audio-Text Synchronization Studio for Quran & Tafsir Developers**

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android-00A98F?style=for-the-badge)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.0-emerald?style=for-the-badge)](#)

*أستوديو احترافي مفتوح المصدر لمزامنة الصوت مع النصوص الإسلامية (القرآن الكريم، الأحاديث النبوية، فصول الكتب، الأدعية والأذكار) بدقة المللي ثانية وتصديرها بصيغ إنتاجية فائقة الخفة.*

---

</div>

## ✨ أبرز المميزات (Key Features)

### 📖 1. محرك مصحف المدينة الرسمي أوفلاين (QPC V2 Glyphs Engine)
- **مصحف المدينة النبوية (604 صفحة)** مدمج محلياً 100% بدون الحاجة لأي اتصال بالإنترنت.
- محمل خطوط ديناميكي ذكي (`QuranFontService`) يقوم بتحميل خط كل صفحة (`QCF2001.ttf` إلى `QCF2604.ttf`) ديناميكياً بدقة مطابقة للمصحف الورقي.

### 🎙️ 2. مزامنة المقاطع متعددة الأنواع (Multi-Segment Synchronization)
- دعم 5 تصنيفات رئيسية:
  1. **📖 آية قرآنية (Quran Verse)**: مع رقم الآية، رقم الصفحة، ورقم الجزء المحسوب تلقائياً.
  2. **📜 حديث نبوي (Prophetic Hadith)**.
  3. **📑 فصل / عنوان (Chapter / Section)**.
  4. **🌿 ذكر / دعاء (Dhikr / Dua)**.
  5. **✍️ فقرة مخصصة (Custom Paragraph)**.

### ⚡ 3. مخطط التصدير فائق الخفة (Ultra-Lightweight Sync Schema v2)
- **Single Source of Truth**: تصدير التوقيتات والمراجع المصحفية بدون حشو نصوص الآيات، مما يقلل حجم ملف الدرس من ~50KB إلى **أقل من 1.5KB**.
- **حساب الأجزاء ونطاق الصفحات تلقائياً**: توليد حقول `juz` و `pageRange` (`from`, `to`, `fromJuz`, `toJuz`) لتسهيل فهرسة وتظليل الآيات في تطبيقات الجوال والويب.

### 🔄 4. جلب وتلقيم ذكي مع التراجع التزامني (Preload & Undo Sync)
- **جلب سور وصفحات القرآن (`Fetch Quran`)** مباشرة بضغطة زر.
- **الرجوع للآية السابقة (`Prev Line`)** والتخطي السريع.
- **التراجع المتزامن (`Undo Sync / Ctrl+Z`)**: عند التراجع عن مقطع مسجل، يعود مؤشر الآية خطوة للوراء تلقائياً لإتاحة إعادة تسجيلها فوراً.

### 📊 5. أستوديو تحكم صوتي متكامل
- موجة صوتية تفاعلية (`Audio Waveform`) مع إمكانية التقديم والتأخير بالنقر المباشر.
- تعويض التأخير البشري (`Latency Compensation`) من -500ms إلى +500ms.
- سرعات تشغيل متعددة (`1x`, `1.5x`, `2x`).
- حفظ تلقائي فوري للجلسة واستعادتها في حال الإغلاق غير المتوقع (`Auto-save & Session Recovery`).

### 📦 6. تعدد صيغ التصدير (Multi-Format Export Studio)
- **JSON Schema v2**: مهيأ لقواعد بيانات Isar / SQLite / Supabase.
- **WebVTT (`.vtt`)**: لمعايير الويب ومشغلات الفيديو HTML5.
- **SubRip (`.srt`)**: لبرامج المونتاج والترجمة.
- **Dart Seed Code (`.dart`)**: كود دارت جاهز للتضمين المباشر في مشاريع Flutter.

---

## ⌨️ اختصارات لوحة المفاتيح (Keyboard Shortcuts)

| المفتاح | الوظيفة |
| :--- | :--- |
| `Space` | تشغيل / إيقاف مؤقت للصوت |
| `Enter` / `NumPad Enter` | **تسجيل نقطة البداية ثم النهاية (Tap-to-Time)** |
| `Esc` | إلغاء بداية قيد التسجيل |
| `Ctrl + Z` | تراجع عن آخر تسجيل وحذف المقطع |
| `→` / `←` | تقديم / تأخير 5 ثوانٍ |
| `↑` / `↓` | تقديم / تأخير 30 ثانية |
| `1` إلى `5` | التبديل السريع بين أنواع المقاطع (آية، حديث، فصل، ذكر، فقرة) |

---

## 🚀 التشغيل والتثبيت (Getting Started)

### المتطلبات الأساسية
- Flutter SDK (الإصدار `>=3.24.0`)
- Dart SDK (الإصدار `>=3.5.0`)

### التشغيل في وضع التطوير
```powershell
# 1. استنساخ المستودع
git clone https://github.com/your-username/tafsir_timing_tool.git
cd tafsir_timing_tool

# 2. تحميل الحزم والاعتماديات
flutter pub get

# 3. التشغيل على Windows
flutter run -d windows

# أو على Android
flutter run -d android
```

### بناء نسخة الإنتاج النهائية (Production Release Build)

#### نظام Windows (Standalone Executable):
```powershell
flutter build windows --release
```
ستجد الملفات التنفيذية الجاهزة للتوزيع في: `build\windows\x64\runner\Release\`

#### نظام Android (APK):
```powershell
flutter build apk --release
```

---

## 📁 هيكلية المشروع (Project Architecture)

```
lib/
├── main.dart                      # نقطة الدخول، إعدادات اللغات والثيم
├── core/
│   └── app_logger.dart            # نظام تسجيل الأحداث والأخطاء الموحد
├── controllers/
│   └── timing_session.dart        # محرك إدارة الجلسة ومشغل الصوت والتلقيم
├── models/
│   ├── timing_entry.dart          # نموذج المقطع الزمني، حساب الأجزاء، و JSON
│   └── segment_type.dart          # تصنيفات المقاطع الخمسة
├── services/
│   ├── json_export_service.dart   # محرك تصدير JSON فائق الخفة
│   ├── multi_format_export_service.dart # تصدير VTT, SRT, Dart Seed
│   ├── quran_api_service.dart     # جلب الآيات والصفحات محلياً وأوفلاين
│   ├── quran_font_service.dart    # محمل خطوط صفحات المصحف الديناميكي
│   ├── settings_service.dart      # إدارة الثيم والاختصارات والتأخير
│   └── waveform_service.dart      # توليد ورسم الموجات الصوتية
├── screens/
│   ├── home_screen.dart           # شاشة الأستوديو الرئيسية
│   └── settings_screen.dart       # شاشة الإعدادات وتخصيص الاختصارات
└── widgets/
    ├── session_metadata_card.dart # شريط التحكم بالملف وبطاقة الآية القرآنية الموسطة
    ├── player_panel.dart          # مشغل الصوت، سرعة التشغيل، والموجة الصوتية
    ├── record_button.dart         # زر التسجيل التفاعلي
    ├── entries_list.dart          # قائمة المقاطع المسجلة مع إمكانية التعديل
    ├── quran_fetch_dialog.dart    # نافذة اختيار السورة والصفحة وجلب الآيات
    └── export_bar.dart            # شريط التصدير متعدد الصيغ
```

---

## 📄 رخصة الاستخدام (License)

هذا المشروع مرخص تحت رخصة **MIT License** — راجع ملف [LICENSE](LICENSE) للمزيد من التفاصيل.
