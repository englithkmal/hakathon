import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/user_currency_provider.dart';
import '../../../home/presentation/widgets/home_app_bar.dart' show HomeUserAvatar;
import '../../../notifications/presentation/widgets/notifications_bell.dart';
import '../../../transactions/data/models/category_model.dart';
import '../../../transactions/presentation/providers/categories_provider.dart';
import '../../../transactions/presentation/widgets/category_icon.dart';
import '../providers/add_budget_category_provider.dart';
import '../providers/budget_tab_provider.dart';

/// "إضافة فئة ميزانية" — picks an existing `Category` from the API,
/// types a monthly limit, and submits it as a budget allocation via
/// `POST /budgets` (when no current-month budget exists yet) or
/// `PUT /budgets/{id}`.
///
/// The category grid is data-driven: it shows expense categories from
/// `GET /categories?type=expense`, automatically excluding the ones
/// already present in the current month's budget so the user can't
/// double-allocate.
class BudgetAddCategoryScreen extends ConsumerStatefulWidget {
  const BudgetAddCategoryScreen({super.key});

  @override
  ConsumerState<BudgetAddCategoryScreen> createState() =>
      _BudgetAddCategoryScreenState();
}

class _BudgetAddCategoryScreenState
    extends ConsumerState<BudgetAddCategoryScreen> {
  final TextEditingController _amountCtrl = TextEditingController();
  final FocusNode _amountFocus = FocusNode();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    final lang = ref.watch(localeProvider).languageCode;

    final state = ref.watch(addBudgetCategoryProvider);
    final notifier = ref.read(addBudgetCategoryProvider.notifier);

    final categoriesAsync = ref.watch(categoriesProvider);
    final budgetTab = ref.watch(budgetTabProvider).valueOrNull;
    // Existing budget wins (user might've created it with another
    // currency). Otherwise fall back to the user's preferred currency
    // from their profile.
    final userCurrency = ref.watch(userCurrencyProvider);
    final currency = (budgetTab?.budget?.currency.isNotEmpty ?? false)
        ? budgetTab!.budget!.currency
        : userCurrency;

    // Categories the user has already allocated this month — they
    // shouldn't appear in the picker because the API treats the row
    // list as a sync (so duplicates would silently overwrite).
    final existing = budgetTab?.budget?.categories
            .map((c) => c.category.id)
            .toSet() ??
        const <int>{};

    final allExpense = categoriesAsync.valueOrNull
            ?.where((c) => c.isExpense)
            .toList() ??
        const <CategoryModel>[];
    final available =
        allExpense.where((c) => !existing.contains(c.id)).toList();

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _AddCategoryAppBar(
        user: user,
        onNotificationsTap: () => context.go(RouteNames.notificationsPath),
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(RouteNames.budgetPath);
          }
        },
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.mobileMargin,
            AppSpacing.md,
            AppSpacing.mobileMargin,
            MediaQuery.viewInsetsOf(context).bottom +
                MediaQuery.paddingOf(context).bottom +
                AppSpacing.lg,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimens.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HeroCard(),
                  const SizedBox(height: AppSpacing.lg),
                  _FieldLabel(
                    text: context.tr(
                      AppStrings.budgetAddLimitLabel,
                      params: {'currency': currency},
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _AmountField(
                    controller: _amountCtrl,
                    focusNode: _amountFocus,
                    currency: currency,
                    onChanged: notifier.setAmount,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FieldLabel(
                    text: context.tr(AppStrings.budgetAddPickIcon),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _CategoryGrid(
                    isLoading: categoriesAsync.isLoading,
                    error: categoriesAsync.error,
                    categories: available,
                    languageCode: lang,
                    selectedId: state.selectedCategoryId,
                    allEmpty: allExpense.isEmpty,
                    onTap: (id) {
                      FocusScope.of(context).unfocus();
                      notifier.selectCategory(id);
                    },
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _InlineError(message: state.errorMessage!),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _SubmitButton(
                    enabled: state.canSubmit,
                    isLoading: state.isSubmitting,
                    onPressed: () => _submit(currency: currency),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _SavingTipCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit({required String currency}) async {
    FocusScope.of(context).unfocus();
    final notifier = ref.read(addBudgetCategoryProvider.notifier);
    final state = ref.read(addBudgetCategoryProvider);

    if (!state.hasCategory) {
      _toast(context.tr(AppStrings.budgetAddErrorPickCategory));
      return;
    }
    if (state.parsedAmount == null) {
      _toast(context.tr(AppStrings.budgetAddErrorAmount));
      return;
    }

    final ok = await notifier.submit(defaultCurrency: currency);
    if (!mounted) return;
    if (ok) {
      _toast(context.tr(AppStrings.budgetAddSuccess), success: true);
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(RouteNames.budgetPath);
      }
    }
  }

  void _toast(String message, {bool success = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? scheme.primary : scheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1800),
        ),
      );
  }
}

// ──────────────────────────── AppBar ────────────────────────────

class _AddCategoryAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _AddCategoryAppBar({
    required this.user,
    required this.onNotificationsTap,
    required this.onBack,
  });

  final dynamic user;
  final VoidCallback onNotificationsTap;
  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(AppDimens.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppDimens.appBarHeight,
          child: Stack(
            children: [
              PositionedDirectional(
                start: AppSpacing.mobileMargin - 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: NotificationsBell(onTap: onNotificationsTap),
                ),
              ),
              PositionedDirectional(
                end: AppSpacing.mobileMargin,
                top: 0,
                bottom: 0,
                child: Center(child: HomeUserAvatar(user: user)),
              ),
              Center(
                child: Text(
                  context.tr(AppStrings.budgetAddTitle),
                  style: AppTextStyles.headlineMd(color: scheme.primary)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              PositionedDirectional(
                end: AppDimens.avatarMd + AppSpacing.mobileMargin + AppSpacing.xs,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: onBack,
                    splashRadius: 22,
                    icon: Icon(
                      isRtl
                          ? Icons.arrow_forward_rounded
                          : Icons.arrow_back_rounded,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────── Hero card ────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: AppRadius.brMd,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.tr(AppStrings.budgetAddHeroTitle),
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLg(color: Colors.white)
                .copyWith(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── Form bits ────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: AppTextStyles.labelMd(color: scheme.onSurface)
          .copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.focusNode,
    required this.currency,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String currency;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 56,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        0,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*([.,]\d{0,2})?'),
                ),
              ],
              textInputAction: TextInputAction.done,
              onChanged: onChanged,
              onTapOutside: (_) => focusNode.unfocus(),
              onSubmitted: (_) => focusNode.unfocus(),
              style: AppTextStyles.headlineSm(color: scheme.onSurface)
                  .copyWith(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '0.00',
                hintStyle: AppTextStyles.headlineSm(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                ).copyWith(fontWeight: FontWeight.w500),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Text(
            currency,
            style: AppTextStyles.labelMd(color: scheme.onSurfaceVariant)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── Category grid ────────────────────────────

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.isLoading,
    required this.error,
    required this.categories,
    required this.languageCode,
    required this.selectedId,
    required this.allEmpty,
    required this.onTap,
  });

  final bool isLoading;
  final Object? error;
  final List<CategoryModel> categories;
  final String languageCode;
  final int? selectedId;
  final bool allEmpty;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    if (isLoading && categories.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null && categories.isEmpty) {
      return _GridMessage(message: error.toString());
    }
    if (categories.isEmpty) {
      return _GridMessage(
        message: context.tr(
          allEmpty
              ? AppStrings.budgetAddNoCategories
              : AppStrings.budgetAddAlreadyAdded,
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.gutter,
        crossAxisSpacing: AppSpacing.gutter,
        childAspectRatio: 1,
      ),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final c = categories[i];
        final isSelected = c.id == selectedId;
        return _CategoryTile(
          category: c,
          languageCode: languageCode,
          isSelected: isSelected,
          onTap: () => onTap(c.id),
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.languageCode,
    required this.isSelected,
    required this.onTap,
  });

  final CategoryModel category;
  final String languageCode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = categoryAccentColor(category.color) ?? scheme.primary;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(
              color: isSelected
                  ? accent
                  : scheme.outlineVariant.withValues(alpha: 0.55),
              width: isSelected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isSelected ? 0.18 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  categoryIconFor(category.icon),
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  category.displayName(languageCode),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSm(color: scheme.onSurface)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridMessage extends StatelessWidget {
  const _GridMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
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

// ──────────────────────────── Submit button ────────────────────────────

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        disabledBackgroundColor: scheme.primary.withValues(alpha: 0.5),
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brSm),
      ),
      child: isLoading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(scheme.onPrimary),
              ),
            )
          : Text(
              context.tr(AppStrings.budgetAddSubmit),
              style: AppTextStyles.labelLg(color: scheme.onPrimary)
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 16),
            ),
    );
  }
}

// ──────────────────────────── Tip card ────────────────────────────

class _SavingTipCard extends StatelessWidget {
  const _SavingTipCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: scheme.primary,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                context.tr(AppStrings.budgetAddTipTitle),
                style: AppTextStyles.labelMd(color: scheme.onSurface)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr(AppStrings.budgetAddTipBody),
            style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant)
                .copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: AppRadius.brSm,
        border: Border.all(
          color: scheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: scheme.error,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.labelSm(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
