import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';

/// 3×4 numeric keypad used in the full-screen add-transaction sheet.
///
/// Layout (always LTR — numbers read the same way regardless of locale):
///   1  2  3
///   4  5  6
///   7  8  9
///   .  0  ⌫
class AddTransactionKeypad extends StatelessWidget {
  const AddTransactionKeypad({
    super.key,
    required this.onDigit,
    required this.onDecimal,
    required this.onBackspace,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onBackspace;

  static const _rows = <List<_KeypadKey>>[
    [_KeypadKey.digit(1), _KeypadKey.digit(2), _KeypadKey.digit(3)],
    [_KeypadKey.digit(4), _KeypadKey.digit(5), _KeypadKey.digit(6)],
    [_KeypadKey.digit(7), _KeypadKey.digit(8), _KeypadKey.digit(9)],
    [_KeypadKey.decimal(), _KeypadKey.digit(0), _KeypadKey.backspace()],
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _rows.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                for (var j = 0; j < _rows[i].length; j++) ...[
                  if (j > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _KeyButton(
                      keyData: _rows[i][j],
                      onDigit: onDigit,
                      onDecimal: onDecimal,
                      onBackspace: onBackspace,
                      scheme: scheme,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.keyData,
    required this.onDigit,
    required this.onDecimal,
    required this.onBackspace,
    required this.scheme,
  });

  final _KeypadKey keyData;
  final ValueChanged<int> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onBackspace;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => keyData.when(
          digit: onDigit,
          decimal: onDecimal,
          backspace: onBackspace,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: SizedBox(
          height: 56,
          child: Center(child: keyData.buildLabel(scheme)),
        ),
      ),
    );
  }
}

class _KeypadKey {
  const _KeypadKey._(this._kind, [this._digit]);

  const _KeypadKey.digit(int value) : this._(_KeypadKind.digit, value);
  const _KeypadKey.decimal() : this._(_KeypadKind.decimal);
  const _KeypadKey.backspace() : this._(_KeypadKind.backspace);

  final _KeypadKind _kind;
  final int? _digit;

  void when({
    required ValueChanged<int> digit,
    required VoidCallback decimal,
    required VoidCallback backspace,
  }) {
    switch (_kind) {
      case _KeypadKind.digit:
        digit(_digit ?? 0);
        break;
      case _KeypadKind.decimal:
        decimal();
        break;
      case _KeypadKind.backspace:
        backspace();
        break;
    }
  }

  Widget buildLabel(ColorScheme scheme) {
    switch (_kind) {
      case _KeypadKind.digit:
        return Text(
          '${_digit ?? 0}',
          style: AppTextStyles.headlineLg(color: scheme.onSurface).copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 28,
          ),
        );
      case _KeypadKind.decimal:
        return Text(
          '.',
          style: AppTextStyles.headlineLg(color: scheme.onSurface).copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 28,
          ),
        );
      case _KeypadKind.backspace:
        return Icon(
          Icons.backspace_outlined,
          size: 24,
          color: scheme.onSurface,
        );
    }
  }
}

enum _KeypadKind { digit, decimal, backspace }
