import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/models/category_model.dart';
import '../../data/models/transaction_model.dart';
import '../providers/categories_provider.dart';
import '../providers/edit_transaction_provider.dart';
import 'category_icon.dart';

/// Opens the small "Edit / Delete" action sheet for a single
/// transaction row. Triggered from a long-press on the history list.
Future<void> showTransactionActionsSheet(
  BuildContext context,
  TransactionModel transaction,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    builder: (sheetContext) {
      return _TransactionActionsSheet(transaction: transaction);
    },
  );
}

class _TransactionActionsSheet extends StatelessWidget {
  const _TransactionActionsSheet({required this.transaction});

  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: AppRadius.brMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionTile(
              icon: Icons.edit_outlined,
              label: context.tr(AppStrings.commonEdit),
              foreground: scheme.primary,
              onTap: () async {
                Navigator.of(context).pop();
                await showEditTransactionSheet(context, transaction);
              },
            ),
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.6)),
            _ActionTile(
              icon: Icons.delete_outline_rounded,
              label: context.tr(AppStrings.commonDelete),
              foreground: scheme.error,
              onTap: () async {
                Navigator.of(context).pop();
                await _confirmAndDelete(context, transaction);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.brMd,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, color: foreground, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMd(color: foreground)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── Delete confirm ──────────────────────────

Future<void> _confirmAndDelete(
  BuildContext context,
  TransactionModel tx,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(dialogContext.tr(AppStrings.transactionsDeleteTitle)),
        content: Text(dialogContext.tr(AppStrings.transactionsDeleteBody)),
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
  if (confirmed != true || !context.mounted) return;
  await _runDelete(context, tx);
}

Future<void> _runDelete(BuildContext context, TransactionModel tx) async {
  final container = ProviderScope.containerOf(context);
  final notifier =
      container.read(editTransactionProvider(tx).notifier);
  final ok = await notifier.delete();
  if (!context.mounted) return;
  if (ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr(AppStrings.transactionsDeleteSuccess)),
      ),
    );
  } else {
    final state = container.read(editTransactionProvider(tx));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.errorMessage ?? context.tr(AppStrings.commonGenericError),
        ),
      ),
    );
  }
}

// ──────────────────────────── Edit sheet ────────────────────────────

Future<bool> showEditTransactionSheet(
  BuildContext context,
  TransactionModel transaction,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) =>
        _EditTransactionSheet(transaction: transaction),
  );
  return result == true;
}

class _EditTransactionSheet extends ConsumerStatefulWidget {
  const _EditTransactionSheet({required this.transaction});

  final TransactionModel transaction;

  @override
  ConsumerState<_EditTransactionSheet> createState() =>
      _EditTransactionSheetState();
}

class _EditTransactionSheetState
    extends ConsumerState<_EditTransactionSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final initial =
        ref.read(editTransactionProvider(widget.transaction));
    _amountController = TextEditingController(text: initial.amountText);
    _noteController = TextEditingController(text: initial.note);
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
    final lang = ref.watch(localeProvider).languageCode;
    final state = ref.watch(editTransactionProvider(widget.transaction));
    final notifier =
        ref.read(editTransactionProvider(widget.transaction).notifier);
    final categoriesAsync = ref.watch(categoriesProvider);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    final dateLabel = DateFormat.yMMMd(lang).format(state.transactionDate);

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
                context.tr(AppStrings.transactionsEditTitle),
                style: AppTextStyles.headlineSm(color: scheme.onSurface)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.md),
              _TypeToggle(
                value: state.type,
                onChanged: notifier.setType,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.tr(AppStrings.transactionsEditAmountLabel),
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
                context.tr(AppStrings.transactionsEditCategoryLabel),
                style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              categoriesAsync.when(
                data: (cats) => _CategoryWrap(
                  categories: cats
                      .where(
                        (c) => state.type == 'expense'
                            ? c.isExpense
                            : !c.isExpense,
                      )
                      .toList(),
                  selectedId: state.categoryId,
                  languageCode: lang,
                  onSelect: (c) =>
                      notifier.setCategory(c.id, type: c.isExpense ? 'expense' : 'income'),
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => Text(
                  context.tr(AppStrings.commonGenericError),
                  style: AppTextStyles.labelSm(color: scheme.error),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.tr(AppStrings.transactionsEditNoteLabel),
                style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _noteController,
                maxLength: 120,
                onChanged: notifier.setNote,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: context.tr(
                    AppStrings.transactionsEditNoteHint,
                  ),
                  border: OutlineInputBorder(borderRadius: AppRadius.brSm),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                borderRadius: AppRadius.brSm,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: state.transactionDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
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
                          '${context.tr(AppStrings.transactionsEditDateLabel)}: '
                          '$dateLabel',
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
                                context.tr(
                                  AppStrings.transactionsEditSuccess,
                                ),
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
                    : Text(
                        context.tr(AppStrings.transactionsEditSubmit),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _ToggleSegment(
            label: context.tr(AppStrings.transactionsTypeExpense),
            selected: value == 'expense',
            onTap: () => onChanged('expense'),
          ),
          _ToggleSegment(
            label: context.tr(AppStrings.transactionsTypeIncome),
            selected: value == 'income',
            onTap: () => onChanged('income'),
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.labelMd(
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _CategoryWrap extends StatelessWidget {
  const _CategoryWrap({
    required this.categories,
    required this.selectedId,
    required this.languageCode,
    required this.onSelect,
  });

  final List<CategoryModel> categories;
  final int selectedId;
  final String languageCode;
  final ValueChanged<CategoryModel> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (categories.isEmpty) {
      return Text(
        context.tr(AppStrings.transactionsEditCategoriesEmpty),
        style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final cat in categories)
          _CategoryChip(
            category: cat,
            selected: cat.id == selectedId,
            languageCode: languageCode,
            onTap: () => onSelect(cat),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.languageCode,
    required this.onTap,
  });

  final CategoryModel category;
  final bool selected;
  final String languageCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = categoryAccentColor(category.color) ?? scheme.primary;
    final bg = selected
        ? accent.withValues(alpha: 0.18)
        : scheme.surfaceContainerLowest;
    final fg = selected ? accent : scheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.sm - 2,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent : scheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(categoryIconFor(category.icon), size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              category.displayName(languageCode),
              style: AppTextStyles.labelSm(color: fg)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
