// lib/widgets/user_guide_dialog.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نافذة ترحيبية ودليل استخدام شامل لأستوديو مُزامِن
class UserGuideDialog extends StatefulWidget {
  const UserGuideDialog({super.key, this.isFirstLaunch = false});

  final bool isFirstLaunch;

  static const String prefKey = 'has_seen_welcome_guide_v1';

  static Future<void> show(
    BuildContext context, {
    bool isFirstLaunch = false,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => UserGuideDialog(isFirstLaunch: isFirstLaunch),
    );
  }

  static Future<bool> shouldShowOnStartup() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(prefKey) ?? false);
  }

  @override
  State<UserGuideDialog> createState() => _UserGuideDialogState();
}

class _UserGuideDialogState extends State<UserGuideDialog> {
  bool _dontShowAgain = false;

  @override
  void initState() {
    super.initState();
    _dontShowAgain = widget.isFirstLaunch;
  }

  Future<void> _handleClose() async {
    if (_dontShowAgain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(UserGuideDialog.prefKey, true);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 780,
          maxHeight: 640,
        ),
        child: DefaultTabController(
          length: 4,
          child: Column(
            children: [
              // رأس النافذة الترحيبية
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: isLight ? 0.6 : 0.4),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(
                    bottom: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: isLight ? 0.6 : 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary,
                            scheme.primary.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.graphic_eq_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'guide.dialog_title'.tr(),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: scheme.primary.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  'v1.0.0',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'app_subtitle'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'guide.close_btn'.tr(),
                      onPressed: _handleClose,
                    ),
                  ],
                ),
              ),

              // شريط التبويبات الأنيق
              Container(
                color: scheme.surfaceContainerHigh.withValues(alpha: isLight ? 0.3 : 0.2),
                child: TabBar(
                  isScrollable: false,
                  indicatorColor: scheme.primary,
                  indicatorWeight: 3,
                  labelColor: scheme.primary,
                  unselectedLabelColor: scheme.onSurfaceVariant,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.stars_rounded, size: 20),
                      text: 'guide.tab_about'.tr(),
                    ),
                    Tab(
                      icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                      text: 'guide.tab_workflow'.tr(),
                    ),
                    Tab(
                      icon: const Icon(Icons.keyboard_rounded, size: 20),
                      text: 'guide.tab_shortcuts'.tr(),
                    ),
                    Tab(
                      icon: const Icon(Icons.tips_and_updates_outlined, size: 20),
                      text: 'guide.tab_tips'.tr(),
                    ),
                  ],
                ),
              ),

              // محتوى التبويبات
              Expanded(
                child: TabBarView(
                  children: [
                    _buildAboutTab(context, scheme, isLight),
                    _buildWorkflowTab(context, scheme, isLight),
                    _buildShortcutsTab(context, scheme, isLight),
                    _buildTipsTab(context, scheme, isLight),
                  ],
                ),
              ),

              // الشريط السفلي: خيار عدم الإظهار وزر البدء
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh.withValues(alpha: isLight ? 0.5 : 0.3),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  border: Border(
                    top: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: isLight ? 0.5 : 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          _dontShowAgain = !_dontShowAgain;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _dontShowAgain,
                              onChanged: (val) {
                                setState(() {
                                  _dontShowAgain = val ?? false;
                                });
                              },
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'guide.dont_show_again'.tr(),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _handleClose,
                      icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                      label: Text(
                        'guide.start_btn'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutTab(BuildContext context, ColorScheme scheme, bool isLight) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: isLight ? 0.4 : 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: scheme.primary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'guide.about_title'.tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'guide.about_desc'.tr(),
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'guide.features_title'.tr(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.5,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            scheme,
            icon: Icons.menu_book_rounded,
            title: 'guide.feature_1_title'.tr(),
            desc: 'guide.feature_1_desc'.tr(),
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            context,
            scheme,
            icon: Icons.category_rounded,
            title: 'guide.feature_2_title'.tr(),
            desc: 'guide.feature_2_desc'.tr(),
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            context,
            scheme,
            icon: Icons.data_object_rounded,
            title: 'guide.feature_3_title'.tr(),
            desc: 'guide.feature_3_desc'.tr(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    ColorScheme scheme, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: isLight ? 0.4 : 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: scheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowTab(BuildContext context, ColorScheme scheme, bool isLight) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        _buildWorkflowStep(
          context,
          scheme,
          stepNumber: '1',
          icon: Icons.audio_file_outlined,
          title: 'guide.workflow_step1_title'.tr(),
          desc: 'guide.workflow_step1_desc'.tr(),
        ),
        const SizedBox(height: 12),
        _buildWorkflowStep(
          context,
          scheme,
          stepNumber: '2',
          icon: Icons.cloud_download_outlined,
          title: 'guide.workflow_step2_title'.tr(),
          desc: 'guide.workflow_step2_desc'.tr(),
        ),
        const SizedBox(height: 12),
        _buildWorkflowStep(
          context,
          scheme,
          stepNumber: '3',
          icon: Icons.touch_app_outlined,
          title: 'guide.workflow_step3_title'.tr(),
          desc: 'guide.workflow_step3_desc'.tr(),
          highlight: true,
        ),
        const SizedBox(height: 12),
        _buildWorkflowStep(
          context,
          scheme,
          stepNumber: '4',
          icon: Icons.file_upload_outlined,
          title: 'guide.workflow_step4_title'.tr(),
          desc: 'guide.workflow_step4_desc'.tr(),
        ),
      ],
    );
  }

  Widget _buildWorkflowStep(
    BuildContext context,
    ColorScheme scheme, {
    required String stepNumber,
    required IconData icon,
    required String title,
    required String desc,
    bool highlight = false,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? scheme.primaryContainer.withValues(alpha: isLight ? 0.35 : 0.2)
            : scheme.surfaceContainerHighest.withValues(alpha: isLight ? 0.4 : 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? scheme.primary.withValues(alpha: 0.4)
              : scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: highlight ? scheme.primary : scheme.surfaceContainerHighest,
            child: Text(
              stepNumber,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: highlight ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Icon(icon, color: highlight ? scheme.primary : scheme.onSurfaceVariant, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: highlight ? scheme.primary : scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutsTab(BuildContext context, ColorScheme scheme, bool isLight) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        _buildShortcutRow(
          context,
          scheme,
          keyLabel: 'Space',
          actionDesc: 'keyboard.space_desc'.tr(),
          icon: Icons.play_arrow_rounded,
        ),
        const SizedBox(height: 8),
        _buildShortcutRow(
          context,
          scheme,
          keyLabel: 'Enter / NumPad',
          actionDesc: 'keyboard.enter_desc'.tr(),
          icon: Icons.radio_button_checked_rounded,
          highlight: true,
        ),
        const SizedBox(height: 8),
        _buildShortcutRow(
          context,
          scheme,
          keyLabel: 'Ctrl + Z',
          actionDesc: 'keyboard.ctrl_z_desc'.tr(),
          icon: Icons.undo_rounded,
        ),
        const SizedBox(height: 8),
        _buildShortcutRow(
          context,
          scheme,
          keyLabel: 'Esc',
          actionDesc: 'keyboard.escape_desc'.tr(),
          icon: Icons.cancel_outlined,
        ),
        const SizedBox(height: 8),
        _buildShortcutRow(
          context,
          scheme,
          keyLabel: '→  /  ←',
          actionDesc: 'keyboard.arrow_right_desc'.tr(),
          icon: Icons.fast_forward_rounded,
        ),
        const SizedBox(height: 8),
        _buildShortcutRow(
          context,
          scheme,
          keyLabel: '1 .. 5',
          actionDesc: 'keyboard.switch_type_desc'.tr(),
          icon: Icons.dialpad_rounded,
        ),
      ],
    );
  }

  Widget _buildShortcutRow(
    BuildContext context,
    ColorScheme scheme, {
    required String keyLabel,
    required String actionDesc,
    required IconData icon,
    bool highlight = false,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? scheme.primary.withValues(alpha: isLight ? 0.1 : 0.15)
            : scheme.surfaceContainerHighest.withValues(alpha: isLight ? 0.3 : 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? scheme.primary.withValues(alpha: 0.3) : scheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.4),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Text(
              keyLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: highlight ? scheme.primary : scheme.onSurface,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 14),
          Icon(icon, size: 18, color: highlight ? scheme.primary : scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              actionDesc,
              style: TextStyle(
                fontSize: 13,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsTab(BuildContext context, ColorScheme scheme, bool isLight) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        _buildTipCard(
          context,
          scheme,
          icon: Icons.timer_outlined,
          title: 'guide.tip_1_title'.tr(),
          desc: 'guide.tip_1_desc'.tr(),
        ),
        const SizedBox(height: 12),
        _buildTipCard(
          context,
          scheme,
          icon: Icons.history_rounded,
          title: 'guide.tip_2_title'.tr(),
          desc: 'guide.tip_2_desc'.tr(),
        ),
        const SizedBox(height: 12),
        _buildTipCard(
          context,
          scheme,
          icon: Icons.alt_route_rounded,
          title: 'guide.tip_3_title'.tr(),
          desc: 'guide.tip_3_desc'.tr(),
        ),
      ],
    );
  }

  Widget _buildTipCard(
    BuildContext context,
    ColorScheme scheme, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: isLight ? 0.4 : 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: scheme.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: scheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
