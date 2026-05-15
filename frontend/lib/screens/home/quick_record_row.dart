import 'package:flutter/material.dart';
import '../../core/record_utils.dart';
import '../../widgets/app_text.dart';

class QuickRecordRow extends StatelessWidget {
  final List<String> quickTypeIds;
  final void Function(String typeId) onTap;

  const QuickRecordRow(
      {super.key, required this.quickTypeIds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final types = kQuickTypes
        .where((t) => quickTypeIds.contains(t.id))
        .toList();

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: types.length,
        itemBuilder: (_, i) {
          final t = types[i];
          return GestureDetector(
            onTap: () => onTap(t.id),
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(t.icon, size: 22),
                  ),
                  const SizedBox(height: 4),
                  AppText(t.label, fontSize: 11),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
