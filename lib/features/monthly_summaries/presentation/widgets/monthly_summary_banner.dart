import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../home/data/models/dashboard_model.dart';
import '../../../home/presentation/utils/home_money.dart';

/// Surfaced on the home dashboard when `data.monthly_summary` flags
/// either an unread closed summary (`has_unread_summary: true`) or a
/// non-zero `pending_unallocated_total`.
///
/// Tapping the card jumps the user to the detail screen for the
/// `latest` summary so they can read it / allocate any leftover
/// surplus right away.
class MonthlySummaryBanner extends StatelessWidget {
  const MonthlySummaryBanner({super.key, required this.block});

  final DashboardMonthlySummaryBlock block;

  @override
  Widget build(BuildContext context) {
    if (!block.shouldShow) return const SizedBox.shrink();
    final latest = block.latest;
    if (latest == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final hasPending = block.pendingUnallocatedCount > 0 ||
        block.pendingUnallocatedTotal > 0.01;

    final palette = hasPending
        ? _BannerPalette(
            bg: AppColors.amber100,
            border: AppColors.amber500.withValues(alpha: 0.45),
            iconBg: AppColors.amber500,
            iconColor: Colors.white,
            titleColor: AppColors.amber700,
            bodyColor: AppColors.amber700.withValues(alpha: 0.85),
            ctaBg: AppColors.amber500,
            ctaFg: Colors.white,
          )
        : _BannerPalette(
            bg: scheme.primary.withValues(alpha: 0.10),
            border: scheme.primary.withValues(alpha: 0.30),
            iconBg: scheme.primary,
            iconColor: scheme.onPrimary,
            titleColor: scheme.primary,
            bodyColor: scheme.onSurfaceVariant,
            ctaBg: scheme.primary,
            ctaFg: scheme.onPrimary,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: AppRadius.brMd,
        onTap: () => _open(context, latest),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: palette.bg,
            borderRadius: AppRadius.brMd,
            border: Border.all(color: palette.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.iconBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  hasPending
                      ? Icons.savings_rounded
                      : Icons.event_available_rounded,
                  color: palette.iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr(AppStrings.dashboardSummaryBannerNew),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMd(color: palette.titleColor)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    if (hasPending)
                      Text(
                        context.tr(
                          AppStrings.dashboardSummaryBannerPending,
                          params: {
                            'amount': kHomeMoneyFormat
                                .format(block.pendingUnallocatedTotal),
                            'currency': latest.currency,
                          },
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppTextStyles.labelMd(color: palette.bodyColor),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: () => _open(context, latest),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.ctaBg,
                  foregroundColor: palette.ctaFg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.brSm,
                  ),
                ),
                child: Text(
                  hasPending
                      ? context.tr(
                          AppStrings.dashboardSummaryBannerAllocateCta,
                        )
                      : context.tr(AppStrings.dashboardSummaryBannerCta),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, DashboardMonthlySummaryLatest latest) {
    // Always go through the detail route — when there's leftover
    // surplus, the detail screen already exposes the allocate FAB
    // so a single nav handles both "read me" and "allocate me".
    context.push('/monthly-summaries/${latest.year}/${latest.month}');
  }
}

class _BannerPalette {
  const _BannerPalette({
    required this.bg,
    required this.border,
    required this.iconBg,
    required this.iconColor,
    required this.titleColor,
    required this.bodyColor,
    required this.ctaBg,
    required this.ctaFg,
  });

  final Color bg;
  final Color border;
  final Color iconBg;
  final Color iconColor;
  final Color titleColor;
  final Color bodyColor;
  final Color ctaBg;
  final Color ctaFg;
}
