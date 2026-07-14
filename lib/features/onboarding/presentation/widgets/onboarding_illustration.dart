import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';

/// Hero illustration for an onboarding page: a soft mint halo behind a
/// rounded primary card with a feature icon at the centre.
///
/// Designed to fill a roughly square area and stay readable across screen
/// sizes by capping its width.
class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({
    super.key,
    required this.icon,
    this.maxSize = 320,
  });

  final IconData icon;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth.clamp(220.0, maxSize);
        final iconSize = size * 0.34;

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer mint halo (very soft).
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primaryContainer.withValues(alpha: 0.18),
                  ),
                ),
                // Inner halo for a subtle glow.
                Padding(
                  padding: EdgeInsets.all(size * 0.08),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primaryContainer.withValues(alpha: 0.28),
                    ),
                  ),
                ),
                // Primary card with the feature icon.
                Padding(
                  padding: EdgeInsets.all(size * 0.18),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.brXl,
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          scheme.primary,
                          scheme.primaryContainer,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.22),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      size: iconSize,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
