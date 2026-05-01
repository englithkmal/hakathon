import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../budget/data/models/saving_goal_model.dart';
import '../../../budget/presentation/providers/budget_tab_provider.dart';
import '../../../home/presentation/utils/home_money.dart';
import '../../data/models/monthly_summary_model.dart';
import '../providers/allocate_monthly_surplus_provider.dart';

/// Opens the bottom sheet that lets the user split a monthly summary's
/// `unallocated_surplus` across one or more saving goals.
///
/// Returns the updated [MonthlySummaryModel] when the user successfully
/// submits at least one allocation, otherwise `null`.
Future<MonthlySummaryModel?> showAllocateSurplusSheet(
  BuildContext context,
  MonthlySummaryModel summary,
) {
  return showModalBottomSheet<MonthlySummaryModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _AllocateSurplusSheet(summary: summary),
  );
}

class _AllocateSurplusSheet extends ConsumerWidget {
  const _AllocateSurplusSheet({required this.summary});

  final MonthlySummaryModel summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(allocateMonthlySurplusProvider(summary));
    final notifier =
        ref.read(allocateMonthlySurplusProvider(summary).notifier);

    final goals = ref.watch(budgetTabProvider).valueOrNull?.goals ?? const [];
    final activeGoals =
        goals.where((g) => g.status == 'active').toList(growable: false);

    final viewInsets = MediaQuery.viewInsetsOf(context);
    final remainingLabel = context.tr(
      AppStrings.allocateSheetRemaining,
      params: {
        'amount': kHomeMoneyFormat.format(state.remaining),
        'currency': summary.currency,
      },
    );

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
        child: SingleChildScrollView(
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
                context.tr(AppStrings.allocateSheetTitle),
                style: AppTextStyles.headlineSm(color: scheme.onSurface)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(AppStrings.allocateSheetIntro),
                style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              if (activeGoals.isEmpty)
                _NoGoalsCard()
              else ...[
                for (var i = 0; i < state.rows.length; i++) ...[
                  _AllocateRow(
                    index: i,
                    row: state.rows[i],
                    goals: activeGoals,
                    currency: summary.currency,
                    canRemove: state.rows.length > 1,
                    onGoalChanged: (id) => notifier.setRowGoal(i, id),
                    onAmountChanged: (v) => notifier.setRowAmount(i, v),
                    onRemove: () => notifier.removeRow(i),
                  ),
                  if (i < state.rows.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: state.rows.length >= activeGoals.length
                        ? null
                        : notifier.addRow,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      context.tr(AppStrings.allocateSheetAddRow),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  remainingLabel,
                  style: AppTextStyles.labelMd(
                    color: state.hasOverflow
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                if (state.hasOverflow) ...[
                  const SizedBox(height: 4),
                  Text(
                    context.tr(AppStrings.allocateSheetOverflow),
                    style: AppTextStyles.labelSm(color: scheme.error),
                  ),
                ],
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.tr(
                                    AppStrings.allocateSheetSuccess,
                                  ),
                                ),
                              ),
                            );
                            Navigator.of(context).pop(updated);
                          }
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.brSm,
                    ),
                  ),
                  child: state.isSubmitting
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            // When the user kicked off > 1 allocation,
                            // surface a "1/3 ↻" hint so they know the
                            // sheet isn't frozen mid-batch (the new
                            // server contract serialises the calls).
                            if (state.totalRowsToSubmit > 1) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                '${state.submittedRows}/${state.totalRowsToSubmit}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        )
                      : Text(context.tr(AppStrings.allocateSheetSubmit)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AllocateRow extends StatefulWidget {
  const _AllocateRow({
    required this.index,
    required this.row,
    required this.goals,
    required this.currency,
    required this.canRemove,
    required this.onGoalChanged,
    required this.onAmountChanged,
    required this.onRemove,
  });

  final int index;
  final AllocateRowDraft row;
  final List<SavingGoalModel> goals;
  final String currency;
  final bool canRemove;
  final ValueChanged<int?> onGoalChanged;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onRemove;

  @override
  State<_AllocateRow> createState() => _AllocateRowState();
}

class _AllocateRowState extends State<_AllocateRow> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.row.amountText);
  }

  @override
  void didUpdateWidget(_AllocateRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.amountText != widget.row.amountText &&
        widget.row.amountText != _amountController.text) {
      _amountController.text = widget.row.amountText;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(AppStrings.allocateSheetGoalLabel),
            style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<int?>(
            value: widget.row.savingGoalId,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: AppRadius.brSm),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 12,
              ),
            ),
            hint: Text(
              context.tr(AppStrings.allocateSheetGoalPlaceholder),
            ),
            items: [
              for (final g in widget.goals)
                DropdownMenuItem<int?>(
                  value: g.id,
                  child: Text(
                    g.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: widget.onGoalChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr(AppStrings.allocateSheetAmountLabel),
            style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: widget.onAmountChanged,
            decoration: InputDecoration(
              hintText: '0.00',
              suffixText: widget.currency,
              border: OutlineInputBorder(borderRadius: AppRadius.brSm),
            ),
          ),
          if (widget.canRemove) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: widget.onRemove,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: scheme.error,
                ),
                label: Text(
                  context.tr(AppStrings.allocateSheetRemoveRow),
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoGoalsCard extends StatelessWidget {
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
        context.tr(AppStrings.allocateSheetNoGoals),
        style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
