import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../providers/add_transaction_provider.dart';
import '../providers/categories_provider.dart';
import 'quick_field_pickers.dart';

/// "إضافة معاملة سريعة" — the inline quick-add card pinned to the top
/// of the Transactions tab.
///
/// Layout (matches the Figma reference):
///   • title              "إضافة معاملة سريعة"
///   • amount field       0.00 .................... SAR
///   • category + date    [طعام ▾]   [اليوم 📅]
///   • note field         [أضف ملاحظة...] ✎
///   • CTA                [+ حفظ المعاملة] (green, full width)
///
/// The transaction `type` is derived automatically from the picked
/// category, so the user never sees an expense/income toggle here.
class AddTransactionCard extends ConsumerStatefulWidget {
  const AddTransactionCard({super.key, required this.currency});

  final String currency;

  @override
  ConsumerState<AddTransactionCard> createState() =>
      _AddTransactionCardState();
}

class _AddTransactionCardState extends ConsumerState<AddTransactionCard> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(addTransactionProvider);
    _amountController = TextEditingController(
      text: initial.amount > 0 ? initial.amount.toStringAsFixed(2) : '',
    );
    _noteController = TextEditingController(text: initial.note);
    _noteController.addListener(_syncNote);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.removeListener(_syncNote);
    _noteController.dispose();
    super.dispose();
  }

  void _syncNote() {
    final notifier = ref.read(addTransactionProvider.notifier);
    if (_noteController.text != ref.read(addTransactionProvider).note) {
      notifier.setNote(_noteController.text);
    }
  }

  Future<void> _submit(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final successText = context.tr(AppStrings.transactionsCreated);
    final ok = await ref
        .read(addTransactionProvider.notifier)
        .submit(currency: widget.currency);
    if (!ok || !mounted) return;
    _amountController.clear();
    _noteController.clear();
    messenger.showSnackBar(
      SnackBar(
        content: Text(successText),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(addTransactionProvider);
    final notifier = ref.read(addTransactionProvider.notifier);
    final lang = Localizations.localeOf(context).languageCode;
    final categoriesAsync = ref.watch(categoriesProvider);

    // Reset the local amount controller text whenever the underlying
    // state is cleared (e.g. after a successful submit).
    if (state.amount == 0 && _amountController.text.isNotEmpty) {
      _amountController.clear();
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              context.tr(AppStrings.transactionsAddSection),
              style: AppTextStyles.headlineMd(color: scheme.primary).copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _AmountRow(
            controller: _amountController,
            currency: widget.currency,
            onChanged: notifier.setAmount,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: categoriesAsync.when(
                  data: (cats) => QuickCategoryPicker(
                    categories: cats,
                    selectedId: state.categoryId,
                    onSelected: notifier.selectCategory,
                    languageCode: lang,
                  ),
                  loading: () => const _PickerSkeleton(),
                  error: (_, __) => _PickerError(
                    onRetry: () => ref.invalidate(categoriesProvider),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
              Expanded(
                child: QuickDatePicker(
                  date: state.transactionDate,
                  onChanged: notifier.setDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _NoteRow(controller: _noteController),
          if (state.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.errorMessage!,
              style: AppTextStyles.labelMd(color: scheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: state.canSubmit ? () => _submit(context) : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.brSm,
              ),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              textStyle: AppTextStyles.labelLg(color: scheme.onPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            icon: state.isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_circle_outline_rounded, size: 20),
            label: Text(context.tr(AppStrings.transactionsSaveButton)),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.controller,
    required this.currency,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String currency;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            context.tr(AppStrings.transactionsAmount),
            style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          height: 48,
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.sm + AppSpacing.xs,
            end: AppSpacing.sm + AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: AppRadius.brSm,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.start,
                  textDirection: TextDirection.ltr,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: AppTextStyles.bodyMd(color: scheme.onSurface)
                      .copyWith(fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: '0.00',
                    hintStyle: AppTextStyles.bodyMd(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  onChanged: (raw) {
                    final normalised = raw.replaceAll(',', '.');
                    final parsed = double.tryParse(normalised) ?? 0;
                    onChanged(parsed);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                currency,
                style: AppTextStyles.bodyMd(color: scheme.primary).copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            context.tr(AppStrings.transactionsNoteLabel),
            style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          height: 48,
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.sm + AppSpacing.xs,
            end: AppSpacing.sm + AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: AppRadius.brSm,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.done,
                  style: AppTextStyles.bodySm(color: scheme.onSurface),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: context.tr(AppStrings.transactionsNoteHint),
                    hintStyle: AppTextStyles.bodySm(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.edit_note_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickerSkeleton extends StatelessWidget {
  const _PickerSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: AppRadius.brSm,
          ),
        ),
      ],
    );
  }
}

class _PickerError extends StatelessWidget {
  const _PickerError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Center(
        child: TextButton(
          onPressed: onRetry,
          child: Text(context.tr(AppStrings.commonRetry)),
        ),
      ),
    );
  }
}
