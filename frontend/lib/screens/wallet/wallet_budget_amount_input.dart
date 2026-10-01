import 'package:flutter/services.dart';
import 'wallet_expense_utils.dart';

int? walletAmountValue(String text) => int.tryParse(
  text.trim().replaceAll(',', '').replaceFirst(RegExp(r'원$'), ''),
);

/// Keep a grouped, adjacent won suffix while preserving the numeric caret.
class WalletWonInputFormatter extends TextInputFormatter {
  const WalletWonInputFormatter();
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final amount = walletAmountValue(newValue.text);
    if (amount == null) return newValue;
    final text = formatWon(amount);
    final before = newValue.text.substring(
      0,
      newValue.selection.extentOffset.clamp(0, newValue.text.length),
    );
    final digitsBefore = RegExp(r'\d').allMatches(before).length;
    var count = 0;
    var offset = 0;
    for (var i = 0; i < text.length - 1; i++) {
      if (RegExp(r'\d').hasMatch(text[i])) count++;
      if (count >= digitsBefore) {
        offset = i + 1;
        break;
      }
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
