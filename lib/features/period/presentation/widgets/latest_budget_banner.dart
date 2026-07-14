import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../data/models/selected_period.dart';
import '../providers/selected_period_provider.dart';

/// Helper banner shown whenever the server returned `period.source =
/// latest_budget` for the period the screen is rendering.
///
/// Per the spec: «اعرض في الـ UI شريطاً مساعداً عند `source ==
/// "latest_budget"`: تعرض شهر مايو لأن لا توجد ميزانية لشهر السيرفر
/// الحالي». The banner exposes a "back to current month" CTA that
/// re-aligns [selectedPeriodProvider] to the device's calendar month
/// (which becomes the explicit period).
///
/// Renders nothing (`SizedBox.shrink`) when [period] is `null` or when
/// the source isn't [PeriodSource.latestBudget], so it's safe to
/// drop in unconditionally above any list.
class LatestBudgetBanner extends ConsumerWidget {
  const LatestBudgetBanner({super.key, required this.period, this.onTap});

  final SelectedPeriod? period;

  /// Custom tap handler. Defaults to re-aligning [selectedPeriodProvider]
  /// to the device's current calendar month.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = period;
    if (p == null || !p.isFromLatestBudget) {
      return const SizedBox.shrink();
    }

    final lang = ref.watch(localeProvider).languageCode;
    final monthLabel = _monthLabel(p, lang);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: scheme.brightness == Brightness.dark
            ? AppColors.amber900.withValues(alpha: 0.25)
            : AppColors.amber50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap ?? () => _backToToday(ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppColors.amber700,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(
                          AppStrings.periodLatestBudgetTitle,
                          params: {'month': monthLabel},
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              color: AppColors.amber900,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(AppStrings.periodLatestBudgetSubtitle),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: AppColors.amber900.withValues(alpha: 0.85),
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr(AppStrings.periodLatestBudgetBackToToday),
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                              color: AppColors.amber900,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.amber900,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _backToToday(WidgetRef ref) {
    final now = DateTime.now();
    ref
        .read(selectedPeriodProvider.notifier)
        .setExplicit(month: now.month, year: now.year);
  }

  String _monthLabel(SelectedPeriod p, String lang) {
    // Prefer the server-formatted period_start so locale-specific month
    // names match what the dashboard already renders. Fall back to a
    // synthesised first-of-month when the field is empty.
    final start = DateTime.tryParse(p.periodStart) ??
        (p.month >= 1 && p.month <= 12 && p.year > 1900
            ? DateTime(p.year, p.month, 1)
            : null);
    if (start == null) return '${p.month}/${p.year}';
    return DateFormat.MMMM(lang).format(start);
  }
}
