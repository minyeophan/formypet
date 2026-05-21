import 'package:flutter/material.dart';

Future<void> dismissKeyboardBeforeTransition(BuildContext context) async {
  FocusScope.of(context).unfocus();
  await WidgetsBinding.instance.endOfFrame;
}
