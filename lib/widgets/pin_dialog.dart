import 'package:flutter/material.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../core/colors.dart';
import '../core/theme_colors.dart';

/// Reusable PIN entry dialog with a custom numeric keypad.
///
/// Supports 4-6 digit PINs. Shows dots for entered digits.
/// [onPinEntered] is called when the user submits.
/// [onCancel] is called when the user cancels.
/// [errorMessage] can be set to show a validation error.
/// [title] is the dialog title.
/// [pinLength] sets the expected PIN length (default 4).
class PinDialog extends StatefulWidget {
  final String title;
  final String? errorMessage;
  final int pinLength;
  final ValueChanged<String> onPinEntered;
  final VoidCallback onCancel;

  const PinDialog({
    super.key,
    required this.title,
    this.errorMessage,
    this.pinLength = 4,
    required this.onPinEntered,
    required this.onCancel,
  });

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  String _pin = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.errorMessage;
  }

  @override
  void didUpdateWidget(covariant PinDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorMessage != oldWidget.errorMessage) {
      _error = widget.errorMessage;
    }
  }

  void _addDigit(String digit) {
    if (_pin.length >= widget.pinLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == widget.pinLength) {
      widget.onPinEntered(_pin);
    }
  }

  void _removeDigit() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  void _clear() {
    setState(() {
      _pin = '';
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return Dialog(
      backgroundColor: tc.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: tc.textPrimary),
            ),
            const SizedBox(height: 24),
            // Dots
            Semantics(
              label: AppLocalizations.of(context)!.chiffresSaisis(_pin.length, widget.pinLength),
              child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.pinLength, (i) {
                final filled = i < _pin.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppColors.primaryBlue : Colors.transparent,
                      border: Border.all(
                        color: filled ? AppColors.primaryBlue : tc.textDisabled,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }),
            )),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style:
                    const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            // Numeric keypad
            _buildKeypad(),
            const SizedBox(height: 16),
            TextButton(
              onPressed: widget.onCancel,
              child: Text(AppLocalizations.of(context)!.annuler,
                  style: TextStyle(color: tc.textTertiary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        _keypadRow(['1', '2', '3']),
        const SizedBox(height: 8),
        _keypadRow(['4', '5', '6']),
        const SizedBox(height: 8),
        _keypadRow(['7', '8', '9']),
        const SizedBox(height: 8),
        _keypadRow(['C', '0', '<']),
      ],
    );
  }

  Widget _keypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _keypadButton(key),
        );
      }).toList(),
    );
  }

  Widget _keypadButton(String label) {
    final tc = AppThemeColors.of(context);
    final isBackspace = label == '<';
    final isClear = label == 'C';

    final l10n = AppLocalizations.of(context)!;
    final semanticLabel = isBackspace ? l10n.effacer : isClear ? l10n.toutEffacer : l10n.chiffre(label);
    return Semantics(
      label: semanticLabel,
      button: true,
      child: SizedBox(
        width: 64,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: tc.inputFill,
            foregroundColor: tc.textPrimary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: EdgeInsets.zero,
          ),
          onPressed: () {
            if (isBackspace) {
              _removeDigit();
            } else if (isClear) {
              _clear();
            } else {
              _addDigit(label);
            }
          },
          child: isBackspace
              ? const Icon(Icons.backspace_outlined, size: 20)
              : Text(label, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}

/// Show a PIN dialog and return the entered PIN, or null if cancelled.
Future<String?> showPinDialog(
  BuildContext context, {
  required String title,
  String? errorMessage,
  int pinLength = 4,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      String? error = errorMessage;
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return PinDialog(
            title: title,
            errorMessage: error,
            pinLength: pinLength,
            onPinEntered: (pin) {
              Navigator.of(ctx).pop(pin);
            },
            onCancel: () {
              Navigator.of(ctx).pop(null);
            },
          );
        },
      );
    },
  );
}
