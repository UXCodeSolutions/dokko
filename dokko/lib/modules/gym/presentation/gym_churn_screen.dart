import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_card.dart';
import '../../../core/widgets/dokko_empty_state.dart';
import '../../../core/widgets/dokko_skeleton.dart';
import '../../../core/widgets/dokko_table.dart';
import '../data/gym_api.dart';
import '../providers/gym_provider.dart';

class GymChurnScreen extends ConsumerWidget {
  const GymChurnScreen({super.key});

  String _relativeDays(int? days) {
    if (days == null) return '—';
    if (days == 0) return 'Hoy';
    if (days == 1) return 'Ayer';
    return 'hace $days días';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(gymChurnProvider);

    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      body: Padding(
        padding: const EdgeInsets.all(DokkoTokens.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Churn / Fidelización',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: DokkoTokens.text,
              ),
            ),
            const SizedBox(height: DokkoTokens.space24),
            Expanded(
              child: overviewAsync.when(
                loading: () => const _ChurnSkeleton(),
                error: (err, _) => Center(
                  child: Text('Error: $err',
                      style: const TextStyle(color: Colors.red)),
                ),
                data: (overview) {
                  final atRisk =
                      (overview['at_risk'] as List<dynamic>? ?? [])
                          .cast<Map<String, dynamic>>();
                  final months =
                      (overview['months'] as List<dynamic>? ?? [])
                          .cast<Map<String, dynamic>>();

                  final columns = <DokkoTableColumn>[
                    const DokkoTableColumn(title: 'Miembro', flex: 2),
                    const DokkoTableColumn(
                        title: 'Último check-in', width: 120),
                    const DokkoTableColumn(title: 'Vence', width: 110),
                    DokkoTableColumn(
                        title: 'Riesgo',
                        width: 90,
                        customRender: _renderRiesgo),
                    DokkoTableColumn(
                        title: '',
                        width: 110,
                        customRender: (item) =>
                            _renderAccionWidget(context, ref, item)),
                  ];

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // KPIs
                        Row(
                          children: [
                            _KpiCard(
                              label: 'Miembros en riesgo',
                              value: '${overview['at_risk_count'] ?? 0}',
                              color: (overview['at_risk_count'] ?? 0) > 0
                                  ? DokkoTokens.red
                                  : DokkoTokens.text3,
                            ),
                            const SizedBox(width: DokkoTokens.space16),
                            _KpiCard(
                              label: 'Miembros activos',
                              value: '${overview['active_members_count'] ?? 0}',
                              color: DokkoTokens.green,
                            ),
                            const SizedBox(width: DokkoTokens.space16),
                            _KpiCard(
                              label: 'Churn 6 meses',
                              value:
                                  '${overview['churn_rate_6m'] ?? 0.0}%',
                              color: DokkoTokens.amber,
                            ),
                          ],
                        ),
                        const SizedBox(height: DokkoTokens.space16),

                        // Miembros en riesgo
                        DokkoCard(
                          padding: EdgeInsets.zero,
                          child: _SectionHeader(
                            title: 'Miembros en riesgo',
                            subtitle: atRisk.isEmpty
                                ? 'Nadie reúne las condiciones de riesgo hoy.'
                                : 'Baja asistencia y/o membresía por vencer.',
                          ),
                        ),
                        if (atRisk.isEmpty)
                          const DokkoEmptyState(
                            icon: Icons.health_and_safety_rounded,
                            message: 'Sin miembros en riesgo.\n'
                                'Los riesgos se detectan en el backend de forma automática.',
                          )
                        else
                          Container(
                            height: 320,
                            decoration: BoxDecoration(
                              color: DokkoTokens.bg,
                              border: Border.all(color: DokkoTokens.line),
                              borderRadius: BorderRadius.circular(
                                  DokkoTokens.radiusLg),
                            ),
                            child: DokkoTable<Map<String, dynamic>>(
                              columns: columns,
                              data: atRisk,
                              onRowTap: (item) =>
                                  context.push('/gym/members/${item['member_id']}'),
                              cellValue: (item, index) {
                                switch (index) {
                                  case 0:
                                    return '${item['first_name']} ${item['last_name']}';
                                  case 1:
                                    return _relativeDays(
                                        item['days_since_last_checkin'] as int?);
                                  case 2:
                                    return item['membership_expires_at'] ?? '—';
                                  case 3:
                                    return item['risk_level'] == 'alto'
                                        ? 'Alto'
                                        : 'Medio';
                                  default:
                                    return '';
                                }
                              },
                            ),
                          ),

                        const SizedBox(height: DokkoTokens.space16),

                        // Churn histórico
                        DokkoCard(
                          child: _ChurnHistoryChart(months: months),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderAccionWidget(
      BuildContext context, WidgetRef ref, dynamic item) {
    final member = item as Map<String, dynamic>;
    return Center(
      child: DokkoButton(
        label: 'Recordar',
        variant: DokkoButtonVariant.ghost,
        onPressed: () async {
          try {
            await ref
                .read(gymApiProvider)
                .sendChurnReminder(member['member_id'] as String);
            if (!context.mounted) return;
            ref.invalidate(gymChurnProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Recordatorio de recuperación enviado.')),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al enviar recordatorio: $e')),
            );
          }
        },
      ),
    );
  }

  Widget _renderRiesgo(dynamic item) {
    final member = item as Map<String, dynamic>;
    final isAlto = member['risk_level'] == 'alto';
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: DokkoTokens.space8, vertical: 4),
        decoration: BoxDecoration(
          color: (isAlto ? DokkoTokens.red : DokkoTokens.amber)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(DokkoTokens.radiusSm),
        ),
        child: Text(
          isAlto ? 'Alto' : 'Medio',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isAlto ? DokkoTokens.red : DokkoTokens.amber,
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DokkoCard(
        padding: const EdgeInsets.all(DokkoTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: DokkoTokens.text2,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.02,
              ),
            ),
            const SizedBox(height: DokkoTokens.space8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: DokkoTokens.space16, vertical: DokkoTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.02,
              color: DokkoTokens.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: DokkoTokens.text3),
          ),
        ],
      ),
    );
  }
}

class _ChurnHistoryChart extends StatelessWidget {
  final List<Map<String, dynamic>> months;

  const _ChurnHistoryChart({required this.months});

  @override
  Widget build(BuildContext context) {
    final spots = months.asMap().entries.map((e) {
      return FlSpot(
          e.key.toDouble(),
          (e.value['churn_rate'] as num).toDouble());
    }).toList();

    final maxRate = spots.isEmpty
        ? 5.0
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Churn histórico (últimos 6 meses)',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: DokkoTokens.text),
        ),
        const SizedBox(height: DokkoTokens.space4),
        Row(
          children: [
            _KpiChip(
                label: 'Tasa',
                value:
                    '${months.fold<double>(0.0, (s, m) => s + (m['churned'] as num).toDouble())} '
                    'miembros perdidos',
                color: DokkoTokens.amber),
          ],
        ),
        const SizedBox(height: DokkoTokens.space20),
        SizedBox(
          height: 180,
          child: spots.isEmpty || spots.every((s) => s.y == 0)
              ? const Center(
                  child: Text('Sin datos de churn todavía.',
                      style: TextStyle(color: DokkoTokens.text2)))
              : LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: (maxRate * 1.3).clamp(5.0, double.infinity),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: DokkoTokens.line,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (v, meta) => Text(
                            '${v.toInt()}%',
                            style: const TextStyle(
                                fontSize: 10, color: DokkoTokens.text3),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (v, meta) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= months.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              _shortMonth(months[idx]['month'] as String),
                              style: const TextStyle(
                                  fontSize: 10, color: DokkoTokens.text3),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: DokkoTokens.red,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: DokkoTokens.red.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) => touchedSpots
                            .map((s) => LineTooltipItem(
                                  '${s.y.toStringAsFixed(1)}%',
                                  const TextStyle(
                                      color: DokkoTokens.text,
                                      fontSize: 12),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _KpiChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DokkoTokens.space12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DokkoTokens.radiusSm),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _shortMonth(String yyyyMm) {
  const meses = [
    '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];
  final parts = yyyyMm.split('-');
  if (parts.length != 2) return yyyyMm;
  final mes = int.tryParse(parts[1]);
  return mes != null ? meses[mes] : yyyyMm;
}

class _ChurnSkeleton extends StatelessWidget {
  const _ChurnSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: DokkoTokens.space16),
                const Expanded(
                  child: DokkoSkeleton(
                      height: 96, borderRadius: DokkoTokens.radiusLg),
                ),
              ],
            ],
          ),
          const SizedBox(height: DokkoTokens.space16),
          const DokkoSkeleton(height: 44, borderRadius: DokkoTokens.radiusLg),
          const SizedBox(height: DokkoTokens.space8),
          ...List.generate(5, (_) => const Padding(
            padding: EdgeInsets.only(bottom: DokkoTokens.space8),
            child: DokkoSkeleton(height: 40),
          )),
          const SizedBox(height: DokkoTokens.space24),
          const DokkoSkeleton(
              height: 240, borderRadius: DokkoTokens.radiusLg),
        ],
      ),
    );
  }
}