import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../auth/presentation/providers/user_currency_provider.dart';
import '../../data/models/category_model.dart';
import '../providers/add_transaction_provider.dart';
import '../providers/categories_provider.dart';
import '../widgets/add_transaction_amount_display.dart';
import '../widgets/add_transaction_category_grid.dart';
import '../widgets/add_transaction_keypad.dart';
import '../widgets/add_transaction_note_date_row.dart';
import '../widgets/transaction_type_toggle.dart';

/// Full-screen "Add transaction" sheet.
///
/// Layout (top to bottom, mirrors the Figma reference):
///   X                       تصميم العنوان
///   ───── pill toggle مصروف/دخل ─────
///   SAR 0.00 (huge centred)
///   "أدخل المبلغ"
///   Category grid (5 cells)
///   ملاحظة + التاريخ row
///   3×4 numeric keypad
///   Big "حفظ المعاملة" CTA
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late final TextEditingController _noteController;
  late final FocusNode _noteFocusNode;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
      text: ref.read(addTransactionProvider).note,
    );
    _noteController.addListener(_syncNote);
    _noteFocusNode = FocusNode();
    // Drive the keypad show/hide off the note field's focus, not the
    // system viewInsets. The MediaQuery-based path was racy: closing
    // the keyboard via the back gesture sometimes left the screen in
    // "keyboard open" layout because the rebuild fired before insets
    // settled, or the field stayed focused with no keyboard visible.
    // Tracking focus directly is deterministic.
    _noteFocusNode.addListener(_onNoteFocusChanged);
  }

  @override
  void dispose() {
    _noteController.removeListener(_syncNote);
    _noteController.dispose();
    _noteFocusNode.removeListener(_onNoteFocusChanged);
    _noteFocusNode.dispose();
    super.dispose();
  }

  void _syncNote() {
    final notifier = ref.read(addTransactionProvider.notifier);
    if (_noteController.text != ref.read(addTransactionProvider).note) {
      notifier.setNote(_noteController.text);
    }
  }

  void _onNoteFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(addTransactionProvider);
    final notifier = ref.read(addTransactionProvider.notifier);
    final lang = ref.watch(localeProvider).languageCode;
    // `userCurrencyProvider` already prefers the dashboard's
    // server-provided currency and only falls back to the cached
    // `auth.user.currency` if the dashboard isn't ready yet — exactly
    // the resolution we want for the keypad header.
    final dashCurrency = ref.watch(userCurrencyProvider);

    // Hide the custom keypad while the user is editing the note. Using
    // the focus node (instead of `MediaQuery.viewInsetsOf`) avoids the
    // "keyboard closed but layout stuck" glitch the MediaQuery path
    // could produce on Android.
    final noteEditing = _noteFocusNode.hasFocus;

    final title = state.type == 'income'
        ? context.tr(AppStrings.transactionsAddIncomeTitle)
        : context.tr(AppStrings.transactionsAddExpenseTitle);

    final filteredAsync = ref
        .watch(categoriesProvider)
        .whenData(
          (all) => all
              .where(
                (c) => state.type == 'expense' ? c.isExpense : !c.isExpense,
              )
              .toList(),
        );

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: context.tr(AppStrings.commonClose),
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _close(),
        ),
        title: Text(
          title,
          style: AppTextStyles.headlineMd(
            color: scheme.primary,
          ).copyWith(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
      ),
      // The body keeps a stable shape across keyboard show/hide:
      //   SafeArea > Padding > SingleChildScrollView > Column.
      // We never swap the parent widget type — only the *contents* of
      // the column change (the custom keypad is hidden while the system
      // keyboard is open). Swapping the parent (e.g. Column -> Scroll)
      // would unmount the note `TextField`, which immediately steals
      // focus back and the system keyboard would close right after it
      // opened. Keeping the same tree preserves the focus.
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.mobileMargin,
            AppSpacing.sm,
            AppSpacing.mobileMargin,
            AppSpacing.md,
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TransactionTypeToggle(
                  value: state.type,
                  onChanged: notifier.setType,
                  variant: TransactionTypeToggleVariant.light,
                ),
                const SizedBox(height: AppSpacing.lg),
                AddTransactionAmountDisplay(
                  amountText: state.amountText,
                  currency: dashCurrency,
                ),
                const SizedBox(height: AppSpacing.lg),
                _CategorySection(
                  async: filteredAsync,
                  state: state,
                  notifier: notifier,
                  languageCode: lang,
                ),
                const SizedBox(height: AppSpacing.md),
                AddTransactionNoteDateRow(
                  noteController: _noteController,
                  noteFocusNode: _noteFocusNode,
                  date: state.transactionDate,
                  onPickDate: notifier.setDate,
                ),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    state.errorMessage!,
                    style: AppTextStyles.labelMd(color: scheme.error),
                  ),
                ],
                if (!noteEditing) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AddTransactionKeypad(
                    onDigit: notifier.pressDigit,
                    onDecimal: notifier.pressDecimal,
                    onBackspace: notifier.pressBackspace,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: state.canSubmit ? () => _submit() : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.brSm,
                      ),
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      textStyle: AppTextStyles.labelLg(
                        color: scheme.onPrimary,
                      ).copyWith(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    child: state.isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(context.tr(AppStrings.transactionsSaveButton)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final scheme = Theme.of(context).colorScheme;
    FocusManager.instance.primaryFocus?.unfocus();
    // Use the same resolved currency the keypad header showed so the
    // saved row matches what the user typed under.
    final currency = ref.read(userCurrencyProvider);
    final ok = await ref
        .read(addTransactionProvider.notifier)
        .submit(currency: currency);
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: scheme.primary,
        content: Text(
          context.tr(AppStrings.transactionsCreated),
          style: AppTextStyles.labelMd(color: scheme.onPrimary),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _close();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/transactions');
    }
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.async,
    required this.state,
    required this.notifier,
    required this.languageCode,
  });

  final AsyncValue<List<CategoryModel>> async;
  final AddTransactionState state;
  final AddTransactionNotifier notifier;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              context.tr(AppStrings.transactionsCategory),
              style: AppTextStyles.labelMd(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        async.when(
          data: (list) {
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: Text(
                    context.tr(AppStrings.transactionsCategoriesEmpty),
                    style: AppTextStyles.labelMd(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            return AddTransactionCategoryGrid(
              categories: list,
              selectedId: state.categoryId,
              onSelected: notifier.selectCategory,
              languageCode: languageCode,
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: Text(
                context.tr(AppStrings.commonError),
                style: AppTextStyles.labelMd(color: scheme.error),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
