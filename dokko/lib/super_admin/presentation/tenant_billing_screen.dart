import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_card.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_empty_state.dart';

class TenantBillingScreen extends ConsumerStatefulWidget {
  const TenantBillingScreen({super.key});

  @override
  ConsumerState<TenantBillingScreen> createState() => _TenantBillingScreenState();
}

class _TenantBillingScreenState extends ConsumerState<TenantBillingScreen> {
  List<Map<String, dynamic>> _overdue = [];
  List<Map<String, dynamic>> _tenants = [];
  bool _isLoading = true;
  bool _checking = false;
  String? _lastCheckMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken ?? '';
      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
      final overdueRes = await http.get(
        Uri.parse('$baseUrl/billing/overdue'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (overdueRes.statusCode == 200) {
        final data = jsonDecode(overdueRes.body) as List;
        _overdue = List<Map<String, dynamic>>.from(data);
      }
    } catch (_) {
      _overdue = [];
    }
    try {
      final res = await Supabase.instance.client
          .from('tenants')
          .select('id, name, status, brand_config')
          .order('created_at');
      _tenants = List<Map<String, dynamic>>.from(res);
    } catch (_) {
      _tenants = [];
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _runSuspensionCheck() async {
    setState(() => _checking = true);
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken ?? '';
      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
      final response = await http.post(
        Uri.parse('$baseUrl/billing/suspension-check'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final checked = data['checked']?.toString() ?? '0';
      final suspended = data['suspended']?.toString() ?? '0';
      setState(() => _lastCheckMessage =
          'Revisión completada: $checked negocio(s) revisados · $suspended suspendido(s).');
      await _load();
    } catch (e) {
      setState(() => _lastCheckMessage = 'No se pudo ejecutar la revisión: $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  int _graceOf(Map<String, dynamic> tenant) {
    final bc = tenant['brand_config'] as Map<String, dynamic>? ?? {};
    final g = bc['grace_days'];
    if (g is num && g > 0) return g.toInt();
    return 7;
  }

  Future<void> _setGrace(String tenantId, int days) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken ?? '';
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
    final response = await http.put(
      Uri.parse('$baseUrl/billing/grace'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'tenant_id': tenantId, 'grace_days': days}),
    );
    if (response.statusCode != 200) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar la gracia: ${response.body}')),
        );
      }
      return;
    }
    await _load();
  }

  Future<void> _askGrace(Map<String, dynamic> tenant) async {
    final controller = TextEditingController(text: _graceOf(tenant).toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Días de gracia'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Días (0 - 60)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text) ?? 7),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != null) await _setGrace(tenant['id'] as String, result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DokkoTokens.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: DokkoTokens.space12,
            runSpacing: DokkoTokens.space12,
            children: [
              const Text(
                'Facturación Global',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: DokkoTokens.text),
              ),
              Wrap(
                spacing: DokkoTokens.space12,
                runSpacing: DokkoTokens.space8,
                children: [
                  DokkoButton(
                    label: 'Revisar suspensiones',
                    variant: DokkoButtonVariant.secondary,
                    isLoading: _checking,
                    onPressed: _checking ? null : _runSuspensionCheck,
                  ),
                  DokkoButton(
                    label: 'Actualizar',
                    variant: DokkoButtonVariant.outline,
                    onPressed: _isLoading ? null : _load,
                  ),
                ],
              ),
            ],
          ),

          if (_lastCheckMessage != null) ...[
            const SizedBox(height: DokkoTokens.space12),
            Container(
              padding: const EdgeInsets.all(DokkoTokens.space12),
              decoration: BoxDecoration(
                color: DokkoTokens.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
              ),
              child: Text(_lastCheckMessage!,
                  style: const TextStyle(color: DokkoTokens.text, fontSize: 13)),
            ),
          ],
          const SizedBox(height: DokkoTokens.space24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      DokkoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pagos vencidos (notificaciones)',
                                style: TextStyle(color: DokkoTokens.text, fontSize: 15, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            if (_overdue.isEmpty)
                              const DokkoEmptyState(
                                icon: Icons.check_circle_outline,
                                message: 'No hay pagos vencidos.',
                              )
                            else
                              ..._overdue.map((o) => Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: (o['in_grace'] == true
                                              ? DokkoTokens.amber
                                              : DokkoTokens.red)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: (o['in_grace'] == true ? DokkoTokens.amber : DokkoTokens.red)
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          o['in_grace'] == true
                                              ? Icons.hourglass_top
                                              : Icons.error_outline,
                                          size: 18,
                                          color: o['in_grace'] == true
                                              ? DokkoTokens.amber
                                              : DokkoTokens.red,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(o['tenant_name'] as String? ?? 'Tenant',
                                                  style: const TextStyle(color: DokkoTokens.text, fontSize: 13, fontWeight: FontWeight.w600)),
                                              Text(
                                                '${o['days_overdue']} días vencido · '
                                                '${o['in_grace'] == true ? "dentro de gracia (${o['grace_days']}d)" : "FUERA de gracia"}'
                                                '${o['status'] == 'suspended' ? ' · SUSPENDIDO' : ''}',
                                                style: const TextStyle(fontSize: 12.5, color: DokkoTokens.text2),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(o['owner_email'] as String? ?? '',
                                            style: const TextStyle(fontSize: 12.5, color: DokkoTokens.text2)),
                                      ],
                                    ),
                                  )),
                          ],
                        ),
                      ),
                      const SizedBox(height: DokkoTokens.space16),
                      _BuildTenantsGraceTable(
                        tenants: _tenants,
                        graceOf: _graceOf,
                        onEdit: _askGrace,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _BuildTenantsGraceTable extends StatelessWidget {
  final List<Map<String, dynamic>> tenants;
  final int Function(Map<String, dynamic>) graceOf;
  final void Function(Map<String, dynamic>) onEdit;

  const _BuildTenantsGraceTable({
    required this.tenants,
    required this.graceOf,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return DokkoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Configuración por tenant',
              style: TextStyle(color: DokkoTokens.text, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'Los días de gracia controlan cuándo se suspende automáticamente un negocio con pago vencido.',
            style: TextStyle(color: DokkoTokens.text2, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...tenants.map((t) => Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: DokkoTokens.line.withValues(alpha: 0.5)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor(t['status'] as String? ?? 'active').withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        (t['status'] as String? ?? 'active').toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(t['status'] as String? ?? 'active'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(t['name'] as String? ?? '—',
                          style: const TextStyle(color: DokkoTokens.text, fontSize: 13)),
                    ),
                    Text('Gracia: ${graceOf(t)} días',
                        style: const TextStyle(color: DokkoTokens.text2, fontSize: 13)),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => onEdit(t),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.edit_outlined, size: 16, color: DokkoTokens.text2),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return DokkoTokens.green;
      case 'suspended':
        return DokkoTokens.red;
      default:
        return DokkoTokens.amber;
    }
  }
}