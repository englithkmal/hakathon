import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';

/// Compact row that shows the note input on the start side and a small
/// date pill on the end side (mirrors the Figma reference for the
/// add-transaction sheet).
class AddTransactionNoteDateRow extends StatelessWidget {
  const AddTransactionNoteDateRow({
    super.key,
    required this.noteController,
    required this.date,
    required this.onPickDate,
    this.noteFocusNode,
  });

  final TextEditingController noteController;
  final FocusNode? noteFocusNode;
  final DateTime date;
  final ValueChanged<DateTime> onPickDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(AppStrings.transactionsNoteLabel),
                style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: AppRadius.brSm,
                ),
                alignment: AlignmentDirectional.center,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: noteController,
                        focusNode: noteFocusNode,
                        textInputAction: TextInputAction.done,
                        // Tapping anywhere outside the field unfocuses
                        // it. This guarantees the keypad is restored
                        // even if the OS keyboard was dismissed by a
                        // back gesture or a tap on another control.
                        onTapOutside: (_) => noteFocusNode?.unfocus(),
                        onSubmitted: (_) => noteFocusNode?.unfocus(),
                        style:
                            AppTextStyles.bodySm(color: scheme.onSurface),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText:
                              context.tr(AppStrings.transactionsNoteHint),
                          hintStyle: AppTextStyles.bodySm(
                            color: scheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.edit_note_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(AppStrings.transactionsDateLabel),
                style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xs),
              InkWell(
                onTap: () => _pickDate(context),
                borderRadius: AppRadius.brSm,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + AppSpacing.xs,
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
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
    if (picked != null) onPickDate(picked);
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
