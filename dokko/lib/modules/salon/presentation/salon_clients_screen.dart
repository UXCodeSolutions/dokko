import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/messaging/wa_deep_link.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_empty_state.dart';
import '../data/models/salon_models.dart';
import '../data/salon_api.dart';

final salonClientsProvider = FutureProvider<List<SalonClient>>((ref) async {
  return ref.read(salonApiProvider).getClients();
});

class SalonClientsScreen extends ConsumerStatefulWidget {
  const SalonClientsScreen({super.key});

  @override
  ConsumerState<SalonClientsScreen> createState() => _SalonClientsScreenState();
}

class _SalonClientsScreenState extends ConsumerState<SalonClientsScreen> {
  String _query = '';
  int _segment = 0; // 0 Todas, 1 Sin visitas, 2 Con visitas

  List<SalonClient> _applyFilters(List<SalonClient> all) {
    final q = _query.trim().toLowerCase();
    final list = _segment == 0
        ? all
        : all.where((c) =>
            (_segment == 1 && c.totalVisits == 0) ||
            (_segment == 2 && c.totalVisits > 0));
    if (q.isEmpty) return List.of(list);
    return list.where((c) {
      final name = '${c.firstName} ${c.lastName}'.toLowerCase();
      final phone = (c.phone ?? '').toLowerCase();
      final email = (c.email ?? '').toLowerCase();
      final notes = (c.notes ?? '').toLowerCase();
      return name.contains(q) ||
          phone.contains(q) ||
          email.contains(q) ||
          notes.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(salonClientsProvider);

    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      appBar: AppBar(
        title: const Text('Clientes', style: TextStyle(color: DokkoTokens.text)),
        backgroundColor: DokkoTokens.surface,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddClientModal(context, ref),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Nuevo Cliente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DokkoTokens.accentDefault,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: clientsAsync.when(
        data: (clients) {
          final filtered = _applyFilters(clients);
          return Column(
            children: [
              if (clients.isNotEmpty)
                _FilterBar(
                  query: _query,
                  segment: _segment,
                  total: clients.length,
                  sinVisitas: clients
                      .where((c) => c.totalVisits == 0)
                      .length,
                  conVisitas:
                      clients.where((c) => c.totalVisits > 0).length,
                  onQueryChanged: (v) => setState(() => _query = v),
                  onSegmentChanged: (v) => setState(() => _segment = v),
                ),
              Expanded(
                child: filtered.isEmpty
                    ? DokkoEmptyState(
                        icon: Icons.search_off_rounded,
                        message: clients.isEmpty
                            ? 'No hay clientes registrados.\nAgrega tu primer cliente.'
                            : 'Ningún cliente coincide con el filtro.',
                      )
                    : GridView.builder(
                        key: const ValueKey('salon-clients-list'),
                        padding: const EdgeInsets.fromLTRB(
                            DokkoTokens.space16,
                            4,
                            DokkoTokens.space16,
                            DokkoTokens.space16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 340,
                          mainAxisSpacing: DokkoTokens.space16,
                          crossAxisSpacing: DokkoTokens.space16,
                          childAspectRatio: 1.4,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final client = filtered[index];
                          return _ClientCard(
                            client: client,
                            onExport: () =>
                                _exportClient(context, ref, client),
                            onDelete: () =>
                                _deleteClient(context, ref, client),
                            onWhatsApp: () =>
                                _launchWaForClient(context, ref, client),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => GridView.builder(
          padding: const EdgeInsets.all(DokkoTokens.space16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 340,
            mainAxisSpacing: DokkoTokens.space16,
            crossAxisSpacing: DokkoTokens.space16,
            childAspectRatio: 1.4,
          ),
          itemCount: 6,
          itemBuilder: (context, index) => Container(
            decoration: BoxDecoration(
              color: DokkoTokens.surface2,
              borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
            ),
          ),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showAddClientModal(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const _AddClientModal(),
    ).then((val) {
      if (val == true) ref.invalidate(salonClientsProvider);
    });
  }

  // ── FASE 28 — Deep-link a WhatsApp desde la tarjeta de cliente ──
  Future<void> _launchWaForClient(
      BuildContext context, WidgetRef ref, SalonClient client) async {
    final digits = normalizePhoneToDigits(client.phone);
    if (digits == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este cliente no tiene un teléfono válido.'),
        ),
      );
      return;
    }
    final body = 'Hola ${client.firstName}! 👋 Te saludamos desde tu salón.';
    try {
      await openWaDeepLink(ref, phoneDigits: digits, body: body);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir WhatsApp: $e')),
      );
    }
  }

  // ── FASE 25 — Ley 172-13: portabilidad y supresión de datos de un cliente ──
  Future<void> _exportClient(
      BuildContext context, WidgetRef ref, SalonClient client) async {
    try {
      final data = await ref.read(salonApiProvider).exportClientData(client.id);
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (_) => _ClientExportDialog(data: data),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    }
  }

  Future<void> _deleteClient(
      BuildContext context, WidgetRef ref, SalonClient client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DokkoTokens.surface,
        title: const Text('Eliminar cliente',
            style: TextStyle(color: DokkoTokens.text, fontSize: 18)),
        content: const Text(
          'Se eliminarán definitivamente los datos personales de esta '
          'clienta/cliente conforme al derecho de supresión de la Ley 172-13. '
          'Las citas asociadas se conservarán sin vincularle. No se puede deshacer.',
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
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(salonApiProvider).deleteClient(client.id);
      ref.invalidate(salonClientsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente eliminado.')),
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
}

class _FilterBar extends StatelessWidget {
  final String query;
  final int segment;
  final int total;
  final int sinVisitas;
  final int conVisitas;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<int> onSegmentChanged;

  const _FilterBar({
    required this.query,
    required this.segment,
    required this.total,
    required this.sinVisitas,
    required this.conVisitas,
    required this.onQueryChanged,
    required this.onSegmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        DokkoTokens.space16,
        DokkoTokens.space12,
        DokkoTokens.space16,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, teléfono, email…',
              hintStyle: const TextStyle(color: DokkoTokens.text3, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 18, color: DokkoTokens.text3),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 16, color: DokkoTokens.text3),
                      onPressed: () => onQueryChanged(''),
                    ),
              filled: true,
              fillColor: DokkoTokens.surface,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: DokkoTokens.space8),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(DokkoTokens.radiusMd),
                borderSide: const BorderSide(color: DokkoTokens.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(DokkoTokens.radiusMd),
                borderSide: const BorderSide(color: DokkoTokens.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(DokkoTokens.radiusMd),
                borderSide: const BorderSide(
                    color: DokkoTokens.accentDefault, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: DokkoTokens.space12),
          Row(
            children: [
              _SegmentChip(
                label: 'Todas ($total)',
                selected: segment == 0,
                onTap: () => onSegmentChanged(0),
              ),
              const SizedBox(width: DokkoTokens.space8),
              _SegmentChip(
                label: 'Con visitas ($conVisitas)',
                selected: segment == 2,
                onTap: () => onSegmentChanged(2),
              ),
              const SizedBox(width: DokkoTokens.space8),
              _SegmentChip(
                label: 'Sin visitas ($sinVisitas)',
                selected: segment == 1,
                onTap: () => onSegmentChanged(1),
              ),
            ],
          ),
          const SizedBox(height: DokkoTokens.space8),
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? DokkoTokens.accentDefault : DokkoTokens.text2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: DokkoTokens.space12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? DokkoTokens.accentDefault.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? DokkoTokens.accentDefault.withValues(alpha: 0.4)
                : DokkoTokens.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ClientCard extends StatefulWidget {
  final SalonClient client;
  final Future<void> Function()? onExport;
  final Future<void> Function()? onDelete;
  final Future<void> Function()? onWhatsApp;

  const _ClientCard({
    required this.client,
    this.onExport,
    this.onDelete,
    this.onWhatsApp,
  });

  @override
  State<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<_ClientCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final hasNotes = client.notes != null && client.notes!.isNotEmpty;
    final hasConsent = client.consentGrantedAt != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.all(DokkoTokens.space16),
        decoration: BoxDecoration(
          color: DokkoTokens.bg,
          border: Border.all(
            color: _hovered
                ? DokkoTokens.accentDefault.withValues(alpha: 0.55)
                : DokkoTokens.line,
            width: _hovered ? 1.2 : 1,
          ),
          borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: DokkoTokens.accentDefault.withValues(alpha: 0.14),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      DokkoTokens.accentDefault.withValues(alpha: 0.15),
                  foregroundColor: DokkoTokens.accentDefault,
                  child: Text(
                    client.firstName[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: DokkoTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${client.firstName} ${client.lastName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: DokkoTokens.text,
                            fontSize: 14),
                      ),
                      if (client.phone != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          client.phone!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: DokkoTokens.text2, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            hasConsent
                                ? Icons.check_circle_outline_rounded
                                : Icons.privacy_tip_outlined,
                            size: 12,
                            color: hasConsent
                                ? DokkoTokens.accentDefault
                                : DokkoTokens.text3,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasConsent
                                ? 'Consentimiento ✓'
                                : 'Sin consentimiento',
                            style: TextStyle(
                              color: hasConsent
                                  ? DokkoTokens.text2
                                  : DokkoTokens.text3,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _hovered
                          ? Column(
                              key: const ValueKey('client-actions'),
                              children: [
                                IconButton(
                                  tooltip: 'Enviar por WhatsApp',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                      Icons.chat_bubble_rounded,
                                      color: DokkoTokens.accentDefault,
                                      size: 17),
                                  onPressed: widget.onWhatsApp,
                                ),
                                IconButton(
                                  tooltip: 'Exportar datos (Ley 172-13)',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                      Icons.file_download_outlined,
                                      color: DokkoTokens.text2,
                                      size: 17),
                                  onPressed: widget.onExport,
                                ),
                                IconButton(
                                  tooltip: 'Eliminar (Ley 172-13)',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: DokkoTokens.red,
                                      size: 17),
                                  onPressed: widget.onDelete,
                                ),
                              ],
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('client-actions-none')),
                    ),
                    const SizedBox(height: 2),
                    _VisitsBadge(totalVisits: client.totalVisits),
                  ],
                ),
              ],
            ),
            if (hasNotes) ...[
              const SizedBox(height: DokkoTokens.space8),
              Text(
                client.notes!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: DokkoTokens.text3, fontSize: 11.5),
              ),
            ],
            const Spacer(),
            if (client.lastVisitDate != null)
              Text(
                'Última visita: ${client.lastVisitDate!.day}/${client.lastVisitDate!.month}/${client.lastVisitDate!.year}',
                style: const TextStyle(color: DokkoTokens.text3, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

class _VisitsBadge extends StatelessWidget {
  final int totalVisits;

  const _VisitsBadge({required this.totalVisits});

  @override
  Widget build(BuildContext context) {
    final hasVisits = totalVisits > 0;
    final color = hasVisits
        ? DokkoTokens.accentDefault
        : DokkoTokens.text3;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DokkoTokens.space8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        hasVisits ? '$totalVisits visitas' : 'Sin visitas',
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ClientExportDialog extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ClientExportDialog({required this.data});

  @override
  Widget build(BuildContext context) {
    final personal = data['personal_data'] as Map<String, dynamic>? ?? {};
    final consent = data['consent_granted_at'];
    final appointments = (data['appointments'] as List?)?.length ?? 0;
    final sales = (data['sales'] as List?)?.length ?? 0;
    return AlertDialog(
      backgroundColor: DokkoTokens.surface,
      title: const Text('Exportar Datos (Ley 172-13)',
          style: TextStyle(color: DokkoTokens.text, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${personal['first_name']} ${personal['last_name']}',
                style: const TextStyle(
                    color: DokkoTokens.text, fontSize: 15)),
            const SizedBox(height: DokkoTokens.space8),
            Text(consent != null
                ? 'Consentimiento registrado.'
                : 'Sin consentimiento registrado.',
                style: const TextStyle(color: DokkoTokens.text2, fontSize: 13)),
            const SizedBox(height: DokkoTokens.space8),
            Text('Citas: $appointments  |  Ventas: $sales',
                style: const TextStyle(color: DokkoTokens.text2, fontSize: 13)),
            const SizedBox(height: DokkoTokens.space8),
            Text((data['law'] ?? 'Ley 172-13').toString(),
                style: const TextStyle(color: DokkoTokens.text3, fontSize: 12)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar',
              style: TextStyle(color: DokkoTokens.text2)),
        ),
      ],
    );
  }
}

class _AddClientModal extends ConsumerStatefulWidget {
  const _AddClientModal();

  @override
  ConsumerState<_AddClientModal> createState() => _AddClientModalState();
}

class _AddClientModalState extends ConsumerState<_AddClientModal> {
  final _formKey = GlobalKey<FormState>();
  String _firstName = '';
  String _lastName = '';
  String _phone = '';
  String _notes = '';
  bool _isLoading = false;
  bool _consent = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);
    try {
      await ref.read(salonApiProvider).createClient({
        'first_name': _firstName,
        'last_name': _lastName,
        'phone': _phone,
        'notes': _notes,
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
              const Text('Nuevo Cliente', style: TextStyle(color: DokkoTokens.text, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: DokkoTokens.space16),
              Row(
                children: [
                  Expanded(child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    onSaved: (v) => _firstName = v!,
                  )),
                  const SizedBox(width: DokkoTokens.space16),
                  Expanded(child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Apellido'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    onSaved: (v) => _lastName = v!,
                  )),
                ],
              ),
              const SizedBox(height: DokkoTokens.space16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Teléfono'),
                onSaved: (v) => _phone = v ?? '',
              ),
              const SizedBox(height: DokkoTokens.space16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Notas / Preferencias'),
                maxLines: 3,
                onSaved: (v) => _notes = v ?? '',
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
                      'La clienta/cliente autoriza el tratamiento de sus datos '
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
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  const SizedBox(width: DokkoTokens.space8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: DokkoTokens.accentDefault, foregroundColor: Colors.white),
                    child: _isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white))
                        : const Text('Crear Cliente'),
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