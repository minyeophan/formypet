import 'package:flutter/material.dart';
import '../../services/policy_service.dart';

Future<Map<String, dynamic>?> collectPolicyAcceptance(
  BuildContext context, {
  PolicyService? policyService,
}) async {
  final service = policyService ?? PolicyService();
  final catalog = await service.catalog();
  if (catalog['enforcementEnabled'] != true) return <String, dynamic>{};
  final documents = await Future.wait([
    service.document('terms'),
    service.document('privacy'),
  ]);
  if (!context.mounted) return null;
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        PolicyConsentDialog(terms: documents[0], privacy: documents[1]),
  );
}

class PolicyConsentDialog extends StatefulWidget {
  final Map<String, dynamic> terms;
  final Map<String, dynamic> privacy;
  const PolicyConsentDialog({
    super.key,
    required this.terms,
    required this.privacy,
  });
  @override
  State<PolicyConsentDialog> createState() => _PolicyConsentDialogState();
}

class _PolicyConsentDialogState extends State<PolicyConsentDialog> {
  bool _terms = false;
  bool _age = false;
  void _show(Map<String, dynamic> document) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(document['title'] as String),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: SelectableText(
              '버전 ${document['version']}\n시행일 ${document['effectiveAt']}\n\n${document['body']}',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('서비스 이용 동의'),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => _show(widget.terms),
              child: const Text('이용약관 전문 보기'),
            ),
            CheckboxListTile(
              value: _terms,
              onChanged: (v) => setState(() => _terms = v == true),
              title: const Text('[필수] 이용약관에 동의합니다'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              value: _age,
              onChanged: (v) => setState(() => _age = v == true),
              title: const Text('[필수] 만 14세 이상입니다'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Text('개인정보 처리 내용은 아래 처리방침에서 확인할 수 있습니다.'),
            TextButton(
              onPressed: () => _show(widget.privacy),
              child: const Text('개인정보 처리방침 전문 보기'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: _terms && _age
            ? () => Navigator.pop(context, <String, dynamic>{
                'termsVersion': widget.terms['version'],
                'termsAccepted': true,
                'age14Confirmed': true,
              })
            : null,
        child: const Text('동의하고 계속'),
      ),
    ],
  );
}
