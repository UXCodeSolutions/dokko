import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_card.dart';
import '../../../core/widgets/dokko_empty_state.dart';
import '../data/salon_api.dart';

class SalonReportsScreen extends ConsumerStatefulWidget {
  const SalonReportsScreen({super.key});

  @override
  ConsumerState<SalonReportsScreen> createState() => _SalonReportsScreenState();
}

class _SalonReportsScreenState extends ConsumerState<SalonReportsScreen> {
  int _selectedDays = 30;
  final List<int> _periodOptions = [7, 14, 30, 90];

  List<dynamic> _revenue = [];
  bool _isLoading = true;
  bool _isExportingCsv = false;
  bool _isExportingPdf = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(salonApiProvider);
      final res = await api.getRevenueReport(days: _selectedDays);
      if (!mounted) return;
      setState(() {
        _revenue = res;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  double get _totalRevenue => _revenue.fold(
      0.0, (acc, r) => acc + (r['total'] as num? ?? 0).toDouble());

  double get _totalPos => _revenue.fold(
      0.0, (acc, r) => acc + (r['pos'] as num? ?? 0).toDouble());

  Future<void> _exportCsv() async {
    setState(() => _isExportingCsv = true);
    try {
      final sb = StringBuffer();
      sb.writeln('Fecha;Total;POS');
      for (final r in _revenue) {
        sb.writeln('${r['date']};${r['total']};${r['pos']}');
      }
      final stamp =
          DateTime.now().toIso8601String().split('.').first.replaceAll(':', '-');
      final path = '${Directory.systemTemp.path}/salon_reports_$stamp.csv';
      await File(path).writeAsString(sb.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const ValueKey('salon-export-snackbar'),
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

  Future<void> _exportPdf() async {
    setState(() => _isExportingPdf = true);
    try {
      final doc = pw.Document();
      final hdrStyle =
          pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);
      final subStyle = pw.TextStyle(fontSize: 11, color: PdfColors.grey600);

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Header(
            text: 'Dokko SalonOS — Reportes',
            textStyle: hdrStyle,
          ),
          pw.Text('Período: $_selectedDays días', style: subStyle),
          pw.SizedBox(height: 16),
          pw.Text('Ingresos POS por día',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Fecha', 'Total', 'POS'],
            data: _revenue
                .map((r) => ['${r['date']}', '${r['total']}', '${r['pos']}'])
                .toList(),
          ),
        ],
      ));
      final stamp =
          DateTime.now().toIso8601String().split('.').first.replaceAll(':', '-');
      final path = '${Directory.systemTemp.path}/salon_reports_$stamp.pdf';
      await File(path).writeAsBytes(await doc.save());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const ValueKey('salon-export-pdf-snackbar'),
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
                Row(
                  children: [
                    DokkoButton(
                      key: const ValueKey('salon-export-csv-btn'),
                      label: 'CSV',
                      variant: DokkoButtonVariant.secondary,
                      isLoading: _isExportingCsv,
                      onPressed: _exportCsv,
                    ),
                    const SizedBox(width: DokkoTokens.space8),
                    DokkoButton(
                      key: const ValueKey('salon-export-pdf-btn'),
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
                          _fetch();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin:
                              const EdgeInsets.only(left: DokkoTokens.space8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: DokkoTokens.space12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? DokkoTokens.accentDefault
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
                            '$d días',
                            style: TextStyle(
                              fontSize: 12,
                              color: selected
                                  ? DokkoTokens.bg
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
            const SizedBox(height: DokkoTokens.space16),

            // KPIs
            if (!_isLoading && _revenue.isNotEmpty)
              Row(
                children: [
                  _KpiCard(
                    label: 'Ingresos POS ($_selectedDays días)',
                    value: _totalPos.toStringAsFixed(2),
                  ),
                  const SizedBox(width: DokkoTokens.space12),
                  _KpiCard(
                    label: 'Total',
                    value: _totalRevenue.toStringAsFixed(2),
                  ),
                ],
              ),
            const SizedBox(height: DokkoTokens.space16),

            // Table
            Expanded(
              child: DokkoCard(
                padding: EdgeInsets.zero,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _revenue.isEmpty
                        ? const DokkoEmptyState(
                            icon: Icons.insights_rounded,
                            message: 'Sin ventas en el período.',
                          )
                        : Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: DokkoTokens.space16,
                                    vertical: DokkoTokens.space12),
                                decoration: const BoxDecoration(
                                  color: DokkoTokens.surface2,
                                  border: Border(
                                      bottom:
                                          BorderSide(color: DokkoTokens.line)),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(
                                        flex: 2,
                                        child: Text('Fecha',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: DokkoTokens.text2,
                                                fontWeight:
                                                    FontWeight.w500))),
                                    Expanded(
                                        child: Text('POS',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: DokkoTokens.text2,
                                                fontWeight:
                                                    FontWeight.w500))),
                                    Expanded(
                                        child: Text('Total',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: DokkoTokens.text2,
                                                fontWeight:
                                                    FontWeight.w500))),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: _revenue.length,
                                  separatorBuilder: (ctx, i) => const Divider(
                                      height: 1, color: DokkoTokens.line),
                                  itemBuilder: (ctx, i) {
                                    final r = _revenue[i];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: DokkoTokens.space16,
                                          vertical: DokkoTokens.space12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                              flex: 2,
                                              child: Text(
                                                '${r['date'] ?? '—'}',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color: DokkoTokens.text),
                                              )),
                                          Expanded(
                                              child: Text(
                                                '\$${r['pos'] ?? 0}',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color: DokkoTokens.text),
                                              )),
                                          Expanded(
                                              child: Text(
                                                '\$${r['total'] ?? 0}',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color:
                                                        DokkoTokens.green),
                                              )),
                                        ],
                                      ),
                                    );
                                  },
                                ),
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

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  const _KpiCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return DokkoCard(
      padding: const EdgeInsets.symmetric(
          horizontal: DokkoTokens.space16, vertical: DokkoTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: DokkoTokens.text2)),
          const SizedBox(height: DokkoTokens.space4),
          Text('\$$value',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: DokkoTokens.accentDefault)),
        ],
      ),
    );
  }
}