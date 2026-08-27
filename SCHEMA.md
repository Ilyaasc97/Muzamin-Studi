# JSON Export Schema v2 — استوديو المزامنة الصوتية (Universal Audio Sync Studio)

## نظرة عامة

يحفظ التطبيق بيانات التوقيت المتزامن في ملف JSON عالي الدقة (Schema v2) مع دعم كامل للربط المباشر بتطبيقات الإنتاج وقواعد البيانات (Isar, SQLite, PostgreSQL, Supabase) ومخازن الصوتيات السحابية مثل Cloudflare R2.

---

## البنية الأساسية (Schema v2)

```json
{
  "schemaVersion": 2,
  "lessonId": "baqarah_lesson_01",
  "audioUrl": "https://pub-xxx.r2.dev/tafsiirapp/baqarah_01.mp3",
  "sourceFile": "baqarah_01.mp3",
  "exportedAt": "2026-08-25T14:30:00.000Z",
  "totalSegments": 5,
  "totalDurationMs": 450000,
  "countsByType": {
    "quran": 3,
    "hadith": 1,
    "chapter": 1,
    "dhikr": 0,
    "custom": 0
  },
  "segments": [
    {
      "id": 0,
      "number": 1,
      "verseNumber": 1,
      "type": "chapter",
      "startMs": 0,
      "endMs": 15000,
      "durationMs": 15000,
      "label": "مقدمة وتفسير الاستعاذة"
    },
    {
      "id": 1,
      "number": 2,
      "verseNumber": 2,
      "type": "quran",
      "startMs": 15200,
      "endMs": 48120,
      "durationMs": 32920,
      "label": "سورة البقرة - الآية 1",
      "textArabic": "الم"
    },
    {
      "id": 2,
      "number": 3,
      "verseNumber": 3,
      "type": "hadith",
      "startMs": 49000,
      "endMs": 95000,
      "durationMs": 46000,
      "label": "حديث فضل سورة البقرة",
      "textArabic": "لا تجعلوا بيوتكم مقابر إن الشيطان ينفر من البيت الذي تقرأ فيه سورة البقرة"
    }
  ],
  "totalVerses": 1,
  "verses": [
    {
      "id": 1,
      "number": 2,
      "verseNumber": 2,
      "type": "quran",
      "startMs": 15200,
      "endMs": 48120,
      "durationMs": 32920
    }
  ]
}
```

---

## تفاصيل الحقول (Field Specifications)

### المستوى الأول (Root Object)

| الحقل | النوع | المطلوب | الوصف |
| :--- | :--- | :--- | :--- |
| `schemaVersion` | `integer` | ✓ | إصدار البنية (حالياً: `2`) |
| `lessonId` | `string` | ✓ | معرّف الدرس أو التسجيل الصوتي |
| `audioUrl` | `string` | ✗ | رابط الملف الصوتي على R2 أو CDN |
| `sourceFile` | `string` | ✗ | اسم الملف الصوتي الأصلي |
| `exportedAt` | `ISO8601` | ✓ | وقت التصدير بصيغة UTC |
| `totalSegments` | `integer` | ✓ | إجمالي عدد المقاطع المسجلة بكل الأنواع |
| `totalDurationMs` | `integer` | ✓ | إجمالي مدة التسجيل بالمللي ثانية |
| `countsByType` | `object` | ✓ | إحصائيات المقاطع لكل نوع (`quran`, `hadith`, `chapter`, `dhikr`, `custom`) |
| `segments` | `array` | ✓ | مصفوفة المقاطع الموحدة |
| `verses` | `array` | ✗ | مصفوفة الآيات القرآنية فقط (للتوافقية العكسية مع تطبيقات التفسير القائمة) |

---

### بنية المقطع الموحد (`Segment` Object)

| الحقل | النوع | المطلوب | الوصف |
| :--- | :--- | :--- | :--- |
| `id` | `integer` | ✓ | معرف تسلسلي فريد للمقطع |
| `number` / `verseNumber` | `integer` | ✓ | الرقم الترتيبي للمقطع |
| `type` | `string` | ✓ | نوع المقطع: `quran` \| `hadith` \| `chapter` \| `dhikr` \| `custom` |
| `startMs` | `integer` | ✓ | وقت البداية بالمللي ثانية |
| `endMs` | `integer` | ✓ | وقت النهاية بالمللي ثانية |
| `durationMs` | `integer` | ✓ | مدة المقطع (`endMs - startMs`) |
| `label` | `string` | ✗ | عنوان المقطع أو اسم السورة / الباب |
| `textArabic` | `string` | ✗ | النص العربي (الآية، الحديث، الذكر) |

---

## أنواع المقاطع المدعومة (Segment Types)

| النوع (`type`) | الاستخدام النموذجي | اللون المقابل في الواجهة |
| :--- | :--- | :--- |
| `quran` | الآيات القرآنية مع رقم الآية والسورة | تركوازي زمردي (`Teal #2DD4BF`) |
| `hadith` | الأحاديث النبوية مع المتن والرواية | كهرماني ذهبي (`Amber #FBBF24`) |
| `chapter` | الفصول والأبواب والعناوين الرئيسية للدرس | أزرق نيلي (`Blue #60A5FA`) |
| `dhikr` | الأذكار والأدعية الواردة في الدرس | بنفسجي (`Purple #A78BFA`) |
| `custom` | الفوائد المقتطفة والفقرات الخاصة | أحمر مرجاني (`Coral #F87171`) |

---

## التوافقية العكسية (Backward Compatibility)

1. **الاستيراد:** عند استيراد أي ملف قديم تم تصديره بـ Schema v1 (يحتوي فقط على `verses`)، يقوم التطبيق تلقائياً بقراءته وتحويل جميع العناصر إلى مقاطع من نوع `quran` دون أي أخطاء.
2. **التصدير:** يوفر ملف التصدير مصفوفة `verses` إلى جانب `segments` لتمكين التطبيقات التي تتوقع مصفوفة آيات تقليدية من العمل دون تعديل.
