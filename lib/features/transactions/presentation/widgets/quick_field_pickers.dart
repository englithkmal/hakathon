import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/models/category_model.dart';
import 'category_icon.dart';

/// Compact category picker tile shown inside the quick-add transaction
/// card. Renders the selected category's icon + label, and opens a
/// bottom sheet with all categories (grouped by type) on tap.
class QuickCategoryPicker extends StatelessWidget {
  const QuickCategoryPicker({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    required this.languageCode,
  });

  final List<CategoryModel> categories;
  final int? selectedId;
  final ValueChanged<CategoryModel> onSelected;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _resolveSelected();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            context.tr(AppStrings.transactionsCategory),
            style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: () => _openSheet(context),
          borderRadius: AppRadius.brSm,
          child: Container(
            height: 48,
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.sm + AppSpacing.xs,
              end: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: AppRadius.brSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected?.displayName(languageCode) ??
                        context.tr(AppStrings.transactionsCategory),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySm(
                      color: selected == null
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ).copyWith(
                      fontWeight: selected == null
                          ? FontWeight.w500
                          : FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _accentBg(scheme, selected),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    selected != null
                        ? categoryIconFor(
                            selected.icon.isNotEmpty
                                ? selected.icon
                                : selected.slug,
                          )
                        : Icons.category_outlined,
                    size: 16,
                    color: _accentFg(scheme, selected),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  CategoryModel? _resolveSelected() {
    if (selectedId == null) return null;
    for (final cat in categories) {
      if (cat.id == selectedId) return cat;
    }
    return null;
  }

  Color _accentBg(ColorScheme s, CategoryModel? cat) {
    if (cat == null) return s.surfaceContainerHighest;
    final accent = categoryAccentColor(cat.color);
    if (accent != null) return accent.withValues(alpha: 0.18);
    return s.primary.withValues(alpha: 0.16);
  }

  Color _accentFg(ColorScheme s, CategoryModel? cat) {
    if (cat == null) return s.onSurfaceVariant;
    final accent = categoryAccentColor(cat.color);
    return accent ?? s.primary;
  }

  Future<void> _openSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<CategoryModel>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.radiusLg),
      ),
      isScrollControlled: true,
      builder: (sheetCtx) => _CategoriesPickerSheet(
        categories: categories,
        languageCode: languageCode,
        selectedId: selectedId,
      ),
    );
    if (picked != null) onSelected(picked);
  }
}

class _CategoriesPickerSheet extends StatelessWidget {
  const _CategoriesPickerSheet({
    required this.categories,
    required this.languageCode,
    required this.selectedId,
  });

  final List<CategoryModel> categories;
  final String languageCode;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final expense = categories.where((c) => c.isExpense).toList();
    final income = categories.where((c) => !c.isExpense).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.tr(AppStrings.transactionsCategory),
              style: AppTextStyles.headlineMd(color: scheme.onSurface)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  if (expense.isNotEmpty) ...[
                    _SectionLabel(
                      label: context.tr(AppStrings.transactionsTypeExpense),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _CategoryGrid(
                      categories: expense,
                      languageCode: languageCode,
                      selectedId: selectedId,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (income.isNotEmpty) ...[
                    _SectionLabel(
                      label: context.tr(AppStrings.transactionsTypeIncome),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _CategoryGrid(
                      categories: income,
                      languageCode: languageCode,
                      selectedId: selectedId,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(
        label,
        style: AppTextStyles.labelMd(color: scheme.onSurfaceVariant)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.languageCode,
    required this.selectedId,
  });

  final List<CategoryModel> categories;
  final String languageCode;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final cat in categories)
          SizedBox(
            width: (MediaQuery.sizeOf(context).width -
                    AppSpacing.lg * 2 -
                    AppSpacing.sm * 3) /
                4,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.md),
              onTap: () => Navigator.of(context).pop(cat),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: cat.id == selectedId
                            ? (categoryAccentColor(cat.color) ?? scheme.primary)
                                .withValues(alpha: 0.18)
                            : scheme.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        categoryIconFor(
                          cat.icon.isNotEmpty ? cat.icon : cat.slug,
                        ),
                        size: 22,
                        color: cat.id == selectedId
                            ? (categoryAccentColor(cat.color) ?? scheme.primary)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      cat.displayName(languageCode),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSm(
                        color: cat.id == selectedId
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ).copyWith(
                        fontWeight: cat.id == selectedId
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Compact date picker tile mirroring the look of [QuickCategoryPicker].
/// Shows a localized label ("اليوم" / "Today" or formatted date) with a
/// calendar icon. Tapping opens the system date picker.
class QuickDatePicker extends StatelessWidget {
  const QuickDatePicker({
    super.key,
    required this.date,
    required this.onChanged,
  });

  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            context.tr(AppStrings.transactionsDateLabel),
            style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: () => _pickDate(context),
          borderRadius: AppRadius.brSm,
          child: Container(
            height: 48,
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.sm + AppSpacing.xs,
              end: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: AppRadius.brSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(context, date, lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySm(color: scheme.onSurface)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) onChanged(picked);
  }

  String _formatDate(BuildContext context, DateTime d, String lang) {
    final today = DateTime.now();
    final isToday = d.year == today.year &&
        d.month == today.month &&
        d.day == today.day;
    if (isToday) return context.tr(AppStrings.transactionsDateToday);
    return intl.DateFormat('d MMM', lang).format(d);
  }
}
