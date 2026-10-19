import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_card.dart';
import '../../../core/providers/tenant_provider.dart';
import '../providers/gym_provider.dart';

class GymDashboardScreen extends ConsumerWidget {
  const GymDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(gymKpisProvider);
    final tenant = ref.watch(tenantProvider).value;
    
    final primaryColor = tenant?.accentColor ?? DokkoTokens.accentDefault;

    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DokkoTokens.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Dashboard Gym',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: DokkoTokens.text,
              ),
            ),
            const SizedBox(height: DokkoTokens.space24),
            kpisAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error: $err', style: const TextStyle(color: Colors.red)),
              data: (kpis) {
                final cards = [
                  _KpiCard(
                    title: 'Miembros Activos',
                    value: '${kpis['active_members_count']}',
                    icon: Icons.people_rounded,
                    color: primaryColor,
                  ),
                  _KpiCard(
                    title: 'Ingresos del Mes',
                    value: '\$${kpis['monthly_revenue']}',
                    icon: Icons.attach_money_rounded,
                    color: DokkoTokens.green,
                  ),
                  _KpiCard(
                    title: 'Vencimientos a 7 Días',
                    value: '${kpis['upcoming_expirations_count']}',
                    icon: Icons.warning_rounded,
                    color: DokkoTokens.amber,
                  ),
                  _KpiCard(
                    title: 'Check-ins Hoy',
                    value: '${kpis['checkins_today']}',
                    icon: Icons.qr_code_scanner_rounded,
                    color: primaryColor,
                  ),
                ];

                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 680) {
                      final isSingleCol = constraints.maxWidth < 420;
                      return GridView.count(
                        crossAxisCount: isSingleCol ? 1 : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: DokkoTokens.space12,
                        mainAxisSpacing: DokkoTokens.space12,
                        childAspectRatio: isSingleCol ? 2.6 : 1.35,
                        children: cards,
                      );
                    }

                    return Row(
                      children: cards
                          .map((c) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: DokkoTokens.space8,
                                  ),
                                  child: c,
                                ),
                              ))
                          .toList(),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DokkoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: color),
                const SizedBox(width: DokkoTokens.space8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: DokkoTokens.text2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DokkoTokens.space16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: DokkoTokens.text,
              ),
            ),
          ],
        ),
      );
  }
}

