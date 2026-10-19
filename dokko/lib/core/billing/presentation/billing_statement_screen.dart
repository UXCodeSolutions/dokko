import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import '../../theme/dokko_tokens.dart';
import '../../widgets/dokko_card.dart';
import '../../widgets/dokko_button.dart';

class BillingStatementScreen extends ConsumerStatefulWidget {
  const BillingStatementScreen({super.key});

  @override
  ConsumerState<BillingStatementScreen> createState() => _BillingStatementScreenState();
}

class _BillingStatementScreenState extends ConsumerState<BillingStatementScreen> {
  Map<String, dynamic>? _statement;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStatement();
  }

  Future<void> _fetchStatement() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token =
          Supabase.instance.client.auth.currentSession?.accessToken ?? '';
      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
      final response = await http.get(
        Uri.parse('$baseUrl/billing/statement'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw Exception(response.body);
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (mounted) setState(() => _statement = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    return dt == null ? '—' : '${dt.year}-${_p(dt.month)}-${_p(dt.day)}';
  }

  String _p(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DokkoTokens.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Estado de cuenta',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: DokkoTokens.text,
                ),
              ),
              const Spacer(),
              DokkoButton(
                label: 'Actualizar',
                variant: DokkoButtonVariant.secondary,
                onPressed: _isLoading ? null : _fetchStatement,
              ),
            ],
          ),
          const SizedBox(height: DokkoTokens.space24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            DokkoCard(
              child: Text('No se pudo cargar tu estado de cuenta: $_error',
                  style: const TextStyle(color: DokkoTokens.text2)),
            )
          else if (_statement == null)
            const CenteredMessage('Sin datos aún.')
          else ..._buildContent(),
        ],
      ),
    );
  }

  List<Widget> _buildContent() {
    final s = _statement!;
    final tenant = (s['tenant'] as Map<String, dynamic>?) ?? {};
    final grace = (s['grace_days'] as num?)?.toInt() ?? 7;
    final subs = (s['subscriptions'] as List?) ?? [];
    final payments = (s['payments'] as List?) ?? [];
    final isCurrent = s['is_current'] == true;
    final daysOverdue = (s['days_overdue'] as num?)?.toInt() ?? 0;
    final inGrace = s['in_grace'] == true;

    final tenantStatus = tenant['status'] as String? ?? 'active';

    return [
      DokkoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusDot(status: tenantStatus),
                const SizedBox(width: 8),
                Text(
                  _labelFor(tenantStatus),
                  style: const TextStyle(
                      color: DokkoTokens.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  'Gracia configurada: $grace días',
                  style: const TextStyle(color: DokkoTokens.text2, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoLine(label: 'Negocio', value: tenant['name']?.toString() ?? '—'),
            _InfoLine(label: 'Días de gracia', value: '$grace días'),
            if (daysOverdue > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (inGrace ? DokkoTokens.amber : DokkoTokens.red)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      inGrace ? Icons.hourglass_top : Icons.error_outline,
                      size: 16,
                      color: inGrace ? DokkoTokens.amber : DokkoTokens.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        inGrace
                            ? 'Tu suscripción venció hace $daysOverdue días. Estás dentro del periodo de gracia ($grace días). Renueva para evitar la suspensión.'
                            : 'Tu suscripción está vencida hace $daysOverdue días. Sin pago, el negocio se suspenderá automáticamente.',
                        style: const TextStyle(fontSize: 12, color: DokkoTokens.text),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isCurrent)
              const SizedBox(height: 8) else
              const SizedBox(height: 8),
          ],
        ),
      ),
      const SizedBox(height: DokkoTokens.space16),
      DokkoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Suscripción',
                style: TextStyle(color: DokkoTokens.text, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (subs.isEmpty)
              const Text('Sin suscripción activa registrada.',
                  style: TextStyle(color: DokkoTokens.text2, fontSize: 12))
            else
              ...subs.map((sub) {
                final plan = (sub['plan'] as Map<String, dynamic>?) ?? {};
                final price = (plan['base_price'] as num?)?.toStringAsFixed(2) ?? '—';
                final interval = plan['interval']?.toString() ?? '';
                final planName = plan['name']?.toString() ?? 'Plan Dokko';
                final end = sub['current_period_end']?.toString();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium_outlined, size: 16, color: DokkoTokens.text2),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('$planName${interval.isNotEmpty ? ' ($interval)' : ''}',
                            style: const TextStyle(color: DokkoTokens.text, fontSize: 13)),
                      ),
                      Text('RD\$$price',
                          style: const TextStyle(color: DokkoTokens.text, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      Text('Fin: ${_fmtDate(end)}',
                          style: const TextStyle(color: DokkoTokens.text2, fontSize: 12)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
      const SizedBox(height: DokkoTokens.space16),
      DokkoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historial de pagos',
                style: TextStyle(color: DokkoTokens.text, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (payments.isEmpty)
              const Text('Aún no hay pagos registrados.',
                  style: TextStyle(color: DokkoTokens.text2, fontSize: 12))
            else
              ...payments.map((p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (p['status'] == 'paid' || p['status'] == 'succeeded'
                                    ? DokkoTokens.green
                                    : DokkoTokens.amber)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            (p['status'] ?? '—').toString().toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: p['status'] == 'paid' || p['status'] == 'succeeded'
                                    ? DokkoTokens.green
                                    : DokkoTokens.amber),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('RD\$${((p['amount'] as num?) ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(color: DokkoTokens.text, fontSize: 13)),
                        const Spacer(),
                        Text(_fmtDate(p['created_at']?.toString()),
                            style: const TextStyle(color: DokkoTokens.text2, fontSize: 12)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    ];
  }

  String _labelFor(String status) {
    switch (status) {
      case 'suspended':
        return 'Suscripción suspendida — contacta a Dokko';
      case 'cancelled':
        return 'Suscripción cancelada';
      default:
        return 'Suscripción activa';
    }
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'active'
        ? DokkoTokens.green
        : status == 'suspended'
            ? DokkoTokens.red
            : DokkoTokens.amber;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: DokkoTokens.text2, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: DokkoTokens.text, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class CenteredMessage extends StatelessWidget {
  final String message;
  const CenteredMessage(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: const TextStyle(color: DokkoTokens.text2)),
    );
  }
}