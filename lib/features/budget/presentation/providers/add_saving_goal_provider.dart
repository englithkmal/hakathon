import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../data/repositories/budget_repository.dart';
import 'budget_tab_provider.dart';

/// One of the icon presets shown in the "Pick a goal icon" grid.
///
/// Each preset bundles together:
///   - the **slug** that gets persisted in the goal (used by the
///     transaction/category icon resolver to render the right glyph),
///   - a Tailwind-style hex **color** so the saved goal renders with
///     the same accent on every screen,
///   - and a translation **labelKey** for the chip text.
class GoalIconPreset {
  const GoalIconPreset({
    required this.slug,
    required this.color,
    required this.labelKey,
  });

  final String slug;
  final String color;
  final String labelKey;
}

class AddSavingGoalState {
  const AddSavingGoalState({
    this.title = '',
    this.amountText = '',
    this.deadline,
    this.iconSlug,
    this.iconColor,
    this.errorMessage,
    this.isSubmitting = false,
  });

  final String title;
  final String amountText;
  final DateTime? deadline;
  final String? iconSlug;
  final String? iconColor;
  final String? errorMessage;
  final bool isSubmitting;

  /// Server contract (`SavingGoalRequest::rules`): `target_amount` is
  /// required and must be **≥ 1**. We mirror that minimum here so the
  /// "Create" button stays disabled for sub-1 inputs and the user
  /// catches the issue without waiting on a 422 round-trip.
  double? get parsedAmount {
    final raw = amountText.replaceAll(',', '.').trim();
    if (raw.isEmpty) return null;
    final n = double.tryParse(raw);
    if (n == null || n < 1) return null;
    return n;
  }

  /// Months between today and the chosen deadline (rounded up so the
  /// UI never shows "0 months" for a date later this month).
  int? get monthsToDeadline {
    final d = deadline;
    if (d == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!d.isAfter(today)) return null;
    var months = (d.year - today.year) * 12 + (d.month - today.month);
    if (d.day > today.day) months += 1;
    return months <= 0 ? 1 : months;
  }

  /// `target_amount / months` — the headline figure on the forecast
  /// card. Returns `null` until the user has typed a valid amount and
  /// picked a future deadline.
  double? get monthlySaving {
    final amount = parsedAmount;
    final months = monthsToDeadline;
    if (amount == null || months == null) return null;
    return amount / months;
  }

  /// Submit eligibility:
  ///   - the user has tapped one of the icon presets (which also sets
  ///     [title] from the preset's translated label),
  ///   - typed an amount ≥ 1, and
  ///   - picked a future deadline.
  bool get canSubmit =>
      iconSlug != null &&
      title.trim().isNotEmpty &&
      parsedAmount != null &&
      monthsToDeadline != null &&
      !isSubmitting;

  AddSavingGoalState copyWith({
    String? title,
    String? amountText,
    Object? deadline = _unset,
    Object? iconSlug = _unset,
    Object? iconColor = _unset,
    Object? errorMessage = _unset,
    bool? isSubmitting,
  }) {
    return AddSavingGoalState(
      title: title ?? this.title,
      amountText: amountText ?? this.amountText,
      deadline: identical(deadline, _unset)
          ? this.deadline
          : deadline as DateTime?,
      iconSlug:
          identical(iconSlug, _unset) ? this.iconSlug : iconSlug as String?,
      iconColor:
          identical(iconColor, _unset) ? this.iconColor : iconColor as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

const Object _unset = Object();

final addSavingGoalProvider =
    NotifierProvider.autoDispose<AddSavingGoalNotifier, AddSavingGoalState>(
  AddSavingGoalNotifier.new,
);

class AddSavingGoalNotifier
    extends AutoDisposeNotifier<AddSavingGoalState> {
  @override
  AddSavingGoalState build() => const AddSavingGoalState();

  void setAmount(String value) {
    state = state.copyWith(amountText: value, errorMessage: null);
  }

  void setDeadline(DateTime? value) {
    state = state.copyWith(deadline: value, errorMessage: null);
  }

  /// Picks an icon preset for the goal.
  ///
  /// The screen no longer asks the user to type a custom title — the
  /// `title` is derived from the preset's translated label (e.g.
  /// "سفر" / "Travel") which the screen resolves through `context.tr`
  /// and passes in here. The API still requires a non-empty `title`,
  /// so we set both fields atomically.
  void setIcon(GoalIconPreset preset, {required String resolvedLabel}) {
    state = state.copyWith(
      iconSlug: preset.slug,
      iconColor: preset.color,
      title: resolvedLabel,
      errorMessage: null,
    );
  }

  /// [defaultCurrency] should be the user's preferred currency
  /// (from `userCurrencyProvider`) — the screen is responsible for
  /// resolving it. The constant fallback is only here as a final
  /// safety net so the value is never an empty string.
  Future<bool> submit({
    String defaultCurrency = AppConstants.defaultCurrency,
  }) async {
    final amount = state.parsedAmount;
    final deadline = state.deadline;
    final monthsLeft = state.monthsToDeadline;
    if (state.title.trim().isEmpty ||
        amount == null ||
        deadline == null ||
        monthsLeft == null) {
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final repo = ref.read(budgetRepositoryProvider);
      final tab = ref.read(budgetTabProvider).valueOrNull;
      final currency = (tab?.budget?.currency.isNotEmpty ?? false)
          ? tab!.budget!.currency
          : defaultCurrency;

      await repo.createSavingGoal(
        title: state.title.trim(),
        targetAmount: amount,
        deadline: _ymd(deadline),
        currency: currency,
        icon: state.iconSlug,
        color: state.iconColor,
        startDate: _ymd(DateTime.now()),
      );

      // Refresh the parent tab so the new goal pops in immediately.
      await ref.read(budgetTabProvider.notifier).refresh();
      state = state.copyWith(isSubmitting: false);
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.message ?? 'Error',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}

String _ymd(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}
