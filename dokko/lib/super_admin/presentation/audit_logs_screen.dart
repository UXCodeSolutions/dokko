import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_card.dart';
import '../../../core/widgets/dokko_empty_state.dart';
import '../../../core/widgets/dokko_table.dart';

class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('audit_log')
          .select('*, tenants(name)')
          .order('created_at', ascending: false)
          .limit(100);
      setState(() {
        _logs = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    final dt = DateTime.parse(dateStr).toLocal();
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DokkoTokens.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Log de Auditoría',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: DokkoTokens.text,
            ),
          ),
          const SizedBox(height: DokkoTokens.space24),
          Expanded(
            child: DokkoCard(
              padding: EdgeInsets.zero,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _logs.isEmpty
                      ? const DokkoEmptyState(
                          icon: Icons.history_rounded,
                          message: 'No hay eventos en el log.',
                        )
                      : DokkoTable<Map<String, dynamic>>(
                          columns: const [
                            DokkoTableColumn(title: 'Fecha', width: 140),
                            DokkoTableColumn(title: 'Acción', flex: 2),
                            DokkoTableColumn(title: 'Tenant', flex: 2),
                            DokkoTableColumn(title: 'Entidad', width: 100),
                          ],
                          data: _logs,
                          cellValue: (item, index) {
                            switch (index) {
                              case 0:
                                return _formatDate(item['created_at']);
                              case 1:
                                return item['action'] ?? '—';
                              case 2:
                                return item['tenants']?['name'] ?? '—';
                              case 3:
                                return item['entity'] ?? '—';
                              default:
                                return '';
                            }
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
