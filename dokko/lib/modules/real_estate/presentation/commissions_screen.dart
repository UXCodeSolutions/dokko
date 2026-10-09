import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_card.dart';
import '../data/models/realestate_models.dart';
import '../data/realestate_api.dart';
import 'properties_screen.dart'; // To fetch sold properties

final agentsProvider = FutureProvider<List<RealEstateAgent>>((ref) async {
  final api = ref.read(realEstateApiProvider);
  return api.getAgents();
});

final commissionsProvider = FutureProvider<List<RealEstateCommission>>((ref) async {
  final api = ref.read(realEstateApiProvider);
  return api.getCommissions();
});

class CommissionsScreen extends ConsumerWidget {
  const CommissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      appBar: AppBar(
        title: const Text('Comisiones y Agentes', style: TextStyle(color: DokkoTokens.text)),
        backgroundColor: DokkoTokens.surface,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildAgentsSection(context, ref)),
                Container(width: 1, color: DokkoTokens.surface2),
                Expanded(child: _buildCommissionsSection(context, ref)),
              ],
            );
          } else {
            return DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: DokkoTokens.accentDefault,
                    unselectedLabelColor: DokkoTokens.text2,
                    indicatorColor: DokkoTokens.accentDefault,
                    tabs: [
                      Tab(text: 'Agentes'),
                      Tab(text: 'Comisiones'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildAgentsSection(context, ref),
                        _buildCommissionsSection(context, ref),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildAgentsSection(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(agentsProvider);
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(DokkoTokens.space16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Agentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DokkoTokens.text)),
              ElevatedButton.icon(
                onPressed: () => _showAddAgentModal(context, ref),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Nuevo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DokkoTokens.surface2,
                  foregroundColor: DokkoTokens.text,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: agentsAsync.when(
            data: (agents) {
              if (agents.isEmpty) {
                return const Center(child: Text('No hay agentes registrados', style: TextStyle(color: DokkoTokens.text3)));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: DokkoTokens.space16),
                itemCount: agents.length,
                itemBuilder: (context, index) {
                  final agent = agents[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: DokkoTokens.space8),
                    child: DokkoCard(
                      padding: const EdgeInsets.all(DokkoTokens.space16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: DokkoTokens.accentDefault.withValues(alpha: 0.1),
                            foregroundColor: DokkoTokens.accentDefault,
                            child: Text(agent.firstName[0].toUpperCase()),
                          ),
                          const SizedBox(width: DokkoTokens.space16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${agent.firstName} ${agent.lastName}', style: const TextStyle(fontWeight: FontWeight.bold, color: DokkoTokens.text)),
                                if (agent.licenseNumber != null) Text('Lic: ${agent.licenseNumber}', style: const TextStyle(fontSize: 12, color: DokkoTokens.text2)),
                              ],
                            ),
                          ),
                          Text('${agent.commissionRate}%', style: const TextStyle(color: DokkoTokens.accentDefault, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildCommissionsSection(BuildContext context, WidgetRef ref) {
    final commissionsAsync = ref.watch(commissionsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(DokkoTokens.space16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Comisiones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DokkoTokens.text)),
              ElevatedButton.icon(
                onPressed: () => _showAddCommissionModal(context, ref),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Registrar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DokkoTokens.accentDefault,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: commissionsAsync.when(
            data: (commissions) {
              if (commissions.isEmpty) {
                return const Center(child: Text('No hay comisiones registradas', style: TextStyle(color: DokkoTokens.text3)));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: DokkoTokens.space16),
                itemCount: commissions.length,
                itemBuilder: (context, index) {
                  final commission = commissions[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: DokkoTokens.space8),
                    child: DokkoCard(
                      padding: const EdgeInsets.all(DokkoTokens.space16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                commission.property?.title ?? 'Propiedad Desconocida',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: DokkoTokens.text),
                              ),
                              _buildStatusBadge(commission.status),
                            ],
                          ),
                          const SizedBox(height: DokkoTokens.space8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                commission.agent != null 
                                  ? 'Agente: ${commission.agent!.firstName} ${commission.agent!.lastName}'
                                  : 'Sin Agente',
                                style: const TextStyle(color: DokkoTokens.text2, fontSize: 13),
                              ),
                              Text(
                                '\$${commission.amount.toStringAsFixed(2)}',
                                style: const TextStyle(color: DokkoTokens.accentDefault, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          if (commission.status == 'pending') ...[
                            const SizedBox(height: DokkoTokens.space8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () async {
                                  try {
                                    await ref.read(realEstateApiProvider).updateCommission(commission.id, {'status': 'paid'});
                                    ref.invalidate(commissionsProvider);
                                  } catch (e) {
                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                  }
                                },
                                child: const Text('Marcar como Pagada'),
                              ),
                            )
                          ]
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    
    switch (status) {
      case 'pending':
        bg = Colors.orange.withValues(alpha: 0.2);
        fg = Colors.orange;
        label = 'Pendiente';
        break;
      case 'paid':
        bg = Colors.green.withValues(alpha: 0.2);
        fg = Colors.green;
        label = 'Pagada';
        break;
      case 'cancelled':
        bg = Colors.red.withValues(alpha: 0.2);
        fg = Colors.red;
        label = 'Cancelada';
        break;
      default:
        bg = DokkoTokens.surface2;
        fg = DokkoTokens.text2;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(DokkoTokens.radiusSm)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showAddAgentModal(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _AddAgentModal(),
    ).then((val) {
      if (val == true) ref.invalidate(agentsProvider);
    });
  }

  void _showAddCommissionModal(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _AddCommissionModal(),
    ).then((val) {
      if (val == true) ref.invalidate(commissionsProvider);
    });
  }
}

class _AddAgentModal extends ConsumerStatefulWidget {
  const _AddAgentModal();
  @override
  ConsumerState<_AddAgentModal> createState() => _AddAgentModalState();
}

class _AddAgentModalState extends ConsumerState<_AddAgentModal> {
  final _formKey = GlobalKey<FormState>();
  String _firstName = '';
  String _lastName = '';
  // ignore: prefer_final_fields
  String _phone = '';
  // ignore: prefer_final_fields
  String _email = '';
  String _license = '';
  double _commissionRate = 0.0;
  bool _isLoading = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);
    try {
      await ref.read(realEstateApiProvider).createAgent({
        'first_name': _firstName,
        'last_name': _lastName,
        'phone': _phone,
        'email': _email,
        'license_number': _license,
        'commission_rate': _commissionRate,
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
              const Text('Nuevo Agente', style: TextStyle(color: DokkoTokens.text, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: DokkoTokens.space16),
              Row(
                children: [
                  Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'Nombre'), onSaved: (v) => _firstName = v!)),
                  const SizedBox(width: DokkoTokens.space16),
                  Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'Apellido'), onSaved: (v) => _lastName = v!)),
                ],
              ),
              const SizedBox(height: DokkoTokens.space16),
              TextFormField(decoration: const InputDecoration(labelText: 'Licencia'), onSaved: (v) => _license = v ?? ''),
              const SizedBox(height: DokkoTokens.space16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Porcentaje de Comisión Base (%)'),
                keyboardType: TextInputType.number,
                onSaved: (v) => _commissionRate = double.tryParse(v ?? '0') ?? 0,
              ),
              const SizedBox(height: DokkoTokens.space24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: DokkoTokens.accentDefault, foregroundColor: Colors.white),
                    child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white)) : const Text('Crear'),
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

class _AddCommissionModal extends ConsumerStatefulWidget {
  const _AddCommissionModal();
  @override
  ConsumerState<_AddCommissionModal> createState() => _AddCommissionModalState();
}

class _AddCommissionModalState extends ConsumerState<_AddCommissionModal> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedAgentId;
  String? _selectedPropertyId;
  double _amount = 0.0;
  bool _isLoading = false;

  void _submit() async {
    if (!_formKey.currentState!.validate() || _selectedAgentId == null || _selectedPropertyId == null) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);
    try {
      await ref.read(realEstateApiProvider).createCommission({
        'agent_id': _selectedAgentId,
        'property_id': _selectedPropertyId,
        'amount': _amount,
        'status': 'pending',
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
    final agentsAsync = ref.watch(agentsProvider);
    final propertiesAsync = ref.watch(propertiesProvider);

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
              const Text('Registrar Comisión', style: TextStyle(color: DokkoTokens.text, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: DokkoTokens.space16),
              agentsAsync.when(
                data: (agents) => DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Agente'),
                  items: agents.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.firstName} ${a.lastName}'))).toList(),
                  onChanged: (v) => _selectedAgentId = v,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => const Text('Error al cargar agentes'),
              ),
              const SizedBox(height: DokkoTokens.space16),
              propertiesAsync.when(
                data: (props) => DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Propiedad (Vendida/Cerrada)'),
                  items: props.where((p) => p.status == 'sold').map((p) => DropdownMenuItem(value: p.id, child: Text(p.title))).toList(),
                  onChanged: (v) => _selectedPropertyId = v,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => const Text('Error al cargar propiedades'),
              ),
              const SizedBox(height: DokkoTokens.space16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Monto a Pagar (\$)'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
                onSaved: (v) => _amount = double.tryParse(v ?? '0') ?? 0,
              ),
              const SizedBox(height: DokkoTokens.space24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: DokkoTokens.accentDefault, foregroundColor: Colors.white),
                    child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white)) : const Text('Registrar'),
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
