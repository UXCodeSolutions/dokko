import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_card.dart';
import '../data/models/realestate_models.dart';
import '../data/realestate_api.dart';

final leadsProvider = FutureProvider<List<RealEstateLead>>((ref) async {
  final api = ref.read(realEstateApiProvider);
  return api.getLeads();
});

class LeadsScreen extends ConsumerStatefulWidget {
  const LeadsScreen({super.key});

  @override
  ConsumerState<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends ConsumerState<LeadsScreen> {
  final List<String> _columns = [
    'new',
    'contacted',
    'visiting',
    'negotiating',
    'closed_won',
    'closed_lost'
  ];

  final Map<String, String> _columnTitles = {
    'new': 'Nuevos',
    'contacted': 'Contactados',
    'visiting': 'Visitando',
    'negotiating': 'Negociando',
    'closed_won': 'Ganados',
    'closed_lost': 'Perdidos',
  };

  void _showAddLeadModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _AddLeadModal(),
    ).then((value) {
      if (value == true) {
        ref.invalidate(leadsProvider);
      }
    });
  }

  // ── FASE 25 — Ley 172-13: portabilidad y supresión de datos de un lead ────
  Future<void> _exportLead(BuildContext context, RealEstateLead lead) async {
    try {
      final data =
          await ref.read(realEstateApiProvider).exportLeadData(lead.id);
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (_) => _LeadExportDialog(data: data),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    }
  }

  Future<void> _deleteLead(BuildContext context, RealEstateLead lead) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DokkoTokens.surface,
        title: const Text('Eliminar lead',
            style: TextStyle(color: DokkoTokens.text, fontSize: 18)),
        content: const Text(
          'Se eliminarán definitivamente los datos personales de este lead '
          'conforme al derecho de supresión de la Ley 172-13. '
          'Los expedientes y comisiones asociadas se conservarán sin vincularle.'
          'No se puede deshacer.',
          style: TextStyle(color: DokkoTokens.text2, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: DokkoTokens.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar',
                style: TextStyle(color: DokkoTokens.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(realEstateApiProvider).deleteLead(lead.id);
      ref.invalidate(leadsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lead eliminado.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(leadsProvider);

    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      appBar: AppBar(
        title: const Text('Leads / CRM', style: TextStyle(color: DokkoTokens.text)),
        backgroundColor: DokkoTokens.surface,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddLeadModal(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo Lead'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DokkoTokens.accentDefault,
                foregroundColor: Colors.white,
              ),
            ),
          )
        ],
      ),
      body: leadsAsync.when(
        data: (leads) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(DokkoTokens.space16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _columns.map((status) {
                    final columnLeads = leads.where((l) => l.status == status).toList();
                    return _buildKanbanColumn(status, _columnTitles[status]!, columnLeads, constraints.maxHeight);
                  }).toList(),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildKanbanColumn(String status, String title, List<RealEstateLead> leads, double height) {
    return Container(
      key: ValueKey('kanban-column-$status'),
      width: 300,
      height: height,
      margin: const EdgeInsets.only(right: DokkoTokens.space16),
      decoration: BoxDecoration(
        color: DokkoTokens.surface2,
        borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(DokkoTokens.space16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: DokkoTokens.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: DokkoTokens.bg,
                    borderRadius: BorderRadius.circular(DokkoTokens.radiusSm),
                  ),
                  child: Text(
                    '${leads.length}',
                    style: const TextStyle(color: DokkoTokens.text2, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: DokkoTokens.space16),
              itemCount: leads.length,
              itemBuilder: (context, index) {
                final lead = leads[index];
                return _LeadCard(
                  lead: lead,
                  onStatusChange: (newStatus) async {
                    try {
                      await ref.read(realEstateApiProvider).updateLead(lead.id, {'status': newStatus});
                      ref.invalidate(leadsProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  onExport: () => _exportLead(context, lead),
                  onDelete: () => _deleteLead(context, lead),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  final RealEstateLead lead;
  final Function(String) onStatusChange;
  final Future<void> Function()? onExport;
  final Future<void> Function()? onDelete;

  const _LeadCard({
    required this.lead,
    required this.onStatusChange,
    this.onExport,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DokkoTokens.space16),
      child: DokkoCard(
        padding: const EdgeInsets.all(DokkoTokens.space16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${lead.firstName} ${lead.lastName}',
                  style: const TextStyle(
                    color: DokkoTokens.text,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Consumer(
                builder: (context, ref, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Exportar datos (Ley 172-13)',
                      icon: const Icon(Icons.file_download_outlined,
                          color: DokkoTokens.text2, size: 18),
                      onPressed: () async {
                        final result = await ref
                            .read(realEstateApiProvider)
                            .exportLeadData(lead.id);
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: DokkoTokens.surface,
                              title: const Text('Exportar Datos (Ley 172-13)',
                                  style: TextStyle(color: DokkoTokens.text)),
                              content: Text(
                                result['consent_granted_at'] != null
                                    ? 'Consentimiento registrado.\nDosieres incluidos: '
                                        '${(result['dossiers'] as List?)?.length ?? 0}'
                                    : 'Sin consentimiento registrado.\nDosieres incluidos: '
                                        '${(result['dossiers'] as List?)?.length ?? 0}',
                                style: const TextStyle(
                                    color: DokkoTokens.text2),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cerrar',
                                      style: TextStyle(
                                          color: DokkoTokens.text2)),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Eliminar (Ley 172-13)',
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: DokkoTokens.red, size: 18),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: DokkoTokens.surface,
                            title: const Text('Eliminar lead',
                                style: TextStyle(color: DokkoTokens.red)),
                            content: const Text(
                              'Se eliminarán permanentemente los datos '
                              'personales del lead conforme a la Ley 172-13. '
                              'Se desvincularán sus dosieres y comisiones. '
                              '¿Continuar?',
                              style: TextStyle(color: DokkoTokens.text2),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancelar',
                                    style: TextStyle(
                                        color: DokkoTokens.text2)),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: DokkoTokens.red),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref
                              .read(realEstateApiProvider)
                              .deleteLead(lead.id);
                          if (context.mounted) {
                            ref.invalidate(leadsProvider);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DokkoTokens.space4),
          if (lead.phone != null) ...[
            Text('📞 ${lead.phone}', style: const TextStyle(color: DokkoTokens.text2, fontSize: 12)),
          ],
          if (lead.email != null) ...[
            Text('✉️ ${lead.email}', style: const TextStyle(color: DokkoTokens.text2, fontSize: 12)),
          ],
          const SizedBox(height: DokkoTokens.space8),
          if (lead.budgetMin != null || lead.budgetMax != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: DokkoTokens.accentDefault.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Presupuesto: \$${lead.budgetMin ?? 0} - \$${lead.budgetMax ?? "Sin límite"}',
                style: const TextStyle(color: DokkoTokens.accentDefault, fontSize: 11),
              ),
            ),
          const SizedBox(height: DokkoTokens.space16),
          _buildActionRow(context),
        ],
      ),
    ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildActionButton('Exportar', (_) async {
            if (onExport != null) await onExport!();
          },
              color: DokkoTokens.text2),
          const SizedBox(width: 8),
          _buildActionButton('Eliminar', (_) async {
            if (onDelete != null) await onDelete!();
          },
              color: DokkoTokens.red),
          if (lead.status != 'new' && lead.status != 'closed_won' && lead.status != 'closed_lost') ...[
            const SizedBox(width: 8),
            _buildStatusButton('Atrás', _getPrevStatus(lead.status)),
          ],
          if (lead.status != 'closed_won' && lead.status != 'closed_lost') ...[
            const SizedBox(width: 8),
            _buildStatusButton('Avanzar', _getNextStatus(lead.status)),
          ],
          if (lead.status != 'closed_won' && lead.status != 'closed_lost') ...[
            const SizedBox(width: 8),
            _buildStatusButton('Ganar', 'closed_won', color: Colors.green),
            const SizedBox(width: 8),
            _buildStatusButton('Perder', 'closed_lost', color: Colors.red),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Function(String) onTap, {Color color = Colors.grey}) {
    return InkWell(
      onTap: () => onTap.call(''),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(DokkoTokens.radiusSm),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 10),
        ),
      ),
    );
  }

  Widget _buildStatusButton(String label, String newStatus, {Color color = DokkoTokens.accentDefault}) {
    return InkWell(
      onTap: () => onStatusChange(newStatus),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(DokkoTokens.radiusSm),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 10),
        ),
      ),
    );
  }

  String _getNextStatus(String current) {
    switch (current) {
      case 'new': return 'contacted';
      case 'contacted': return 'visiting';
      case 'visiting': return 'negotiating';
      case 'negotiating': return 'closed_won';
      default: return current;
    }
  }

  String _getPrevStatus(String current) {
    switch (current) {
      case 'contacted': return 'new';
      case 'visiting': return 'contacted';
      case 'negotiating': return 'visiting';
      default: return current;
    }
  }
}

class _LeadExportDialog extends StatelessWidget {
  final dynamic data;
  const _LeadExportDialog({required this.data});

  @override
  Widget build(BuildContext context) {
    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    return Dialog(
      backgroundColor: DokkoTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
        side: const BorderSide(color: DokkoTokens.line),
      ),
      child: SizedBox(
        width: 560,
        height: 520,
        child: Padding(
          padding: const EdgeInsets.all(DokkoTokens.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Exportación de datos (Ley 172-13)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: DokkoTokens.text,
                ),
              ),
              const SizedBox(height: DokkoTokens.space8),
              const Text(
                'Copie o descargue este JSON para entregarlo al titular.',
                style: TextStyle(fontSize: 13, color: DokkoTokens.text2),
              ),
              const SizedBox(height: DokkoTokens.space16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(DokkoTokens.space16),
                  decoration: BoxDecoration(
                    color: DokkoTokens.surface2,
                    borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
                    border: Border.all(color: DokkoTokens.line),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      pretty,
                      style: const TextStyle(
                        fontSize: 12,
                        color: DokkoTokens.text,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DokkoTokens.space16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DokkoButton(
                    label: 'Cerrar',
                    variant: DokkoButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddLeadModal extends ConsumerStatefulWidget {
  const _AddLeadModal();

  @override
  ConsumerState<_AddLeadModal> createState() => _AddLeadModalState();
}

class _AddLeadModalState extends ConsumerState<_AddLeadModal> {
  final _formKey = GlobalKey<FormState>();
  String _firstName = '';
  String _lastName = '';
  String _phone = '';
  String _email = '';
  double? _budgetMin;
  double? _budgetMax;
  bool _isLoading = false;
  bool _consent = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);
    try {
      await ref.read(realEstateApiProvider).createLead({
        'first_name': _firstName,
        'last_name': _lastName,
        'phone': _phone,
        'email': _email,
        'budget_min': _budgetMin,
        'budget_max': _budgetMax,
        'status': 'new',
        // FASE 25 — Ley 172-13: marca de consentimiento individual.
        'consent_granted_at':
            _consent ? DateTime.now().toUtc().toIso8601String() : null,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DokkoTokens.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DokkoTokens.radiusLg)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(DokkoTokens.space24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nuevo Lead', style: TextStyle(color: DokkoTokens.text, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: DokkoTokens.space16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      onSaved: (v) => _firstName = v!,
                    ),
                  ),
                  const SizedBox(width: DokkoTokens.space16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Apellido'),
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      onSaved: (v) => _lastName = v!,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DokkoTokens.space16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Teléfono'),
                onSaved: (v) => _phone = v!,
              ),
              const SizedBox(height: DokkoTokens.space16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Correo Electrónico'),
                onSaved: (v) => _email = v!,
              ),
              const SizedBox(height: DokkoTokens.space16),
              Row(
                children: [
                  Checkbox(
                    value: _consent,
                    onChanged: (v) => setState(() => _consent = v ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      'El lead autoriza el tratamiento de sus datos '
                      'personales conforme a la Ley 172-13.',
                      style: TextStyle(color: DokkoTokens.text2, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DokkoTokens.space24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar', style: TextStyle(color: DokkoTokens.text2)),
                  ),
                  const SizedBox(width: DokkoTokens.space8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: DokkoTokens.accentDefault, foregroundColor: Colors.white),
                    child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white)) : const Text('Crear Lead'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
