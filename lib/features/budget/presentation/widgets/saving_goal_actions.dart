import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/models/saving_goal_model.dart';
import '../providers/edit_saving_goal_provider.dart';

/// Returns a localised display label for a `saving_goals.status` value.
String _statusLabel(BuildContext context, String value) {
  switch (value) {
    case 'paused':
      return context.tr(AppStrings.goalStatusPaused);
    case 'cancelled':
      return context.tr(AppStrings.goalStatusCancelled);
    case 'achieved':
      return context.tr(AppStrings.goalStatusAchieved);
    case 'active':
    default:
      return context.tr(AppStrings.goalStatusActive);
  }
}

/// Opens the "Edit goal" bottom sheet. Returns `true` when the goal
/// was successfully updated so the caller can show a snackbar.
Future<bool> showEditSavingGoalSheet(
  BuildContext context,
  SavingGoalModel goal,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _EditSavingGoalSheet(goal: goal),
  );
  return result == true;
}

/// Confirms + deletes the goal. Returns `true` when the deletion went
/// through so the caller can pop the goal-detail screen.
Future<bool> confirmDeleteSavingGoal(
  BuildContext context,
  WidgetRef ref,
  SavingGoalModel goal,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(dialogContext.tr(AppStrings.goalDeleteTitle)),
        content: Text(
          dialogContext.tr(
            AppStrings.goalDeleteBody,
            params: {'title': goal.title},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.tr(AppStrings.commonCancel)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.tr(AppStrings.commonDelete)),
          ),
        ],
      );
    },
  );
  if (confirmed != true) return false;
  final notifier = ref.read(editSavingGoalProvider(goal).notifier);
  final ok = await notifier.delete();
  if (!context.mounted) return ok;
  if (ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr(AppStrings.goalDeleteSuccess))),
    );
  } else {
    final state = ref.read(editSavingGoalProvider(goal));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.errorMessage ?? context.tr(AppStrings.commonGenericError),
        ),
      ),
    );
  }
  return ok;
}

class _EditSavingGoalSheet extends ConsumerStatefulWidget {
  const _EditSavingGoalSheet({required this.goal});

  final SavingGoalModel goal;

  @override
  ConsumerState<_EditSavingGoalSheet> createState() =>
      _EditSavingGoalSheetState();
}

class _EditSavingGoalSheetState extends ConsumerState<_EditSavingGoalSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(editSavingGoalProvider(widget.goal));
    _titleController = TextEditingController(text: initial.title);
    _amountController = TextEditingController(text: initial.amountText);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lang = ref.watch(localeProvider).languageCode;
    final state = ref.watch(editSavingGoalProvider(widget.goal));
    final notifier = ref.read(editSavingGoalProvider(widget.goal).notifier);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    final deadlineLabel = state.deadline == null
        ? context.tr(AppStrings.budgetAddGoalDeadlineHint)
        : DateFormat.yMMMd(lang).format(state.deadline!);

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
                context.tr(AppStrings.goalEditTitle),
                style: AppTextStyles.headlineSm(color: scheme.onSurface)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.tr(AppStrings.budgetAddGoalNameLabel),
                style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _titleController,
                onChanged: notifier.setTitle,
                decoration: InputDecoration(
                  hintText: context.tr(AppStrings.budgetAddGoalNameHint),
                  border: OutlineInputBorder(borderRadius: AppRadius.brSm),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.tr(AppStrings.budgetAddGoalAmountLabel),
                style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: notifier.setAmount,
                decoration: InputDecoration(
                  hintText: '0.00',
                  suffixText: state.original.currency,
                  border: OutlineInputBorder(borderRadius: AppRadius.brSm),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.tr(AppStrings.budgetAddGoalDeadlineLabel),
                style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              InkWell(
                borderRadius: AppRadius.brSm,
                onTap: () async {
                  final today = DateTime.now();
                  final initial = state.deadline ??
                      today.add(const Duration(days: 30));
                  final picked = await showDatePicker(
                    context: context,
                    initialDate:
                        initial.isAfter(today) ? initial : today,
                    firstDate: today,
                    lastDate: DateTime(today.year + 30),
                  );
                  if (picked != null) notifier.setDeadline(picked);
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
                          deadlineLabel,
                          style: AppTextStyles.labelMd(
                            color: scheme.onSurface,
                          ),
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
              const SizedBox(height: AppSpacing.md),
              Text(
                context.tr(AppStrings.goalEditStatusLabel),
                style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final value in kSavingGoalStatuses)
                    _StatusChip(
                      label: _statusLabel(context, value),
                      selected: state.status == value,
                      onTap: () => notifier.setStatus(value),
                    ),
                ],
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
                onPressed: state.canSubmit && state.isDirty
                    ? () async {
                        final updated = await notifier.submit();
                        if (updated != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.tr(AppStrings.goalEditSuccess),
                              ),
                            ),
                          );
                          Navigator.of(context).pop(true);
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
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(context.tr(AppStrings.goalEditSubmit)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected
        ? scheme.primary.withValues(alpha: 0.12)
        : scheme.surfaceContainerLowest;
    final fg = selected ? scheme.primary : scheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSm(color: fg)
              .copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
