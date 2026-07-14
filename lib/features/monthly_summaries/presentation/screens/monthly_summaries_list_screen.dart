import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../home/presentation/utils/home_money.dart';
import '../../data/models/monthly_summary_model.dart';
import '../providers/monthly_summaries_provider.dart';

/// Top-level list screen for `GET /monthly-summaries`. Each row is one
/// month — tap opens [MonthlySummaryDetailScreen] (route already wired
/// at `/monthly-summaries/:year/:month`).
class MonthlySummariesListScreen extends ConsumerStatefulWidget {
  const MonthlySummariesListScreen({super.key});

  @override
  ConsumerState<MonthlySummariesListScreen> createState() =>
      _MonthlySummariesListScreenState();
}

class _MonthlySummariesListScreenState
    extends ConsumerState<MonthlySummariesListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      ref.read(monthlySummariesListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lang = ref.watch(localeProvider).languageCode;
    final asyncList = ref.watch(monthlySummariesListProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          context.tr(AppStrings.monthlySummariesTitle),
          style: AppTextStyles.headlineSm(color: scheme.onSurface)
              .copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: asyncList.when(
        data: (data) {
          if (data.items.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(monthlySummariesListProvider.notifier).refresh(),
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.mobileMargin,
                AppSpacing.md,
                AppSpacing.mobileMargin,
                MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
              ),
              itemCount: data.items.length + (data.isLoadingMore ? 1 : 0),
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
              itemBuilder: (_, i) {
                if (i >= data.items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final summary = data.items[i];
                return _MonthlySummaryCard(
                  summary: summary,
                  languageCode: lang,
                  onTap: () => context.push(
                    '/monthly-summaries/${summary.year}/${summary.month}',
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorState(
          onRetry: () =>
              ref.read(monthlySummariesListProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard({
    required this.summary,
    required this.languageCode,
    required this.onTap,
  });

  final MonthlySummaryModel summary;
  final String languageCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthLabel = DateFormat.yMMMM(languageCode)
        .format(DateTime(summary.year, summary.month, 1));
    return Material(
      color: scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brMd,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      monthLabel,
                      style: AppTextStyles.headlineSm(color: scheme.onSurface)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  _StatusPill(status: summary.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _MetricRow(
                label: context.tr(AppStrings.monthlySummariesIncome),
                value: kHomeMoneyFormat.format(summary.totalIncome),
                currency: summary.currency,
                color: AppColors.green700,
              ),
              const SizedBox(height: 4),
              _MetricRow(
                label: context.tr(AppStrings.monthlySummariesExpenses),
                value: kHomeMoneyFormat.format(summary.totalExpenses),
                currency: summary.currency,
                color: scheme.error,
              ),
              const SizedBox(height: 4),
              _MetricRow(
                label: context.tr(AppStrings.monthlySummariesSurplus),
                value: kHomeMoneyFormat.format(summary.surplus),
                currency: summary.currency,
                color: scheme.primary,
                emphasised: true,
              ),
              if (summary.unallocatedSurplus > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amber100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '${context.tr(AppStrings.monthlySummariesUnallocatedSurplus)}: '
                      '${kHomeMoneyFormat.format(summary.unallocatedSurplus)} '
                      '${summary.currency}',
                      style: AppTextStyles.labelSm(color: AppColors.amber700)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isClosed = status == 'closed';
    final bg = isClosed ? AppColors.teal100 : AppColors.amber100;
    final fg = isClosed ? AppColors.teal700 : AppColors.amber700;
    final label = isClosed
        ? context.tr(AppStrings.monthlySummariesStatusClosed)
        : context.tr(AppStrings.monthlySummariesStatusOpen);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSm(color: fg)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.currency,
    required this.color,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final String currency;
  final Color color;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySm(
              color: emphasised ? scheme.onSurface : scheme.onSurfaceVariant,
            ).copyWith(fontWeight: emphasised ? FontWeight.w700 : FontWeight.w500),
          ),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            '$value $currency',
            style: AppTextStyles.bodyMd(color: color)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.mobileMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 48,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.tr(AppStrings.monthlySummariesEmptyTitle),
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineSm(color: scheme.onSurface)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr(AppStrings.monthlySummariesEmptySubtitle),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.mobileMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr(AppStrings.monthlySummariesLoadFailed),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.tr(AppStrings.commonRetry)),
            ),
          ],
        ),
      ),
    );
  }
}
