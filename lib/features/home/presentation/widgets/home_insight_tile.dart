import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/models/dashboard_model.dart';

extension _LocaleCode on BuildContext {
  String get languageCode => Localizations.localeOf(this).languageCode;
}

final RegExp _arabicGlyphs = RegExp(r'[\u0600-\u06FF]');

/// Returns true when the [text] looks plausible for the requested [lang].
/// Used to filter out un-localised backend strings that would otherwise
/// produce mixed-language tiles (Arabic alert under an English UI, etc.).
bool _matchesLanguage(String text, String lang) {
  final hasArabic = _arabicGlyphs.hasMatch(text);
  if (lang == 'ar') return hasArabic;
  return !hasArabic;
}

class HomeInsightTileData {
  const HomeInsightTileData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
}

List<HomeInsightTileData> buildHomeInsightTiles(
  BuildContext context,
  DashboardModel d,
) {
  final scheme = Theme.of(context).colorScheme;
  final lang = context.languageCode;
  final out = <HomeInsightTileData>[];

  final tip = d.tipOfTheDay;
  final tipTitle = tip.exists ? tip.displayTitle(lang) : '';
  if (tipTitle.isNotEmpty) {
    final tipBody = tip.displayContent(lang);
    out.add(
      HomeInsightTileData(
        title: tipTitle,
        subtitle: tipBody.isNotEmpty
            ? tipBody
            : context.tr(AppStrings.homeInsightFallbackSubtitle),
        icon: Icons.lightbulb_outline_rounded,
        iconBg: scheme.secondaryContainer,
        iconColor: scheme.onSecondaryContainer,
      ),
    );
  }

  for (final a in d.recentAlerts) {
    if (out.length >= 2) break;
    // Tip-typed alerts are duplicates of `tip_of_the_day` and are stored
    // in the DB as a single locale-specific string (no `_ar` / `_en`),
    // which causes mixed-language tiles. Always skip them — the real tip
    // already shows up via `tip_of_the_day` with proper locale fields.
    if (a.type == 'tip') continue;
    final title = a.title.trim().isNotEmpty ? a.title.trim() : a.text.trim();
    if (title.isEmpty) continue;
    // Defensive: ignore alerts whose script doesn't match the active
    // language so a stray un-localised entry can't sneak in.
    if (!_matchesLanguage(title, lang)) continue;
    if (tipTitle.isNotEmpty && title == tipTitle) continue;
    out.add(
      HomeInsightTileData(
        title: title,
        subtitle: a.message.trim(),
        icon: homeInsightIconForAlert(a),
        iconBg: scheme.secondaryContainer,
        iconColor: scheme.onSecondaryContainer,
      ),
    );
  }

  if (d.activeGoals.isNotEmpty && out.length < 2) {
    final g = d.activeGoals.first;
    final pct = (g.progress * 100).round();
    out.add(
      HomeInsightTileData(
        title: g.title,
        subtitle: context.tr(
          AppStrings.homeGoalProgressSubtitle,
          params: {'pct': '$pct'},
        ),
        icon: homeGoalIcon(g.icon),
        iconBg: AppColors.primaryFixed,
        iconColor: AppColors.onPrimaryFixed,
      ),
    );
  }

  while (out.length < 2) {
    out.add(
      HomeInsightTileData(
        title: context.tr(AppStrings.homeQuickInsights),
        subtitle: context.tr(AppStrings.homeInsightFallbackSubtitle),
        icon: Icons.savings_outlined,
        iconBg: scheme.surfaceContainerHigh,
        iconColor: scheme.onSurfaceVariant,
      ),
    );
  }

  return out.take(2).toList();
}

IconData homeInsightIconForAlert(DashboardAlert a) {
  final raw = a.payloadIcon.toLowerCase();
  if (raw.contains('pencil')) return Icons.edit_note_outlined;
  if (raw.contains('shield')) return Icons.verified_user_outlined;
  if (raw.contains('chart')) return Icons.bar_chart_rounded;
  if (raw.contains('cake')) return Icons.cake_outlined;
  if (raw.contains('truck')) return Icons.local_shipping_outlined;
  if (raw.contains('arrow-path')) return Icons.refresh_rounded;
  if (a.type == 'tip') return Icons.auto_awesome_outlined;
  return Icons.notifications_none_rounded;
}

/// Maps the heroicon-style key from the API (`heroicon-o-truck`,
/// `flight_takeoff`, etc.) to a Material icon.
IconData homeGoalIcon(String key) {
  final raw = key.toLowerCase();
  if (raw.contains('flight')) return Icons.flight_takeoff_rounded;
  if (raw.contains('health')) return Icons.health_and_safety_outlined;
  if (raw.contains('truck') || raw.contains('car')) {
    return Icons.directions_car_outlined;
  }
  if (raw.contains('cafe') || raw.contains('cake') ||
      raw.contains('restaurant')) {
    return Icons.local_cafe_rounded;
  }
  if (raw.contains('home')) return Icons.home_outlined;
  if (raw.contains('book')) return Icons.menu_book_outlined;
  if (raw.contains('shield')) return Icons.verified_user_outlined;
  return Icons.flag_outlined;
}

class HomeInsightTile extends StatelessWidget {
  const HomeInsightTile({super.key, required this.data});

  final HomeInsightTileData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: () {},
        borderRadius: AppRadius.brMd,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(color: scheme.surfaceContainerHighest),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: data.iconBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(data.icon, size: 20, color: data.iconColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.title,
                      style: AppTextStyles.bodyMd(
                        color: scheme.onSurface,
                      ).copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (data.subtitle.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        data.subtitle,
                        style: AppTextStyles.labelMd(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
