import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_sizes.dart';

/// Pagination indicator used by the onboarding flow. The active dot stretches
/// into a pill (per design), while the inactive dots remain compact circles.
class OnboardingDots extends StatelessWidget {
  const OnboardingDots({
    super.key,
    required this.count,
    required this.currentIndex,
  });

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          AnimatedContainer(
            duration: AppConstants.shortAnimation,
            curve: Curves.easeOut,
            width: i == currentIndex ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == currentIndex
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.7),
              borderRadius: AppRadius.brSm,
            ),
          ),
          if (i != count - 1) const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );
  }
}
