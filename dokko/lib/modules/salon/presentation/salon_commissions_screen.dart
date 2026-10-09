import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_card.dart';
import '../../../core/widgets/dokko_empty_state.dart';
import '../data/salon_api.dart';

class SalonCommissionsScreen extends ConsumerStatefulWidget {
  const SalonCommissionsScreen({super.key});

  @override
  ConsumerState<SalonCommissionsScreen> createState() =>
      _SalonCommissionsScreenState();
}

class _SalonCommissionsScreenState
    extends ConsumerState<SalonCommissionsScreen> {
  int _selectedDays = 30;
  final List<int> _periodOptions = [7, 14, 30, 90];

  List<dynamic> _commissions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(salonApiProvider);
      final res = await api.getCommissionSummary(days: _selectedDays);
      if (!mounted) return;
      setState(() {
        _commissions = res;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  double get _totalCommissions => _commissions.fold(
      0.0, (acc, c) => acc + (c['total_commission'] as num? ?? 0).toDouble());

  double get _totalSales => _commissions.fold(
      0.0, (acc, c) => acc + (c['total_sales'] as num? ?? 0).toDouble());

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
                  'Comisiones',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: DokkoTokens.text,
                  ),
                ),
                Row(
                  children: _periodOptions.map((d) {
                    final selected = d == _selectedDays;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedDays = d);
                        _fetch();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(left: DokkoTokens.space8),
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
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: DokkoTokens.space16),

            // KPIs
            if (!_isLoading && _commissions.isNotEmpty)
              Row(
                children: [
                  _KpiCard(
                    label: 'Total comisiones',
                    value: _totalCommissions.toStringAsFixed(2),
                  ),
                  const SizedBox(width: DokkoTokens.space12),
                  _KpiCard(
                    label: 'Ventas con comisión',
                    value: _totalSales.toStringAsFixed(2),
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
                    : _commissions.isEmpty
                        ? const DokkoEmptyState(
                            icon: Icons.monetization_on_rounded,
                            message:
                                'Sin comisiones en el período.\nAsigna un estilista al vender para generar comisiones.',
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
                                        child: Text('Estilista',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: DokkoTokens.text2,
                                                fontWeight:
                                                    FontWeight.w500))),
                                    Expanded(
                                        child: Text('Ventas',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: DokkoTokens.text2,
                                                fontWeight:
                                                    FontWeight.w500))),
                                    Expanded(
                                        child: Text('Total ventas',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: DokkoTokens.text2,
                                                fontWeight:
                                                    FontWeight.w500))),
                                    Expanded(
                                        child: Text('Comisión',
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
                                  itemCount: _commissions.length,
                                  separatorBuilder: (ctx, i) => const Divider(
                                      height: 1, color: DokkoTokens.line),
                                  itemBuilder: (ctx, i) {
                                    final c = _commissions[i];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: DokkoTokens.space16,
                                          vertical: DokkoTokens.space12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                              flex: 2,
                                              child: Text(
                                                c['employee_name'] ?? '—',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color: DokkoTokens.text),
                                              )),
                                          Expanded(
                                              child: Text(
                                                '${c['sales_count'] ?? 0}',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color: DokkoTokens.text),
                                              )),
                                          Expanded(
                                              child: Text(
                                                '\$${c['total_sales'] ?? 0}',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color: DokkoTokens.text),
                                              )),
                                          Expanded(
                                              child: Text(
                                                '\$${c['total_commission'] ?? 0}',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: DokkoTokens.green),
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