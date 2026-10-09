import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_card.dart';
import '../data/gym_api.dart';

class GymReportsScreen extends ConsumerStatefulWidget {
  const GymReportsScreen({super.key});

  @override
  ConsumerState<GymReportsScreen> createState() => _GymReportsScreenState();
}

class _GymReportsScreenState extends ConsumerState<GymReportsScreen> {
  int _selectedDays = 30;
  final List<int> _periodOptions = [7, 14, 30, 90];

  List<dynamic> _revenue = [];
  List<dynamic> _checkins = [];
  Map<String, dynamic> _memberStatus = {};
  bool _isLoading = true;
  bool _isExportingCsv = false;
  bool _isExportingPdf = false;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(gymApiProvider);
      final results = await Future.wait([
        api.getRevenueReport(days: _selectedDays),
        api.getCheckinsReport(days: _selectedDays),
        api.getMembersStatusReport(),
      ]);
      if (!mounted) return;
      setState(() {
        _revenue = results[0] as List;
        _checkins = results[1] as List;
        _memberStatus = results[2] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ── CSV Export ──────────────────────────────────────────────────────────────
  Future<void> _exportCsv() async {
    setState(() => _isExportingCsv = true);
    try {
      final sb = StringBuffer();
      sb.writeln('Fecha;Total;Membresías;POS');
      for (final r in _revenue) {
        sb.writeln(
            '${r['date']};${r['total']};${r['memberships']};${r['pos']}');
      }
      sb.writeln();
      sb.writeln('Fecha;Check-ins');
      for (final c in _checkins) {
        sb.writeln('${c['date']};${c['count']}');
      }
      sb.writeln();
      sb.writeln('Estado;Cantidad');
      for (final e in _memberStatus.entries) {
        sb.writeln('${e.key};${e.value}');
      }
      final stamp =
          DateTime.now().toIso8601String().split('.').first.replaceAll(':', '-');
      final path = '${Directory.systemTemp.path}/dokko_reports_$stamp.csv';
      await File(path).writeAsString(sb.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV exportado a $path'),
          backgroundColor: DokkoTokens.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar CSV: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  // ── PDF Export ──────────────────────────────────────────────────────────────
  Future<void> _exportPdf() async {
    setState(() => _isExportingPdf = true);
    try {
      final doc = pw.Document();
      final hdrStyle = pw.TextStyle(
          fontSize: 18, fontWeight: pw.FontWeight.bold);
      final subStyle = pw.TextStyle(fontSize: 11, color: PdfColors.grey600);

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Header(
            text: 'Dokko — Reportes',
            textStyle: hdrStyle,
          ),
          pw.Text('Período: $_selectedDays días', style: subStyle),
          pw.SizedBox(height: 16),
          pw.Text('Ingresos por día', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Fecha', 'Total', 'Membresías', 'POS'],
            data: _revenue
                .map((r) => [
                      '${r['date']}',
                      '${r['total']}',
                      '${r['memberships']}',
                      '${r['pos']}',
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Check-ins por día', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Fecha', 'Check-ins'],
            data: _checkins
                .map((c) => ['${c['date']}', '${c['count']}'])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Estado de miembros', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Estado', 'Cantidad'],
            data: _memberStatus.entries.map((e) => [e.key, '${e.value}']).toList(),
          ),
        ],
      ));
      final stamp =
          DateTime.now().toIso8601String().split('.').first.replaceAll(':', '-');
      final path = '${Directory.systemTemp.path}/dokko_reports_$stamp.pdf';
      await File(path).writeAsBytes(await doc.save());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF exportado a $path'),
          backgroundColor: DokkoTokens.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      body: Padding(
        padding: const EdgeInsets.all(DokkoTokens.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Reportes',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: DokkoTokens.text,
                  ),
                ),
                // Export + period selector
                Row(
                  children: [
                    DokkoButton(
                      key: const ValueKey('export-csv-btn'),
                      label: 'CSV',
                      variant: DokkoButtonVariant.secondary,
                      isLoading: _isExportingCsv,
                      onPressed: _exportCsv,
                    ),
                    const SizedBox(width: DokkoTokens.space8),
                    DokkoButton(
                      key: const ValueKey('export-pdf-btn'),
                      label: 'PDF',
                      variant: DokkoButtonVariant.secondary,
                      isLoading: _isExportingPdf,
                      onPressed: _exportPdf,
                    ),
                    const SizedBox(width: DokkoTokens.space16),
                    ..._periodOptions.map((d) {
                    final selected = d == _selectedDays;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedDays = d);
                        _fetchAll();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(left: DokkoTokens.space8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: DokkoTokens.space12,
                          vertical: DokkoTokens.space8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? DokkoTokens.accentDefault.withValues(alpha: 0.15)
                              : DokkoTokens.surface,
                          borderRadius:
                              BorderRadius.circular(DokkoTokens.radiusMd),
                          border: Border.all(
                            color: selected
                                ? DokkoTokens.accentDefault
                                : DokkoTokens.line,
                          ),
                        ),
                        child: Text(
                          '${d}d',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selected
                                ? DokkoTokens.accentDefault
                                : DokkoTokens.text2,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
            ),
            const SizedBox(height: DokkoTokens.space24),

            if (_isLoading)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Row 1: Revenue chart + Member status donut
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 3,
                              child: DokkoCard(
                                child: _RevenueChart(data: _revenue),
                              ),
                            ),
                            const SizedBox(width: DokkoTokens.space16),
                            SizedBox(
                              width: 260,
                              child: DokkoCard(
                                child: _MemberStatusDonut(
                                    status: _memberStatus),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: DokkoTokens.space16),
                      // Row 2: Checkins bar chart
                      DokkoCard(
                        child: _CheckinsChart(data: _checkins),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Revenue Line Chart
// ─────────────────────────────────────────────────────────────────────────────
class _RevenueChart extends StatelessWidget {
  final List<dynamic> data;
  const _RevenueChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.fold<double>(
        0.0, (sum, d) => sum + (d['total'] as num).toDouble());
    final memberships = data.fold<double>(
        0.0, (sum, d) => sum + (d['memberships'] as num).toDouble());
    final pos = data.fold<double>(
        0.0, (sum, d) => sum + (d['pos'] as num).toDouble());

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(),
          (e.value['total'] as num).toDouble());
    }).toList();

    final maxY = spots.isEmpty
        ? 100.0
        : (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2)
            .clamp(1.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ingresos',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: DokkoTokens.text),
        ),
        const SizedBox(height: DokkoTokens.space4),
        // KPI row
        Wrap(
          spacing: DokkoTokens.space16,
          children: [
            _KpiChip(
              label: 'Total',
              value: '\$${total.toStringAsFixed(0)}',
              color: DokkoTokens.accentDefault,
            ),
            _KpiChip(
              label: 'Membresías',
              value: '\$${memberships.toStringAsFixed(0)}',
              color: DokkoTokens.green,
            ),
            _KpiChip(
              label: 'POS',
              value: '\$${pos.toStringAsFixed(0)}',
              color: DokkoTokens.amber,
            ),
          ],
        ),
        const SizedBox(height: DokkoTokens.space20),
        SizedBox(
          height: 200,
          child: spots.isEmpty || spots.every((s) => s.y == 0)
              ? const Center(
                  child: Text('Sin datos de ingresos.',
                      style: TextStyle(color: DokkoTokens.text2)))
              : LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY,
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
                          reservedSize: 48,
                          getTitlesWidget: (v, meta) => Text(
                            '\$${v.toInt()}',
                            style: const TextStyle(
                                fontSize: 10, color: DokkoTokens.text3),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: (data.length / 5).ceilToDouble(),
                          getTitlesWidget: (v, meta) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= data.length) {
                              return const SizedBox.shrink();
                            }
                            final dateStr =
                                data[idx]['date'] as String;
                            final parts = dateStr.split('-');
                            return Text(
                              '${parts[2]}/${parts[1]}',
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
                        color: DokkoTokens.accentDefault,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: DokkoTokens.accentDefault.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => DokkoTokens.surface,
                        getTooltipItems: (spots) => spots
                            .map((s) => LineTooltipItem(
                                  '\$${s.y.toStringAsFixed(2)}',
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

// ─────────────────────────────────────────────────────────────────────────────
// Member Status Donut
// ─────────────────────────────────────────────────────────────────────────────
class _MemberStatusDonut extends StatefulWidget {
  final Map<String, dynamic> status;
  const _MemberStatusDonut({required this.status});

  @override
  State<_MemberStatusDonut> createState() => _MemberStatusDonutState();
}

class _MemberStatusDonutState extends State<_MemberStatusDonut> {
  int _touchedIndex = -1;

  static const _colors = {
    'active':    DokkoTokens.green,
    'expired':   DokkoTokens.amber,
    'suspended': DokkoTokens.red,
    'cancelled': DokkoTokens.text3,
  };

  static const _labels = {
    'active':    'Activos',
    'expired':   'Vencidos',
    'suspended': 'Suspendidos',
    'cancelled': 'Cancelados',
  };

  @override
  Widget build(BuildContext context) {
    final total = widget.status.values
        .fold<int>(0, (sum, v) => sum + (v as int));

    final sections = widget.status.entries
        .where((e) => (e.value as int) > 0)
        .map((e) {
          final idx = widget.status.keys.toList().indexOf(e.key);
          final isTouched = idx == _touchedIndex;
          return PieChartSectionData(
            value: (e.value as int).toDouble(),
            color: _colors[e.key] ?? DokkoTokens.text2,
            radius: isTouched ? 60 : 50,
            title: '',
            borderSide: isTouched
                ? const BorderSide(
                    color: DokkoTokens.text, width: 2)
                : BorderSide.none,
          );
        })
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Miembros',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: DokkoTokens.text),
        ),
        const SizedBox(height: DokkoTokens.space4),
        Text(
          '$total total',
          style: const TextStyle(fontSize: 12, color: DokkoTokens.text2),
        ),
        const SizedBox(height: DokkoTokens.space16),
        SizedBox(
          height: 160,
          child: total == 0
              ? const Center(
                  child: Text('Sin miembros.',
                      style: TextStyle(color: DokkoTokens.text2)))
              : PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback:
                          (FlTouchEvent event, PieTouchResponse? res) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              res == null ||
                              res.touchedSection == null) {
                            _touchedIndex = -1;
                          } else {
                            _touchedIndex = res
                                .touchedSection!.touchedSectionIndex;
                          }
                        });
                      },
                    ),
                  ),
                ),
        ),
        const SizedBox(height: DokkoTokens.space16),
        // Legend
        ...widget.status.entries.map((e) => Padding(
              padding:
                  const EdgeInsets.only(bottom: DokkoTokens.space8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _colors[e.key] ?? DokkoTokens.text2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: DokkoTokens.space8),
                  Expanded(
                    child: Text(
                      _labels[e.key] ?? e.key,
                      style: const TextStyle(
                          fontSize: 12, color: DokkoTokens.text2),
                    ),
                  ),
                  Text(
                    '${e.value}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: DokkoTokens.text),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Check-ins Bar Chart
// ─────────────────────────────────────────────────────────────────────────────
class _CheckinsChart extends StatelessWidget {
  final List<dynamic> data;
  const _CheckinsChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final totalCheckins = data.fold<int>(
        0, (sum, d) => sum + (d['count'] as int));

    final maxY = data.isEmpty
        ? 10.0
        : (data
                    .map((d) => (d['count'] as int).toDouble())
                    .reduce((a, b) => a > b ? a : b) *
                1.3)
            .clamp(1.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Check-ins por Día',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: DokkoTokens.text),
            ),
            const SizedBox(width: DokkoTokens.space16),
            _KpiChip(
              label: 'Total período',
              value: '$totalCheckins',
              color: DokkoTokens.green,
            ),
          ],
        ),
        const SizedBox(height: DokkoTokens.space20),
        SizedBox(
          height: 180,
          child: data.isEmpty || data.every((d) => d['count'] == 0)
              ? const Center(
                  child: Text('Sin check-ins en el período.',
                      style: TextStyle(color: DokkoTokens.text2)))
              : BarChart(
                  BarChartData(
                    maxY: maxY,
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
                          reservedSize: 32,
                          getTitlesWidget: (v, meta) => Text(
                            v.toInt().toString(),
                            style: const TextStyle(
                                fontSize: 10, color: DokkoTokens.text3),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: (data.length / 6).ceilToDouble(),
                          getTitlesWidget: (v, meta) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= data.length) {
                              return const SizedBox.shrink();
                            }
                            final dateStr =
                                data[idx]['date'] as String;
                            final parts = dateStr.split('-');
                            return Text(
                              '${parts[2]}/${parts[1]}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: DokkoTokens.text3),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: data.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: (e.value['count'] as int).toDouble(),
                            color: DokkoTokens.green,
                            width: (600 / data.length).clamp(4.0, 20.0),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => DokkoTokens.surface,
                        getTooltipItem: (group, groupIdx, rod, rodIdx) =>
                            BarTooltipItem(
                          '${rod.toY.toInt()} check-ins',
                          const TextStyle(
                              color: DokkoTokens.text, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI chip helper
// ─────────────────────────────────────────────────────────────────────────────
class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8))),
          const SizedBox(width: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}
