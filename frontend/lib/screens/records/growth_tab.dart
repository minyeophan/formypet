import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_text.dart';

class GrowthTab extends ConsumerWidget {
  const GrowthTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(petProvider).records;
    final weightRecords = records
        .where((r) => r.typeId == 'weight' && r.detail['value'] != null)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (weightRecords.isEmpty) {
      return const Center(
          child: AppText('체중 기록이 없습니다', color: Colors.grey));
    }

    final spots = weightRecords.asMap().entries.map((e) {
      final value = double.tryParse(e.value.detail['value'].toString()) ?? 0.0;
      return FlSpot(e.key.toDouble(), value);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const AppText('체중 변화', fontWeight: FontWeight.bold, fontSize: 15),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 2,
                    dotData: const FlDotData(show: true),
                  ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i >= 0 && i < weightRecords.length) {
                          final date = weightRecords[i].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: AppText(date.substring(5), fontSize: 10),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Weight history list
          ...weightRecords.reversed.take(5).map((r) => ListTile(
                dense: true,
                title: AppText('${r.detail['value']} ${r.detail['unit'] ?? 'kg'}',
                    fontSize: 14),
                subtitle: AppText(r.date, fontSize: 12, color: Colors.grey),
              )),
        ],
      ),
    );
  }
}
