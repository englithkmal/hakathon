import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../home/presentation/utils/home_money.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/presentation/widgets/category_icon.dart';
import '../../data/models/goal_monthly_progress.dart';
import '../../data/models/saving_goal_model.dart';
import '../providers/budget_tab_provider.dart';
import '../providers/saving_goal_detail_provider.dart';
import '../utils/goal_pace_palette.dart';
import '../widgets/saving_goal_actions.dart';

/// Detail screen for a single saving goal.
///
/// Wires together:
///   - the cached goal record from [budgetTabProvider] so we don't pay
///     a round trip just to render the header (the deposit response
///     already kicks the budget tab to refresh, which trickles down
///     to here),
///   - `GET /saving-goals/{id}/monthly-progress` for the chart,
///   - `GET /saving-goals/{id}/deposits` for the recent-deposits list,
///   - `POST /saving-goals/{id}/deposit` via [goalDepositProvider] for
///     the bottom-sheet deposit form.
class SavingGoalDetailScreen extends ConsumerWidget {
  const SavingGoalDetailScreen({super.key, required this.goalId});

  final int goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final lang = ref.watch(localeProvider).languageCode;

    final tabAsync = ref.watch(budgetTabProvider);
    final goal = _findGoal(tabAsync.valueOrNull?.goals, goalId);

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
          context.tr(AppStrings.goalDetailTitle),
          style: AppTextStyles.headlineSm(color: scheme.onSurface)
              .copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          if (goal != null)
            PopupMenuButton<_GoalMenuAction>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) => _onMenuAction(context, ref, goal, action),
              itemBuilder: (popupContext) => [
                PopupMenuItem<_GoalMenuAction>(
                  value: _GoalMenuAction.edit,
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Text(popupContext.tr(AppStrings.commonEdit)),
                    ],
                  ),
                ),
                PopupMenuItem<_GoalMenuAction>(
                  value: _GoalMenuAction.delete,
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: scheme.error,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        popupContext.tr(AppStrings.commonDelete),
                        style: TextStyle(color: scheme.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: goal == null
          ? _NotFoundState(onRetry: () => ref.invalidate(budgetTabProvider))
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(goalMonthlyProgressProvider(goalId));
                ref.invalidate(goalRecentDepositsProvider(goalId));
                await ref.read(budgetTabProvider.notifier).refresh();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.mobileMargin,
                  AppSpacing.md,
                  AppSpacing.mobileMargin,
                  MediaQuery.paddingOf(context).bottom + AppSpacing.xl + 80,
                ),
                children: [
                  _GoalHeaderCard(goal: goal),
                  const SizedBox(height: AppSpacing.md),
                  _PaceCard(goal: goal),
                  const SizedBox(height: AppSpacing.lg),
                  _MonthlyProgressSection(goalId: goalId, languageCode: lang),
                  const SizedBox(height: AppSpacing.lg),
                  _RecentDepositsSection(
                    goalId: goalId,
                    languageCode: lang,
                    fallbackCurrency: goal.currency,
                  ),
                ],
              ),
            ),
      floatingActionButton: goal == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openDepositSheet(context, ref, goal),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr(AppStrings.goalDepositCta)),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
    );
  }

  static SavingGoalModel? _findGoal(List<SavingGoalModel>? goals, int id) {
    if (goals == null) return null;
    for (final g in goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  Future<void> _openDepositSheet(
    BuildContext context,
    WidgetRef ref,
    SavingGoalModel goal,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          _DepositSheet(goalId: goal.id, currency: goal.currency),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(AppStrings.goalDepositSuccess))),
      );
    }
  }

  Future<void> _onMenuAction(
    BuildContext context,
    WidgetRef ref,
    SavingGoalModel goal,
    _GoalMenuAction action,
  ) async {
    switch (action) {
      case _GoalMenuAction.edit:
        await showEditSavingGoalSheet(context, goal);
      case _GoalMenuAction.delete:
        final ok = await confirmDeleteSavingGoal(context, ref, goal);
        if (ok && context.mounted) {
          // Goal is gone — bail out of the detail screen so the user
          // lands back on the budget tab where the card has already
          // disappeared.
          Navigator.of(context).maybePop();
        }
    }
  }
}

enum _GoalMenuAction { edit, delete }

// ──────────────────────────── Header card ────────────────────────────

class _GoalHeaderCard extends StatelessWidget {
  const _GoalHeaderCard({required this.goal});

  final SavingGoalModel goal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = categoryAccentColor(goal.color) ?? scheme.primary;
    final pct = (goal.progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: goal.progress,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    backgroundColor:
                        scheme.outlineVariant.withValues(alpha: 0.4),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                Icon(categoryIconFor(goal.icon), color: accent, size: 24),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  goal.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineSm(color: scheme.onSurface)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '${kHomeMoneyFormat.format(goal.currentAmount)}'
                      ' / '
                      '${kHomeMoneyFormat.format(goal.targetAmount)}'
                      ' ${goal.currency}',
                      style: AppTextStyles.bodyMd(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$pct%',
                  style: AppTextStyles.labelMd(color: accent)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── Pace card ────────────────────────────

class _PaceCard extends StatelessWidget {
  const _PaceCard({required this.goal});

  final SavingGoalModel goal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pace = goal.pace;
    final visuals = goalPaceVisuals(
      context,
      pace?.status ?? GoalPaceStatus.unknown,
    );

    final monthlyTarget = pace?.monthlyTarget ?? 0;
    final expectedToday = pace?.expectedAtToday ?? 0;
    final delta = pace?.delta ?? 0;

    String deltaLabel;
    if (pace == null ||
        pace.status == GoalPaceStatus.unscheduled ||
        pace.status == GoalPaceStatus.inactive ||
        pace.status == GoalPaceStatus.unknown) {
      deltaLabel = '';
    } else if (delta > 0.5) {
      deltaLabel = context.tr(
        AppStrings.goalDetailDeltaAhead,
        params: {'amount': kHomeMoneyFormat.format(delta.abs())},
      );
    } else if (delta < -0.5) {
      deltaLabel = context.tr(
        AppStrings.goalDetailDeltaBehind,
        params: {'amount': kHomeMoneyFormat.format(delta.abs())},
      );
    } else {
      deltaLabel = context.tr(AppStrings.goalDetailDeltaOnTrack);
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (visuals.label.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _PacePill(visuals: visuals),
            ),
          if (visuals.label.isNotEmpty) const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _PaceMetric(
                  label: context.tr(AppStrings.goalDetailMonthlyTarget),
                  value: kHomeMoneyFormat.format(monthlyTarget),
                  suffix: goal.currency,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _PaceMetric(
                  label: context.tr(AppStrings.goalDetailExpectedToday),
                  value: kHomeMoneyFormat.format(expectedToday),
                  suffix: goal.currency,
                ),
              ),
            ],
          ),
          if (deltaLabel.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              deltaLabel,
              style: AppTextStyles.labelMd(
                color: visuals.foreground,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _PacePill extends StatelessWidget {
  const _PacePill({required this.visuals});

  final GoalPaceVisuals visuals;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: visuals.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visuals.icon, size: 14, color: visuals.foreground),
          const SizedBox(width: 4),
          Text(
            visuals.label,
            style: AppTextStyles.labelSm(color: visuals.foreground)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PaceMetric extends StatelessWidget {
  const _PaceMetric({
    required this.label,
    required this.value,
    required this.suffix,
  });

  final String label;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Directionality(
          textDirection: TextDirection.ltr,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              '$value $suffix',
              style: AppTextStyles.headlineSm(color: scheme.onSurface)
                  .copyWith(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────── Monthly progress ────────────────────────────

class _MonthlyProgressSection extends ConsumerWidget {
  const _MonthlyProgressSection({
    required this.goalId,
    required this.languageCode,
  });

  final int goalId;
  final String languageCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProgress = ref.watch(goalMonthlyProgressProvider(goalId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr(AppStrings.goalDetailMonthlyProgress),
          style: AppTextStyles.headlineSm(
            color: Theme.of(context).colorScheme.onSurface,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        asyncProgress.when(
          data: (progress) => _MonthlyProgressCard(
            progress: progress,
            languageCode: languageCode,
          ),
          loading: () => const _LoadingCard(),
          error: (_, __) => const _ErrorCard(),
        ),
      ],
    );
  }
}

class _MonthlyProgressCard extends StatelessWidget {
  const _MonthlyProgressCard({
    required this.progress,
    required this.languageCode,
  });

  final GoalMonthlyProgress progress;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (progress.items.isEmpty) {
      return _EmptyCard(
        message: context.tr(AppStrings.goalDetailMonthlyProgressEmpty),
      );
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < progress.items.length; i++) ...[
            _MonthRow(
              item: progress.items[i],
              currency: progress.currency,
              languageCode: languageCode,
            ),
            if (i < progress.items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.item,
    required this.currency,
    required this.languageCode,
  });

  final GoalMonthlyProgressItem item;
  final String currency;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthName = DateFormat.yMMMM(languageCode)
        .format(DateTime(item.year, item.month, 1));
    final coverage = item.coverage.clamp(0.0, 1.0);
    final progressColor = item.onTrack ? AppColors.green500 : AppColors.amber500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                monthName,
                style: AppTextStyles.labelMd(color: scheme.onSurface)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${kHomeMoneyFormat.format(item.deposited)} / '
                '${kHomeMoneyFormat.format(item.expected)} $currency',
                style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: coverage,
            minHeight: 6,
            backgroundColor: scheme.outlineVariant.withValues(alpha: 0.5),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────── Recent deposits ────────────────────────────

class _RecentDepositsSection extends ConsumerWidget {
  const _RecentDepositsSection({
    required this.goalId,
    required this.languageCode,
    required this.fallbackCurrency,
  });

  final int goalId;
  final String languageCode;
  final String fallbackCurrency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPage = ref.watch(goalRecentDepositsProvider(goalId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr(AppStrings.goalDetailRecentDeposits),
          style: AppTextStyles.headlineSm(
            color: Theme.of(context).colorScheme.onSurface,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        asyncPage.when(
          data: (page) => _RecentDepositsCard(
            items: page.items,
            languageCode: languageCode,
            fallbackCurrency: fallbackCurrency,
          ),
          loading: () => const _LoadingCard(),
          error: (_, __) => const _ErrorCard(),
        ),
      ],
    );
  }
}

class _RecentDepositsCard extends StatelessWidget {
  const _RecentDepositsCard({
    required this.items,
    required this.languageCode,
    required this.fallbackCurrency,
  });

  final List<TransactionModel> items;
  final String languageCode;
  final String fallbackCurrency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return _EmptyCard(
        message: context.tr(AppStrings.goalDetailRecentDepositsEmpty),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _DepositRow(
              tx: items[i],
              languageCode: languageCode,
              fallbackCurrency: fallbackCurrency,
            ),
            if (i < items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }
}

class _DepositRow extends StatelessWidget {
  const _DepositRow({
    required this.tx,
    required this.languageCode,
    required this.fallbackCurrency,
  });

  final TransactionModel tx;
  final String languageCode;
  final String fallbackCurrency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = DateTime.tryParse(tx.transactionDate);
    final dateLabel = date != null
        ? DateFormat.yMMMd(languageCode).format(date)
        : tx.transactionDate;
    final currency = tx.currency.isNotEmpty ? tx.currency : fallbackCurrency;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.green100,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.savings_rounded,
              color: AppColors.green700,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description.isNotEmpty
                      ? tx.description
                      : context.tr(AppStrings.goalDepositCta),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMd(color: scheme.onSurface)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: AppTextStyles.labelSm(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '+${kHomeMoneyFormat.format(tx.amount)} $currency',
              style: AppTextStyles.labelMd(color: AppColors.green700)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── Deposit sheet ────────────────────────────

class _DepositSheet extends ConsumerStatefulWidget {
  const _DepositSheet({required this.goalId, required this.currency});

  final int goalId;
  final String currency;

  @override
  ConsumerState<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends ConsumerState<_DepositSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(goalDepositProvider(widget.goalId));
    final notifier = ref.read(goalDepositProvider(widget.goalId).notifier);
    final lang = ref.watch(localeProvider).languageCode;
    final dateLabel = state.transactionDate == null
        ? context.tr(AppStrings.goalDepositDateToday)
        : DateFormat.yMMMd(lang).format(state.transactionDate!);

    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.mobileMargin,
          AppSpacing.md,
          AppSpacing.mobileMargin,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              context.tr(AppStrings.goalDepositSheetTitle),
              style: AppTextStyles.headlineSm(color: scheme.onSurface)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.tr(AppStrings.goalDepositAmountLabel),
              style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: notifier.setAmount,
              decoration: InputDecoration(
                hintText: context.tr(AppStrings.goalDepositAmountHint),
                suffixText: widget.currency,
                border: OutlineInputBorder(borderRadius: AppRadius.brSm),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.tr(AppStrings.goalDepositNoteLabel),
              style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _noteController,
              maxLength: 120,
              onChanged: notifier.setNote,
              decoration: InputDecoration(
                hintText: context.tr(AppStrings.goalDepositNoteHint),
                counterText: '',
                border: OutlineInputBorder(borderRadius: AppRadius.brSm),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              borderRadius: AppRadius.brSm,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: state.transactionDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) notifier.setDate(picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.brSm,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${context.tr(AppStrings.goalDepositDateLabel)}: '
                        '$dateLabel',
                        style: AppTextStyles.labelMd(color: scheme.onSurface),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                state.errorMessage!,
                style: AppTextStyles.labelSm(color: scheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: state.canSubmit
                  ? () async {
                      final updated = await notifier.submit();
                      if (updated != null && context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.brSm),
              ),
              child: state.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(context.tr(AppStrings.goalDepositSubmit)),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────── Helpers ────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        context.tr(AppStrings.goalDetailLoadFailed),
        style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _NotFoundState extends StatelessWidget {
  const _NotFoundState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.mobileMargin),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.tr(AppStrings.goalDetailLoadFailed),
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
