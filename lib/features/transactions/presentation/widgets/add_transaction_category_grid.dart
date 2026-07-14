import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/models/category_model.dart';
import 'category_icon.dart';

/// Single-row grid of categories that mirrors the Figma reference for
/// the full-screen add-transaction sheet. Always shows 5 cells:
///   • The first 4 categories (filtered by type)
///   • A trailing "Other" cell (`أخرى`) that opens a bottom sheet with
///     every remaining category.
class AddTransactionCategoryGrid extends StatelessWidget {
  const AddTransactionCategoryGrid({
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
    final primary = categories.length <= 4
        ? categories
        : categories.take(4).toList();
    final overflow = categories.length <= 4
        ? const <CategoryModel>[]
        : categories.skip(4).toList();

    final selectedIsInOverflow =
        overflow.any((c) => c.id == selectedId);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < primary.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _CategoryCell(
              icon: categoryIconFor(
                primary[i].icon.isNotEmpty
                    ? primary[i].icon
                    : primary[i].slug,
              ),
              label: primary[i].displayName(languageCode),
              accent: categoryAccentColor(primary[i].color),
              isSelected: primary[i].id == selectedId,
              onTap: () => onSelected(primary[i]),
            ),
          ),
        ],
        if (overflow.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _CategoryCell(
              icon: Icons.more_horiz_rounded,
              label: context.tr(AppStrings.transactionsCategoryOther),
              accent: scheme.onSurfaceVariant,
              isSelected: selectedIsInOverflow,
              onTap: () => _showOverflowSheet(context, overflow),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showOverflowSheet(
    BuildContext context,
    List<CategoryModel> rest,
  ) async {
    final picked = await showModalBottomSheet<CategoryModel>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.radiusLg),
      ),
      builder: (sheetCtx) => _OverflowCategoriesSheet(
        categories: rest,
        languageCode: languageCode,
        selectedId: selectedId,
      ),
    );
    if (picked != null) onSelected(picked);
  }
}

class _CategoryCell extends StatelessWidget {
  const _CategoryCell({
    required this.icon,
    required this.label,
    required this.accent,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? accent;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedBg = accent != null
        ? accent!.withValues(alpha: 0.18)
        : scheme.primary.withValues(alpha: 0.16);
    final selectedFg = accent ?? scheme.primary;
    final restingBg = scheme.surfaceContainerHigh;
    final restingFg = scheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected ? selectedBg : restingBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? selectedFg : restingFg,
              ),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSm(
                color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
              ).copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverflowCategoriesSheet extends StatelessWidget {
  const _OverflowCategoriesSheet({
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final cat in categories)
                  SizedBox(
                    width: (MediaQuery.sizeOf(context).width -
                            AppSpacing.lg * 2 -
                            AppSpacing.sm * 3) /
                        4,
                    child: _CategoryCell(
                      icon: categoryIconFor(
                        cat.icon.isNotEmpty ? cat.icon : cat.slug,
                      ),
                      label: cat.displayName(languageCode),
                      accent: categoryAccentColor(cat.color),
                      isSelected: cat.id == selectedId,
                      onTap: () => Navigator.of(context).pop(cat),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
