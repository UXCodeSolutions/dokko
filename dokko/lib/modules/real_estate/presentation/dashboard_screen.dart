import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_card.dart';
import 'properties_screen.dart'; // To use propertiesProvider

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(propertiesProvider);

    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      appBar: AppBar(
        title: const Text('Dashboard Inmobiliario', style: TextStyle(color: DokkoTokens.text)),
        backgroundColor: DokkoTokens.surface,
        elevation: 0,
      ),
      body: propertiesAsync.when(
        data: (properties) {
          final activeCount = properties.where((p) => p.status != 'inactive').length;
          final saleProperties = properties.where((p) => p.operationType == 'sale' || p.operationType == 'both');
          final totalSaleValue = saleProperties.fold<double>(0, (sum, p) => sum + (p.priceSale ?? 0));

          return ListView(
            padding: const EdgeInsets.all(DokkoTokens.space16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      'Propiedades Activas',
                      activeCount.toString(),
                      Icons.home_work_rounded,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: DokkoTokens.space16),
                  Expanded(
                    child: _buildKpiCard(
                      'Valor de Venta (USD)',
                      '\$${(totalSaleValue / 1000).toStringAsFixed(1)}K',
                      Icons.monetization_on_rounded,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DokkoTokens.space16),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      'Nuevos Leads',
                      '0', // Módulo 19
                      Icons.people_alt_rounded,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: DokkoTokens.space16),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return DokkoCard(
      padding: const EdgeInsets.all(DokkoTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: DokkoTokens.space16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: DokkoTokens.text,
            ),
          ),
          const SizedBox(height: DokkoTokens.space4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: DokkoTokens.text2,
            ),
          ),
        ],
      ),
    );
  }
}
