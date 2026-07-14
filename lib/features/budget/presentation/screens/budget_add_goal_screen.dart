import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/user_currency_provider.dart';
import '../../../home/presentation/utils/home_money.dart';
import '../../../home/presentation/widgets/home_app_bar.dart' show HomeUserAvatar;
import '../../../notifications/presentation/widgets/notifications_bell.dart';
import '../../../transactions/presentation/widgets/category_icon.dart';
import '../providers/add_saving_goal_provider.dart';
import '../providers/budget_tab_provider.dart';

/// "إضافة هدف جديد" — collects the inputs for `POST /saving-goals`:
/// `title`, `target_amount`, `deadline`, `icon`, `color`. Renders a
/// live "monthly forecast" so the user sees how much they need to set
/// aside each month before they commit.
class BudgetAddGoalScreen extends ConsumerStatefulWidget {
  const BudgetAddGoalScreen({super.key});

  @override
  ConsumerState<BudgetAddGoalScreen> createState() =>
      _BudgetAddGoalScreenState();
}

class _BudgetAddGoalScreenState extends ConsumerState<BudgetAddGoalScreen> {
  final _amountCtrl = TextEditingController();
  final _amountFocus = FocusNode();

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

    final state = ref.watch(addSavingGoalProvider);
    final notifier = ref.read(addSavingGoalProvider.notifier);

    final budget = ref.watch(budgetTabProvider).valueOrNull?.budget;
    // Goals usually inherit the budget's currency (so categories +
    // goals stay aligned). When no budget exists yet, we fall back to
    // the user's profile preference.
    final userCurrency = ref.watch(userCurrencyProvider);
    final currency = (budget?.currency.isNotEmpty ?? false)
        ? budget!.currency
        : userCurrency;
    final lang = ref.watch(localeProvider).languageCode;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _AddGoalAppBar(
        user: user,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(RouteNames.budgetPath);
          }
        },
        onNotificationsTap: () => context.go(RouteNames.notificationsPath),
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
                  const _HeroBanner(),
                  const SizedBox(height: AppSpacing.lg),
                  _DateAmountRow(
                    deadline: state.deadline,
                    languageCode: lang,
                    amountController: _amountCtrl,
                    amountFocus: _amountFocus,
                    currency: currency,
                    onAmountChanged: notifier.setAmount,
                    onPickDate: _pickDeadline,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FieldLabel(
                    text: context.tr(AppStrings.budgetAddGoalPickIcon),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _IconPresetGrid(
                    selectedSlug: state.iconSlug,
                    onTap: (preset) {
                      FocusScope.of(context).unfocus();
                      notifier.setIcon(
                        preset,
                        resolvedLabel: context.tr(preset.labelKey),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ForecastCard(
                    monthlySaving: state.monthlySaving,
                    monthsLeft: state.monthsToDeadline,
                    targetAmount: state.parsedAmount,
                    currency: currency,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDeadline() async {
    FocusScope.of(context).unfocus();
    final notifier = ref.read(addSavingGoalProvider.notifier);
    final state = ref.read(addSavingGoalProvider);
    final now = DateTime.now();
    final initial = state.deadline ?? now.add(const Duration(days: 90));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: DateTime(now.year + 30),
    );
    if (picked == null) return;
    notifier.setDeadline(DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _submit({required String currency}) async {
    FocusScope.of(context).unfocus();
    final notifier = ref.read(addSavingGoalProvider.notifier);
    final state = ref.read(addSavingGoalProvider);

    if (state.iconSlug == null || state.title.trim().isEmpty) {
      _toast(context.tr(AppStrings.budgetAddGoalErrorPickGoal));
      return;
    }
    if (state.parsedAmount == null) {
      _toast(context.tr(AppStrings.budgetAddGoalErrorAmount));
      return;
    }
    if (state.monthsToDeadline == null) {
      _toast(context.tr(AppStrings.budgetAddGoalErrorDeadline));
      return;
    }

    final ok = await notifier.submit(defaultCurrency: currency);
    if (!mounted) return;
    if (ok) {
      _toast(context.tr(AppStrings.budgetAddGoalSuccess), success: true);
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

class _AddGoalAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AddGoalAppBar({
    required this.user,
    required this.onBack,
    required this.onNotificationsTap,
  });

  final dynamic user;
  final VoidCallback onBack;
  final VoidCallback onNotificationsTap;

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
                  context.tr(AppStrings.budgetAddGoalTitle),
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

// ──────────────────────────── Hero ────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        children: [
          Text(
            context.tr(AppStrings.budgetAddGoalHeroTitle),
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLg(color: scheme.onSurface)
                .copyWith(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            context.tr(AppStrings.budgetAddGoalHeroSubtitle),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant)
                .copyWith(height: 1.5),
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

class _DateAmountRow extends StatelessWidget {
  const _DateAmountRow({
    required this.deadline,
    required this.languageCode,
    required this.amountController,
    required this.amountFocus,
    required this.currency,
    required this.onAmountChanged,
    required this.onPickDate,
  });

  final DateTime? deadline;
  final String languageCode;
  final TextEditingController amountController;
  final FocusNode amountFocus;
  final String currency;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FieldLabel(
                text: context.tr(AppStrings.budgetAddGoalDeadlineLabel),
              ),
              const SizedBox(height: AppSpacing.sm),
              _DeadlinePickerField(
                deadline: deadline,
                languageCode: languageCode,
                onTap: onPickDate,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.gutter),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FieldLabel(
                text: context.tr(AppStrings.budgetAddGoalAmountLabel),
              ),
              const SizedBox(height: AppSpacing.sm),
              _AmountField(
                controller: amountController,
                focusNode: amountFocus,
                currency: currency,
                onChanged: onAmountChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeadlinePickerField extends StatelessWidget {
  const _DeadlinePickerField({
    required this.deadline,
    required this.languageCode,
    required this.onTap,
  });

  final DateTime? deadline;
  final String languageCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasValue = deadline != null;
    final label = hasValue
        ? DateFormat('MM/dd/yyyy', languageCode).format(deadline!)
        : context.tr(AppStrings.budgetAddGoalDeadlineHint);
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          height: 56,
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            0,
            AppSpacing.sm,
            0,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: AppTextStyles.bodyMd(
                    color: hasValue
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  ).copyWith(
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
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

// ──────────────────────────── Icon presets ────────────────────────────

/// Hard-coded set of presets shown in the "Pick a goal icon" grid.
///
/// `slug` and `color` are persisted as-is on `POST /saving-goals`
/// (`icon` and `color` columns) so the goal renders with the same
/// glyph + accent everywhere. The first four pairs match the table
/// in `BUDGET_GOALS_API.md`; the rest fill the 4×2 grid with sensible
/// extras.
const List<GoalIconPreset> _kGoalIconPresets = [
  GoalIconPreset(
    slug: 'heroicon-o-academic-cap',
    color: '#CA8A04',
    labelKey: AppStrings.budgetAddGoalIconEducation,
  ),
  GoalIconPreset(
    slug: 'heroicon-o-computer-desktop',
    color: '#6366F1',
    labelKey: AppStrings.budgetAddGoalIconTools,
  ),
  GoalIconPreset(
    slug: 'heroicon-o-home',
    color: '#0D9488',
    labelKey: AppStrings.budgetAddGoalIconHome,
  ),
  GoalIconPreset(
    slug: 'heroicon-o-paper-airplane',
    color: '#065F46',
    labelKey: AppStrings.budgetAddGoalIconTravel,
  ),
  GoalIconPreset(
    slug: 'heroicon-o-truck',
    color: '#EF4444',
    labelKey: AppStrings.budgetAddGoalIconCar,
  ),
  GoalIconPreset(
    slug: 'heroicon-o-gift',
    color: '#EC4899',
    labelKey: AppStrings.budgetAddGoalIconGift,
  ),
  GoalIconPreset(
    slug: 'heroicon-o-heart',
    color: '#F43F5E',
    labelKey: AppStrings.budgetAddGoalIconWedding,
  ),
  GoalIconPreset(
    slug: 'heroicon-o-sparkles',
    color: '#8B5CF6',
    labelKey: AppStrings.budgetAddGoalIconOther,
  ),
];

class _IconPresetGrid extends StatelessWidget {
  const _IconPresetGrid({
    required this.selectedSlug,
    required this.onTap,
  });

  final String? selectedSlug;
  final ValueChanged<GoalIconPreset> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.gutter,
        crossAxisSpacing: AppSpacing.gutter,
        childAspectRatio: 1,
      ),
      itemCount: _kGoalIconPresets.length,
      itemBuilder: (context, i) {
        final preset = _kGoalIconPresets[i];
        return _IconPresetTile(
          preset: preset,
          isSelected: preset.slug == selectedSlug,
          onTap: () => onTap(preset),
        );
      },
    );
  }
}

class _IconPresetTile extends StatelessWidget {
  const _IconPresetTile({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  final GoalIconPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = categoryAccentColor(preset.color) ?? scheme.primary;
    final selectedBg = scheme.primary;
    return Material(
      color: isSelected ? selectedBg : scheme.surfaceContainerLowest,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(
              color: isSelected
                  ? selectedBg
                  : scheme.outlineVariant.withValues(alpha: 0.55),
              width: isSelected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                categoryIconFor(preset.slug),
                color: isSelected ? Colors.white : accent,
                size: 22,
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  context.tr(preset.labelKey),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSm(
                    color: isSelected ? Colors.white : scheme.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────── Forecast ────────────────────────────

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({
    required this.monthlySaving,
    required this.monthsLeft,
    required this.targetAmount,
    required this.currency,
  });

  final double? monthlySaving;
  final int? monthsLeft;
  final double? targetAmount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasValue = monthlySaving != null;
    final progressFraction = (monthsLeft ?? 0) > 0
        ? (1 / (monthsLeft! > 12 ? 12 : monthsLeft!))
            .clamp(0.0, 1.0)
            .toDouble()
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr(AppStrings.budgetAddGoalForecastTitle),
                  style: AppTextStyles.labelMd(color: scheme.onSurfaceVariant)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (hasValue)
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        kHomeMoneyFormat.format(monthlySaving!),
                        style: AppTextStyles.headlineSm(color: scheme.onSurface)
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currency,
                        style:
                            AppTextStyles.labelSm(color: scheme.onSurfaceVariant)
                                .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  '— $currency',
                  style: AppTextStyles.headlineSm(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: hasValue ? progressFraction.clamp(0.08, 1.0) : 0.04,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(scheme.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasValue
                ? context.tr(AppStrings.budgetAddGoalForecastNote)
                : context.tr(AppStrings.budgetAddGoalForecastHint),
            style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant)
                .copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── Submit / errors ────────────────────────────

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
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline_rounded,
                    size: 20, color: scheme.onPrimary),
                const SizedBox(width: 6),
                Text(
                  context.tr(AppStrings.budgetAddGoalSubmit),
                  style: AppTextStyles.labelLg(color: scheme.onPrimary)
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 16),
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
          Icon(Icons.error_outline_rounded, color: scheme.error, size: 18),
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
