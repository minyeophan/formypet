import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/keyboard_utils.dart';
import '../core/record_utils.dart';
import 'app_visual.dart';
import '../providers/pet_provider.dart';
import '../widgets/app_text.dart';
import 'record_detail_form.dart';

class RecordModal {
  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    String? initialTypeId,
  ) async {
    String? selectedTypeId = initialTypeId;

    if (selectedTypeId == null) {
      selectedTypeId = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _TypeSelectSheet(),
      );
      if (selectedTypeId == null) return;
    }

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: _DetailSheet(typeId: selectedTypeId!),
      ),
    );
  }
}

class _TypeSelectSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const AppText(
              '기록 유형 선택',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.9,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: kQuickTypes.length,
              itemBuilder: (ctx, i) {
                final t = kQuickTypes[i];
                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, t.id),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: AppVisual(
                          id: t.visualId,
                          size: 24,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AppText(t.label, fontSize: 11),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DetailSheet extends ConsumerStatefulWidget {
  final String typeId;
  const _DetailSheet({required this.typeId});

  @override
  ConsumerState<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends ConsumerState<_DetailSheet> {
  final _noteCtrl = TextEditingController();
  TimeOfDay? _time;
  Map<String, dynamic> _detail = {};
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _detail = emptyDetail(widget.typeId);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;

    // backend doesn't support diary/groom
    if (!kSupportedTypeIds.contains(widget.typeId)) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      String? timeStr;
      if (_time != null) {
        timeStr =
            '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';
      }
      await ref.read(petProvider.notifier).addRecord({
        'typeId': widget.typeId,
        'date': dateStr,
        'time': ?timeStr,
        if (_noteCtrl.text.isNotEmpty) 'note': _noteCtrl.text,
        if (_detail.isNotEmpty)
          'detail': sanitizeDetail(_detail, widget.typeId),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = kQuickTypes.where((t) => t.id == widget.typeId).firstOrNull;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                AppVisual(
                  id: recordTypeVisualId(widget.typeId),
                  size: 24,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                AppText(
                  type?.label ?? widget.typeId,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ],
            ),
            const SizedBox(height: 16),
            RecordDetailForm(
              typeId: widget.typeId,
              detail: _detail,
              onChanged: (d) => setState(() => _detail = d),
            ),
            const SizedBox(height: 12),
            // Time picker
            GestureDetector(
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (t != null) setState(() => _time = t);
              },
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  AppText(
                    _time != null ? _time!.format(context) : '시간 선택 (선택)',
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                hintText: '메모 (선택)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              AppText(_error!, color: Colors.red, fontSize: 12),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await dismissKeyboardBeforeTransition(context);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: const AppText('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const AppText('저장', fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
