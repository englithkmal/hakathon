import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../theme/text_styles.dart';

/// Sticky white-tinted top bar used by transactional / linear flows
/// (Login, OTP, Register, etc).
///
/// Matches the Serene Finance design spec:
///  * Translucent white background (`bg-white/95`).
///  * Diffusion shadow (large blur + ~5% opacity) that bleeds into the body.
///  * Primary-coloured back chevron — automatically uses [Icons.arrow_forward]
///    on RTL locales (which visually reads as "back" in Arabic).
///  * Primary-coloured title centred horizontally with a placeholder block on
///    the trailing side to keep the title perfectly centred.
class WafferAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WafferAppBar({
    super.key,
    this.title,
    this.onBack,
    this.showBack = true,
    this.trailing,
  });

  /// Optional title — when `null` or empty, only the back button is shown
  /// and the title slot is rendered as flexible empty space.
  final String? title;
  final VoidCallback? onBack;
  final bool showBack;

  /// Optional widget displayed at the leading edge in LTR (or trailing in RTL).
  /// When `null`, an empty 40×40 spacer is rendered to keep the title centred.
  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(AppDimens.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    // Apply the status-bar inset on top of the fixed bar height so the
    // contents always render *below* the system status bar. Without this the
    // [SafeArea] would steal vertical space from the row, clipping the title
    // and back button.
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // White/95: a near-opaque tint that lets the surface show through.
          color: scheme.surfaceContainerLowest.withValues(alpha: 0.95),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.05),
              blurRadius: 24,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: AppDimens.appBarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.mobileMargin,
              ),
              child: Row(
                children: [
                  if (showBack)
                    _CircularIconButton(
                      icon: isRtl
                          ? Icons.arrow_forward_rounded
                          : Icons.arrow_back_rounded,
                      color: scheme.primary,
                      onTap:
                          onBack ?? () => Navigator.maybeOf(context)?.maybePop(),
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                    )
                  else
                    const SizedBox(width: 40),
                  Expanded(
                    child: (title == null || title!.isEmpty)
                        ? const SizedBox.shrink()
                        : Center(
                            child: Text(
                              title!,
                              textAlign: TextAlign.center,
                              style:
                                  AppTextStyles.headlineMd(color: scheme.primary)
                                      .copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                  ),
                  trailing ?? const SizedBox(width: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircularIconButton extends StatelessWidget {
  const _CircularIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        splashColor: scheme.primaryContainer.withValues(alpha: 0.16),
        highlightColor: scheme.primaryContainer.withValues(alpha: 0.08),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: AppIconSize.lg, color: color),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
