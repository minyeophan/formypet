import 'package:flutter/material.dart';
import '../../widgets/app_confirm_dialog.dart';

class PetConfirmDialogAction {
  final String label;
  final VoidCallback onPressed;
  final bool isDanger;

  const PetConfirmDialogAction({
    required this.label,
    required this.onPressed,
    this.isDanger = false,
  });
}

class PetConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final List<PetConfirmDialogAction> actions;

  const PetConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppConfirmDialog(
      title: title,
      body: body,
      actions: [
        for (final action in actions)
          AppConfirmDialogAction(
            label: action.label,
            onPressed: action.onPressed,
            isDanger: action.isDanger,
          ),
      ],
    );
  }
}
