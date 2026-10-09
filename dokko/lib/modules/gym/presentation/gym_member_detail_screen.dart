import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_card.dart';
import '../data/gym_api.dart';
import '../providers/gym_provider.dart';

class GymMemberDetailScreen extends ConsumerStatefulWidget {
  final String memberId;
  const GymMemberDetailScreen({super.key, required this.memberId});

  @override
  ConsumerState<GymMemberDetailScreen> createState() => _GymMemberDetailScreenState();
}

class _GymMemberDetailScreenState extends ConsumerState<GymMemberDetailScreen> {
  Map<String, dynamic>? _member;
  List<dynamic> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final api = ref.read(gymApiProvider);
      final member = await api.getMember(widget.memberId);
      final payments = await api.getMemberPayments(widget.memberId);
      if (!mounted) return;
      setState(() {
        _member = member;
        _payments = payments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':    return DokkoTokens.green;
      case 'expired':   return DokkoTokens.amber;
      case 'suspended': return DokkoTokens.red;
      default:          return DokkoTokens.text2;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':    return 'Activo';
      case 'expired':   return 'Vencido';
      case 'suspended': return 'Suspendido';
      case 'cancelled': return 'Cancelado';
      default:          return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: DokkoTokens.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_member == null) {
      return Scaffold(
        backgroundColor: DokkoTokens.bg,
        body: Center(
          child: Text('Miembro no encontrado.',
              style: TextStyle(color: DokkoTokens.text2)),
        ),
      );
    }

    final m = _member!;
    final status = m['status'] ?? 'active';
    final expires = m['membership_expires_at'];

    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      body: Padding(
        padding: const EdgeInsets.all(DokkoTokens.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: DokkoTokens.text),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: DokkoTokens.space8),
                Expanded(
                  child: Text(
                    '${m['first_name']} ${m['last_name']}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: DokkoTokens.text,
                    ),
                  ),
                ),
                DokkoButton(
                  label: 'Editar',
                  variant: DokkoButtonVariant.secondary,
                  onPressed: () async {
                    await context.push('/gym/members/${widget.memberId}/edit',
                        extra: _member);
                    _fetchData();
                  },
                ),
                const SizedBox(width: DokkoTokens.space12),
                DokkoButton(
                  label: 'Registrar Pago',
                  onPressed: () => _showPaymentModal(context),
                ),
                const SizedBox(width: DokkoTokens.space12),
                DokkoButton(
                  label: 'Exportar datos',
                  variant: DokkoButtonVariant.secondary,
                  onPressed: () => _exportData(context),
                ),
                const SizedBox(width: DokkoTokens.space12),
                DokkoButton(
                  label: 'Eliminar',
                  variant: DokkoButtonVariant.danger,
                  onPressed: () => _confirmErasure(context),
                ),
              ],
            ),
            const SizedBox(height: DokkoTokens.space24),
            // Info + Payments
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  SizedBox(
                    width: 280,
                    child: DokkoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar
                          Center(
                            child: CircleAvatar(
                              radius: 36,
                              backgroundColor: DokkoTokens.surface2,
                              child: Text(
                                '${m['first_name'][0]}${m['last_name'][0]}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: DokkoTokens.text,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: DokkoTokens.space16),
                          // Status badge
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DokkoTokens.space12,
                                vertical: DokkoTokens.space4,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: _statusColor(status).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                _statusLabel(status),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _statusColor(status),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: DokkoTokens.space24),
                          _infoRow(Icons.email_rounded, m['email'] ?? '—'),
                          const SizedBox(height: DokkoTokens.space12),
                          _infoRow(Icons.phone_rounded, m['phone'] ?? '—'),
                          const SizedBox(height: DokkoTokens.space12),
                          _infoRow(Icons.badge_rounded, m['id_number'] ?? '—'),
                          if (expires != null) ...[
                            const SizedBox(height: DokkoTokens.space12),
                            _infoRow(
                              Icons.calendar_today_rounded,
                              'Vence: $expires',
                            ),
                          ],
                          if ((m['notes'] ?? '').isNotEmpty) ...[
                            const SizedBox(height: DokkoTokens.space16),
                            const Divider(color: DokkoTokens.line),
                            const SizedBox(height: DokkoTokens.space12),
                            Text(
                              m['notes'],
                              style: const TextStyle(
                                fontSize: 13,
                                color: DokkoTokens.text2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: DokkoTokens.space16),
                  // Payment History
                  Expanded(
                    child: DokkoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Historial de Pagos',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: DokkoTokens.text,
                            ),
                          ),
                          const SizedBox(height: DokkoTokens.space16),
                          if (_payments.isEmpty)
                            const Center(
                              child: Text('Sin pagos registrados.',
                                  style: TextStyle(color: DokkoTokens.text2)),
                            )
                          else
                            ..._payments.map((p) => _PaymentRow(payment: p)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: DokkoTokens.text2),
        const SizedBox(width: DokkoTokens.space8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: DokkoTokens.text),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showPaymentModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _PaymentModal(
        memberId: widget.memberId,
        onSuccess: _fetchData,
      ),
    );
  }

  // ── FASE 25 — Ley 172-13 ────────────────────────────────────────────────
  Future<void> _exportData(BuildContext context) async {
    try {
      final api = ref.read(gymApiProvider);
      final data = await api.exportMemberData(widget.memberId);
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (_) => _ExportDialog(data: data),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    }
  }

  Future<void> _confirmErasure(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DokkoTokens.surface,
        title: const Text('Eliminar datos personales',
            style: TextStyle(color: DokkoTokens.text, fontSize: 18)),
        content: const Text(
          'Esta acción eliminará definitivamente los datos de este miembro '
          'conforme al derecho de supresión de la Ley 172-13. '
          'Las ventas asociadas se conservarán sin vincularle. No se puede deshacer.',
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
      final api = ref.read(gymApiProvider);
      await api.deleteMember(widget.memberId);
      ref.invalidate(gymMembersProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos del miembro eliminados.')),
      );
      context.pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Export dialog (Ley 172-13)
// ─────────────────────────────────────────────────────────────────────────────
class _ExportDialog extends StatelessWidget {
  final dynamic data;
  const _ExportDialog({required this.data});

  @override
  Widget build(BuildContext context) {
    final String pretty = const JsonEncoder.withIndent('  ').convert(data);
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
                    borderRadius:
                        BorderRadius.circular(DokkoTokens.radiusMd),
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

// ─────────────────────────────────────────────────────────────────────────────
// Payment row widget
// ─────────────────────────────────────────────────────────────────────────────
class _PaymentRow extends StatelessWidget {
  final dynamic payment;
  const _PaymentRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    final paidAt = DateTime.tryParse(payment['paid_at'] ?? '');
    final date = paidAt != null
        ? '${paidAt.day}/${paidAt.month}/${paidAt.year}'
        : '—';
    final amount = payment['amount'] ?? 0;
    final from = payment['valid_from'] ?? '—';
    final until = payment['valid_until'] ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: DokkoTokens.space12),
      padding: const EdgeInsets.all(DokkoTokens.space12),
      decoration: BoxDecoration(
        color: DokkoTokens.surface2,
        borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_rounded,
              size: 18, color: DokkoTokens.green),
          const SizedBox(width: DokkoTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membresía: $from → $until',
                  style: const TextStyle(
                      fontSize: 13, color: DokkoTokens.text),
                ),
                Text(
                  'Pagado el $date',
                  style: const TextStyle(
                      fontSize: 12, color: DokkoTokens.text2),
                ),
              ],
            ),
          ),
          Text(
            '\$$amount',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: DokkoTokens.green,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment Modal
// ─────────────────────────────────────────────────────────────────────────────
class _PaymentModal extends ConsumerStatefulWidget {
  final String memberId;
  final VoidCallback onSuccess;
  const _PaymentModal({required this.memberId, required this.onSuccess});

  @override
  ConsumerState<_PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends ConsumerState<_PaymentModal> {
  final _amountCtrl = TextEditingController();
  DateTime _validFrom = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  String _paymentMethod = 'cash';
  String? _selectedPlanId;
  List<dynamic> _plans = [];
  bool _isLoading = false;
  bool _loadingPlans = true;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPlans() async {
    try {
      final api = ref.read(gymApiProvider);
      final plans = await api.getMembershipPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loadingPlans = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPlans = false);
    }
  }

  void _applyPlan(dynamic plan) {
    setState(() {
      _selectedPlanId = plan['id'];
      _amountCtrl.text = plan['price'].toString();
      _validFrom = DateTime.now();
      _validUntil = DateTime.now().add(Duration(days: plan['duration_days']));
    });
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null) return;

    setState(() => _isLoading = true);
    try {
      final api = ref.read(gymApiProvider);
      await api.registerPayment({
        'member_id': widget.memberId,
        'plan_id': _selectedPlanId,
        'amount': amount,
        'payment_method': _paymentMethod,
        'valid_from': _validFrom.toIso8601String().substring(0, 10),
        'valid_until': _validUntil.toIso8601String().substring(0, 10),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSuccess();
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
    return Dialog(
      backgroundColor: DokkoTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
        side: const BorderSide(color: DokkoTokens.line),
      ),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(DokkoTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Registrar Pago',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: DokkoTokens.text,
                ),
              ),
              const SizedBox(height: DokkoTokens.space20),
              // Plans quick-select
              if (_loadingPlans)
                const Center(child: CircularProgressIndicator())
              else if (_plans.isNotEmpty) ...[
                const Text('Seleccionar Plan',
                    style: TextStyle(fontSize: 13, color: DokkoTokens.text2)),
                const SizedBox(height: DokkoTokens.space8),
                Wrap(
                  spacing: DokkoTokens.space8,
                  runSpacing: DokkoTokens.space8,
                  children: _plans.map((plan) {
                    final selected = _selectedPlanId == plan['id'];
                    return GestureDetector(
                      onTap: () => _applyPlan(plan),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(plan['name'],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: selected
                                      ? DokkoTokens.accentDefault
                                      : DokkoTokens.text,
                                )),
                            Text('\$${plan['price']}',
                                style: const TextStyle(
                                    fontSize: 12, color: DokkoTokens.text2)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: DokkoTokens.space16),
              ],
              // Amount
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: DokkoTokens.text),
                decoration: InputDecoration(
                  labelText: 'Monto',
                  labelStyle: const TextStyle(color: DokkoTokens.text2),
                  prefixText: '\$ ',
                  prefixStyle: const TextStyle(color: DokkoTokens.text2),
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
                ),
              ),
              const SizedBox(height: DokkoTokens.space16),
              // Payment method
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                dropdownColor: DokkoTokens.surface,
                style: const TextStyle(color: DokkoTokens.text),
                decoration: InputDecoration(
                  labelText: 'Método de Pago',
                  labelStyle: const TextStyle(color: DokkoTokens.text2),
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
                ),
                items: const [
                  DropdownMenuItem(value: 'cash',     child: Text('Efectivo')),
                  DropdownMenuItem(value: 'card',     child: Text('Tarjeta')),
                  DropdownMenuItem(value: 'transfer', child: Text('Transferencia')),
                  DropdownMenuItem(value: 'other',    child: Text('Otro')),
                ],
                onChanged: (v) => setState(() => _paymentMethod = v!),
              ),
              const SizedBox(height: DokkoTokens.space16),
              // Dates row
              Row(
                children: [
                  Expanded(child: _DateField(
                    label: 'Desde',
                    value: _validFrom,
                    onChanged: (d) => setState(() => _validFrom = d),
                  )),
                  const SizedBox(width: DokkoTokens.space12),
                  Expanded(child: _DateField(
                    label: 'Hasta',
                    value: _validUntil,
                    onChanged: (d) => setState(() => _validUntil = d),
                  )),
                ],
              ),
              const SizedBox(height: DokkoTokens.space24),
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
                    label: 'Registrar',
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
}

// Pequeño widget para fechas
class _DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  const _DateField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) => Theme(
            data: ThemeData.dark(),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DokkoTokens.space12,
          vertical: DokkoTokens.space12,
        ),
        decoration: BoxDecoration(
          color: DokkoTokens.surface2,
          borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
          border: Border.all(color: DokkoTokens.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 14, color: DokkoTokens.text2),
            const SizedBox(width: DokkoTokens.space8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: DokkoTokens.text2)),
                Text(
                  '${value.day}/${value.month}/${value.year}',
                  style: const TextStyle(
                      fontSize: 13, color: DokkoTokens.text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
