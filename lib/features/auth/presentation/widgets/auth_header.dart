import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';

/// Hero header used by the login & OTP screens — a soft mint-coloured halo
/// behind a primary-tinted icon, followed by a headline and supporting copy.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final badgeSize = compact ? 72.0 : 96.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: badgeSize + 28,
                height: badgeSize + 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryContainer.withValues(alpha: 0.10),
                ),
              ),
              Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryContainer,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: compact ? 32 : 40,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
        Text(
          title,
          textAlign: TextAlign.center,
          style: compact
              ? AppTextStyles.headlineLg(color: scheme.onSurface)
              : AppTextStyles.headlineXl(color: scheme.onSurface),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
