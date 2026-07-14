import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';

/// Sticky-feeling section header (التنبيهات → اليوم / أمس / …).
class NotificationGroupHeader extends StatelessWidget {
  const NotificationGroupHeader({super.key, required this.titleKey});

  final String titleKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        context.tr(titleKey),
        style: AppTextStyles.labelMd(color: scheme.outline)
            .copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
