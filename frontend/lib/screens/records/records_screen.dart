import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_text.dart';
import '../../widgets/record_modal.dart';
import 'activity_tab.dart';
import 'health_tab.dart';
import 'growth_tab.dart';

class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('기록', fontWeight: FontWeight.bold),
        leading: BackButton(onPressed: () => context.pop()),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: '활동'),
            Tab(text: '건강'),
            Tab(text: '성장'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => RecordModal.show(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          ActivityTab(),
          HealthTab(),
          GrowthTab(),
        ],
      ),
    );
  }
}
