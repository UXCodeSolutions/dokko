import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_card.dart';
import '../../../core/widgets/dokko_empty_state.dart';
import '../data/gym_api.dart';

class GymMembershipsScreen extends ConsumerStatefulWidget {
  const GymMembershipsScreen({super.key});

  @override
  ConsumerState<GymMembershipsScreen> createState() =>
      _GymMembershipsScreenState();
}

class _GymMembershipsScreenState extends ConsumerState<GymMembershipsScreen> {
  List<dynamic> _plans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(gymApiProvider);
      final plans = await api.getMembershipPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _openModal({Map<String, dynamic>? plan}) {
    showDialog(
      context: context,
      builder: (_) => _PlanModal(
        plan: plan,
        onSaved: _fetchPlans,
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DokkoTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
          side: const BorderSide(color: DokkoTokens.line),
        ),
        title: const Text('Eliminar Plan',
            style: TextStyle(color: DokkoTokens.text)),
        content: Text(
          '¿Eliminar "${plan['name']}"? Esta acción no se puede deshacer.',
          style: const TextStyle(color: DokkoTokens.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar',
                style: TextStyle(color: DokkoTokens.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final api = ref.read(gymApiProvider);
        await api.deletePlan(plan['id'].toString());
        await _fetchPlans();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Planes de Membresía',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: DokkoTokens.text,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Define los planes que ofrecerás a tus miembros.',
                      style: TextStyle(fontSize: 13, color: DokkoTokens.text2),
                    ),
                  ],
                ),
                DokkoButton(
                  label: 'Nuevo Plan',
                  onPressed: () => _openModal(),
                ),
              ],
            ),
            const SizedBox(height: DokkoTokens.space24),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _plans.isEmpty
                      ? const DokkoEmptyState(
                          icon: Icons.credit_card_off_rounded,
                          message:
                              'No hay planes creados.\nPresiona "Nuevo Plan" para empezar.',
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 320,
                            mainAxisExtent: 180,
                            crossAxisSpacing: DokkoTokens.space16,
                            mainAxisSpacing: DokkoTokens.space16,
                          ),
                          itemCount: _plans.length,
                          itemBuilder: (ctx, i) => _PlanCard(
                            plan: _plans[i],
                            onEdit: () => _openModal(plan: _plans[i]),
                            onDelete: () => _confirmDelete(_plans[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan Card
// ─────────────────────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final dynamic plan;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlanCard({
    required this.plan,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = plan['is_active'] as bool? ?? true;
    final days = plan['duration_days'] as int? ?? 0;
    final price = plan['price'];

    String durationLabel;
    if (days == 30 || days == 31) {
      durationLabel = '1 mes';
    } else if (days == 90) {
      durationLabel = '3 meses';
    } else if (days == 180) {
      durationLabel = '6 meses';
    } else if (days == 365) {
      durationLabel = '1 año';
    } else {
      durationLabel = '$days días';
    }

    return DokkoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Active badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isActive ? DokkoTokens.green : DokkoTokens.text2)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  isActive ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive ? DokkoTokens.green : DokkoTokens.text2,
                  ),
                ),
              ),
              // Actions
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded,
                        size: 16, color: DokkoTokens.text2),
                    onPressed: onEdit,
                    tooltip: 'Editar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: DokkoTokens.red),
                    onPressed: onDelete,
                    tooltip: 'Eliminar',
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Text(
            plan['name'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: DokkoTokens.text,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: DokkoTokens.space4),
          Text(
            durationLabel,
            style: const TextStyle(fontSize: 13, color: DokkoTokens.text2),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$$price',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: DokkoTokens.accentDefault,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  ' / período',
                  style: TextStyle(fontSize: 12, color: DokkoTokens.text2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan Modal (create / edit)
// ─────────────────────────────────────────────────────────────────────────────
class _PlanModal extends ConsumerStatefulWidget {
  final Map<String, dynamic>? plan;
  final VoidCallback onSaved;

  const _PlanModal({this.plan, required this.onSaved});

  @override
  ConsumerState<_PlanModal> createState() => _PlanModalState();
}

class _PlanModalState extends ConsumerState<_PlanModal> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  int _durationDays = 30;
  bool _isActive = true;
  bool _isLoading = false;

  // Preset options
  static const _presets = [
    {'label': '1 semana', 'days': 7},
    {'label': '1 mes', 'days': 30},
    {'label': '3 meses', 'days': 90},
    {'label': '6 meses', 'days': 180},
    {'label': '1 año', 'days': 365},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.plan != null) {
      _nameCtrl.text = widget.plan!['name'] ?? '';
      _priceCtrl.text = widget.plan!['price'].toString();
      _durationDays = widget.plan!['duration_days'] ?? 30;
      _isActive = widget.plan!['is_active'] ?? true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text);
    if (name.isEmpty || price == null) return;

    setState(() => _isLoading = true);
    try {
      final api = ref.read(gymApiProvider);
      final body = {
        'name': name,
        'price': price,
        'duration_days': _durationDays,
        'is_active': _isActive,
      };
      if (widget.plan == null) {
        await api.createPlan(body);
      } else {
        await api.updatePlan(widget.plan!['id'].toString(), body);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.plan != null;

    return Dialog(
      backgroundColor: DokkoTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
        side: const BorderSide(color: DokkoTokens.line),
      ),
      child: SizedBox(
        width: 440,
        child: Padding(
          padding: const EdgeInsets.all(DokkoTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Editar Plan' : 'Nuevo Plan',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: DokkoTokens.text,
                ),
              ),
              const SizedBox(height: DokkoTokens.space20),

              // Name field
              _ModalField(
                label: 'Nombre del Plan',
                child: TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: DokkoTokens.text),
                  decoration: _inputDecoration('Ej: Plan Mensual Estándar'),
                ),
              ),
              const SizedBox(height: DokkoTokens.space16),

              // Price field
              _ModalField(
                label: 'Precio',
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: DokkoTokens.text),
                  decoration: _inputDecoration('0.00').copyWith(
                    prefixText: '\$ ',
                    prefixStyle:
                        const TextStyle(color: DokkoTokens.text2),
                  ),
                ),
              ),
              const SizedBox(height: DokkoTokens.space16),

              // Duration presets
              _ModalField(
                label: 'Duración',
                child: Wrap(
                  spacing: DokkoTokens.space8,
                  runSpacing: DokkoTokens.space8,
                  children: _presets.map((preset) {
                    final days = preset['days'] as int;
                    final selected = _durationDays == days;
                    return GestureDetector(
                      onTap: () => setState(() => _durationDays = days),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: DokkoTokens.space12,
                          vertical: DokkoTokens.space8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? DokkoTokens.accentDefault.withValues(alpha: 0.15)
                              : DokkoTokens.surface2,
                          borderRadius:
                              BorderRadius.circular(DokkoTokens.radiusMd),
                          border: Border.all(
                            color: selected
                                ? DokkoTokens.accentDefault
                                : DokkoTokens.line,
                          ),
                        ),
                        child: Text(
                          preset['label'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w500
                                : FontWeight.normal,
                            color: selected
                                ? DokkoTokens.accentDefault
                                : DokkoTokens.text,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: DokkoTokens.space16),

              // Active toggle
              Row(
                children: [
                  Switch(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    activeThumbColor: DokkoTokens.green,
                  ),
                  const SizedBox(width: DokkoTokens.space8),
                  Text(
                    _isActive ? 'Plan activo' : 'Plan inactivo',
                    style: const TextStyle(
                        fontSize: 14, color: DokkoTokens.text),
                  ),
                ],
              ),
              const SizedBox(height: DokkoTokens.space24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DokkoButton(
                    label: 'Cancelar',
                    variant: DokkoButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: DokkoTokens.space12),
                  DokkoButton(
                    label: isEditing ? 'Guardar' : 'Crear Plan',
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: DokkoTokens.text3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DokkoTokens.space12,
          vertical: DokkoTokens.space12,
        ),
        filled: true,
        fillColor: DokkoTokens.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
          borderSide: const BorderSide(color: DokkoTokens.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
          borderSide: const BorderSide(color: DokkoTokens.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
          borderSide: const BorderSide(color: DokkoTokens.accentDefault),
        ),
      );
}

// Helper label widget
class _ModalField extends StatelessWidget {
  final String label;
  final Widget child;
  const _ModalField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: DokkoTokens.text2)),
        const SizedBox(height: DokkoTokens.space4),
        child,
      ],
    );
  }
}
