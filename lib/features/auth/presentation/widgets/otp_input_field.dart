import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';

/// Multi-box numeric OTP input.
///
/// - Forces LTR ordering even inside an RTL screen so the boxes read left-to-right.
/// - Auto-advances focus, jumps back on backspace, and accepts pasted codes.
/// - Calls [onCompleted] with the full string once every box is filled.
class OtpInputField extends StatefulWidget {
  const OtpInputField({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool hasError;
  final bool enabled;
  final bool autofocus;

  @override
  State<OtpInputField> createState() => OtpInputFieldState();
}

class OtpInputFieldState extends State<OtpInputField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// Clears every box and re-focuses the first one.
  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    if (mounted) {
      _focusNodes.first.requestFocus();
      widget.onChanged?.call('');
    }
  }

  String get _currentValue =>
      _controllers.map((c) => c.text).join();

  void _handleChange(int index, String value) {
    // Handle paste of the full code into a single box.
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < widget.length; i++) {
        _controllers[i].text =
            i < digits.length ? digits[i] : '';
      }
      final filled = digits.length.clamp(0, widget.length);
      if (filled < widget.length) {
        _focusNodes[filled].requestFocus();
      } else {
        _focusNodes.last.unfocus();
      }
      _emit();
      return;
    }

    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    } else if (value.isNotEmpty && index == widget.length - 1) {
      _focusNodes[index].unfocus();
    }
    _emit();
  }

  void _emit() {
    final code = _currentValue;
    widget.onChanged?.call(code);
    if (code.length == widget.length && !code.contains(' ')) {
      widget.onCompleted(code);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, int index) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      _emit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(widget.length, (i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: i == widget.length - 1 ? 0 : AppSpacing.sm,
              ),
              child: _OtpBox(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                enabled: widget.enabled,
                autofocus: widget.autofocus && i == 0,
                hasError: widget.hasError,
                onChanged: (value) => _handleChange(i, value),
                onKey: (node, event) => _onKey(node, event, i),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.autofocus,
    required this.hasError,
    required this.onChanged,
    required this.onKey,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool autofocus;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final FocusOnKeyEventCallback onKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filled = controller.text.isNotEmpty;
    final hasFocus = focusNode.hasFocus;

    Color borderColor;
    if (hasError) {
      borderColor = scheme.error;
    } else if (hasFocus) {
      borderColor = scheme.primary;
    } else if (filled) {
      borderColor = scheme.primary.withValues(alpha: 0.5);
    } else {
      borderColor = scheme.outlineVariant;
    }

    return Focus(
      onKeyEvent: onKey,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 64,
        decoration: BoxDecoration(
          color: filled
              ? scheme.primaryContainer.withValues(alpha: 0.06)
              : scheme.surfaceContainerLowest,
          borderRadius: AppRadius.brSm,
          border: Border.all(
            color: borderColor,
            width: hasFocus || hasError ? 1.5 : 1,
          ),
          boxShadow: hasFocus
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            autofocus: autofocus,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            cursorColor: scheme.primary,
            style: AppTextStyles.headlineLg(color: scheme.onSurface),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
