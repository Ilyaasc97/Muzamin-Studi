# PROJECT_MAP.md — Universal Islamic Audio-Text Sync Studio (مُزامِن — Muzamin Studio)

---

## [TECH_STACK]
* **Runtime & Framework:** Flutter (Dart SDK >= 3.5.0 < 4.0.0, Material 3, Dark-First RTL/LTR).
* **Audio Engine:** `just_audio` (^0.10.4) + `just_audio_windows` (^0.2.2).
* **Persistence & State Backup:** `shared_preferences` (^2.3.0) — Non-blocking JSON snapshots.
* **File System Interop:** `file_selector` (^1.0.3) + `path_provider` (^2.1.5) + `path` (^1.9.0).
* **Internationalization:** `easy_localization` (^3.0.7) — 100% translated locales: `ar`, `en`, `so`.
* **Logging System:** `AppLogger` — Non-blocking circular in-memory buffer.
* **Theming Engine:** Dynamic Reactive ThemeMode (Dark, Light, System) via `SettingsService` & `ListenableBuilder`.
* **Multi-Format Export:** JSON (Schema v2 with `page` field), Dart Seed Code (`.dart`), WebVTT (`.vtt`), SubRip (`.srt`).
* **Script Pre-loading & Page Splitting:** Sequential auto-text matcher engine with Mushaf page incrementer (+1).
* **Branding & Assets:** Custom vector app icon (`assets/icons/app_icon.png`), native desktop runner configuration (`Muzamin Studio`).
* **Code Health & Testing:** `flutter_lints` (^5.0.0), `flutter_test` (41 Unit & Regression Suites Passed).
* **Current System Baseline:** August 2026. All active dependencies are verified stable and zero-deprecated.

---

## [SYSTEM_FLOW]

```
+-----------------------------------------------------------------------------------+
|                               USER WORKFLOW (GUI)                                 |
+-----------------------------------------------------------------------------------+
| 1. Open Audio / Remote URL  --> Generates / Auto-fills Lesson ID                  |
| 2. (Optional) Pre-load Text --> Paste verses/hadiths for automated sequence link  |
| 3. Select Segment & Page    --> [Quran (1) | Hadith (2) | ... ] + Page Stepper    |
| 4. Play / Pause / Seek      --> 60fps RMS Waveform + Scrubbing + Zoom Controls    |
| 5. Tap to Time (Enter)      --> Record Start -> Record End (Auto-attaches page)   |
| 6. Color-Coded Segments     --> Realtime Waveform Visualization + Filtered List   |
| 7. Edit / Re-order / Delete --> Inline text, page number, and timing adjustment   |
| 8. Settings & Theming       --> Instant Dark/Light/System theme toggle + Latency  |
| 9. Auto-Save Snapshot       --> 30s background cycle to prevent data loss         |
| 10. Multi-Format Export     --> JSON v2 (with page), Dart Seed, WebVTT, SRT       |
+-----------------------------------------------------------------------------------+
```

---

## [ARCHITECTURE]

```
lib/
├── config/
│   └── app_localization.dart         # Multi-language engine (ar, en, so)
├── core/
│   └── app_logger.dart               # Non-blocking async lightweight logger
├── models/
│   ├── segment_type.dart             # Enum: quran, hadith, chapter, dhikr, custom
│   └── timing_entry.dart             # Universal timestamp entity with `page` (SyncSegment alias)
├── controllers/
│   └── timing_session.dart           # Audio state + Tap-to-Time + Script Preloader + Active Page
├── services/
│   ├── json_export_service.dart      # Multi-segment JSON exporter (Schema v2 with page)
│   ├── multi_format_export_service.dart # Dart seed code (with page), WebVTT, and SRT exporter
│   ├── settings_service.dart         # Keybindings, latency offset, theme persistence (ChangeNotifier)
│   └── waveform_service.dart         # RMS Byte Energy waveform generator & curve smoother
├── screens/
│   ├── home_screen.dart              # Responsive studio interface + Global Shortcuts (1-5) + Brand Logo
│   └── settings_screen.dart          # Modernized Settings: Theme, Latency (+/- 50ms), Shortcuts
└── widgets/
    ├── type_selector_chips.dart      # Quick switch between segment types + Page Stepper (+1)
    ├── session_metadata_card.dart    # Audio input + Preload Script + Lesson metadata
    ├── preload_script_dialog.dart    # Text / Script pasting modal
    ├── player_panel.dart             # Timecode, waveform stream, seek controls
    ├── waveform_widget.dart          # RMS Color-coded interactive waveform with live playhead & zoom
    ├── record_button.dart            # Active segment dynamic trigger with live elapsed counter
    ├── entries_list.dart             # Filterable list of stamped items with Page badges
    ├── segment_edit_dialog.dart      # Quick edit modal for label, page, and numbers
    ├── export_bar.dart               # Statistics summary & Multi-Format export
    └── language_selector.dart        # Language switcher dropdown
```

---

## [ORPHANS & PENDING]
*(None — All features, protocols, and workflows are fully implemented, connected, and verified with 0 warnings and passing tests).*
