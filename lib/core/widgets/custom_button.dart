import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../constants/app_sizes.dart';

enum CustomButtonVariant { primary, secondary, ghost }

/// Project-wide button that supports the three Emerald variants and a tap
/// scale-down interaction (per DESIGN.md).
class CustomButton extends StatefulWidget {
  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = CustomButtonVariant.primary,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final CustomButtonVariant variant;
  final bool isLoading;
  final bool expand;

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null || widget.isLoading) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = widget.onPressed == null || widget.isLoading;
    final colors = _resolveColors(theme.colorScheme, widget.variant, disabled);

    final content = widget.isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(colors.foreground),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: AppIconSize.md, color: colors.foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: colors.foreground),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.trailingIcon != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(widget.trailingIcon, size: AppIconSize.md, color: colors.foreground),
              ],
            ],
          );

    final scheme = theme.colorScheme;
    final showShadow =
        widget.variant == CustomButtonVariant.primary && !disabled;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: disabled ? null : widget.onPressed,
      child: AnimatedScale(
        // Slightly more emphatic press-down (matches the design's `active:scale-[0.98]`).
        scale: _pressed ? 0.98 : 1,
        duration: AppConstants.shortAnimation,
        curve: Curves.easeOut,
        child: Container(
          width: widget.expand ? double.infinity : null,
          height: AppDimens.buttonHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.background,
            // Serene Finance: 0.5rem (8px) corner radius across all buttons.
            borderRadius: AppRadius.brSm,
            border: colors.border == null
                ? null
                : Border.all(color: colors.border!),
            boxShadow: showShadow
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: content,
        ),
      ),
    );
  }

  _ButtonColors _resolveColors(
    ColorScheme scheme,
    CustomButtonVariant variant,
    bool disabled,
  ) {
    if (disabled) {
      return _ButtonColors(
        background: scheme.surfaceContainerHigh,
        foreground: scheme.onSurfaceVariant.withValues(alpha: 0.6),
      );
    }
    switch (variant) {
      case CustomButtonVariant.primary:
        return _ButtonColors(
          background: scheme.primary,
          foreground: scheme.onPrimary,
        );
      case CustomButtonVariant.secondary:
        return _ButtonColors(
          background: scheme.secondaryContainer,
          foreground: scheme.primary,
        );
      case CustomButtonVariant.ghost:
        return _ButtonColors(
          background: Colors.transparent,
          foreground: scheme.primary,
          border: scheme.outlineVariant,
        );
    }
  }
}

class _ButtonColors {
  _ButtonColors({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Color? border;
}
