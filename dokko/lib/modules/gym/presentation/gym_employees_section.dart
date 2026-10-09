import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_card.dart';
import '../../../core/widgets/dokko_modal.dart';
import '../../../core/widgets/dokko_skeleton.dart';
import '../data/gym_api.dart';
import '../providers/gym_provider.dart';

class GymEmployeesSection extends ConsumerWidget {
  const GymEmployeesSection({super.key});

  static const _roles = {
    'entrenador': 'Entrenador/a',
    'recepcion': 'Recepción',
    'staff': 'Staff / Soporte',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(gymEmployeesProvider);

    return DokkoCard(
      key: const ValueKey('employees-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.groups_rounded,
                      size: 16, color: DokkoTokens.accentDefault),
                  const SizedBox(width: DokkoTokens.space8),
                  const Text('Empleados',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: DokkoTokens.text)),
                ],
              ),
              DokkoButton(
                key: const ValueKey('add-employee-btn'),
                label: 'Agregar',
                variant: DokkoButtonVariant.secondary,
                onPressed: () => _openAddDialog(ref),
              ),
            ],
          ),
          const SizedBox(height: DokkoTokens.space16),
          employeesAsync.when(
            loading: () => const Column(
              children: [
                DokkoSkeleton(height: 34),
                SizedBox(height: DokkoTokens.space8),
                DokkoSkeleton(height: 34),
                SizedBox(height: DokkoTokens.space8),
                DokkoSkeleton(height: 34),
              ],
            ),
            error: (e, _) => Text(
              'No se pudieron cargar los empleados: $e',
              style: const TextStyle(fontSize: 13, color: DokkoTokens.text2),
            ),
            data: (employees) {
              final list = employees.cast<Map<String, dynamic>>();
              if (list.isEmpty) {
                return const Text(
                  'Sin empleados todavía. Agrega a tu equipo.',
                  style: TextStyle(fontSize: 13, color: DokkoTokens.text2),
                );
              }
              return Column(
                children: [
                  for (final e in list)
                    _EmployeeRow(
                      employee: e,
                      onDelete: () => _deleteEmployee(ref, e['id'] as String),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openAddDialog(WidgetRef ref) async {
    await DokkoModal.show(
      context: ref.context,
      title: 'Agregar Empleado',
      content: const _AddEmployeeForm(),
    );
  }

  Future<void> _deleteEmployee(WidgetRef ref, String id) async {
    final messenger = ScaffoldMessenger.of(ref.context);
    try {
      await ref.read(gymApiProvider).deleteEmployee(id);
      ref.invalidate(gymEmployeesProvider);
    } catch (e) {
      if (!messenger.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error al quitar empleado: $e')),
      );
    }
  }
}

class _EmployeeRow extends StatelessWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onDelete;

  const _EmployeeRow({required this.employee, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final first = employee['first_name'] as String? ?? '';
    final last = employee['last_name'] as String? ?? '';
    final role = employee['role'] as String? ?? 'entrenador';
    final phone = employee['phone'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: DokkoTokens.space8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DokkoTokens.space12,
          vertical: DokkoTokens.space8,
        ),
        decoration: BoxDecoration(
          color: DokkoTokens.surface2,
          borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
          border: Border.all(color: DokkoTokens.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$first $last'.trim(),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: DokkoTokens.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      GymEmployeesSection._roles[role] ?? role,
                      if (phone != null && phone.isNotEmpty) phone,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: DokkoTokens.text2),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline_rounded,
                    size: 18, color: DokkoTokens.text3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEmployeeForm extends ConsumerStatefulWidget {
  const _AddEmployeeForm();

  @override
  ConsumerState<_AddEmployeeForm> createState() => _AddEmployeeFormState();
}

class _AddEmployeeFormState extends ConsumerState<_AddEmployeeForm> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _role = 'entrenador';
  bool _saving = false;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_firstCtrl.text.trim().isEmpty || _lastCtrl.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(gymApiProvider).createEmployee({
        'first_name': _firstCtrl.text.trim(),
        'last_name': _lastCtrl.text.trim(),
        'role': _role,
        if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
        if (_emailCtrl.text.trim().isNotEmpty) 'email': _emailCtrl.text.trim(),
      });
      ref.invalidate(gymEmployeesProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear empleado: $e')),
      );
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: DokkoTokens.text3),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: DokkoTokens.space12, vertical: DokkoTokens.space8),
        filled: true,
        fillColor: DokkoTokens.surface2,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
            borderSide: const BorderSide(color: DokkoTokens.line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
            borderSide: const BorderSide(color: DokkoTokens.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
            borderSide: const BorderSide(color: DokkoTokens.accentDefault)),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('emp-first'),
                controller: _firstCtrl,
                style: const TextStyle(color: DokkoTokens.text, fontSize: 14),
                decoration: _dec('Nombre'),
              ),
            ),
            const SizedBox(width: DokkoTokens.space12),
            Expanded(
              child: TextField(
                key: const ValueKey('emp-last'),
                controller: _lastCtrl,
                style: const TextStyle(color: DokkoTokens.text, fontSize: 14),
                decoration: _dec('Apellido'),
              ),
            ),
          ],
        ),
        const SizedBox(height: DokkoTokens.space12),
        DropdownButtonFormField<String>(
          initialValue: _role,
          dropdownColor: DokkoTokens.surface,
          style: const TextStyle(color: DokkoTokens.text, fontSize: 14),
          decoration: _dec('Rol'),
          items: GymEmployeesSection._roles.entries
              .map((e) =>
                  DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => _role = v ?? 'entrenador'),
        ),
        const SizedBox(height: DokkoTokens.space12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _phoneCtrl,
                style: const TextStyle(color: DokkoTokens.text, fontSize: 14),
                decoration: _dec('Teléfono (opcional)'),
              ),
            ),
            const SizedBox(width: DokkoTokens.space12),
            Expanded(
              child: TextField(
                controller: _emailCtrl,
                style: const TextStyle(color: DokkoTokens.text, fontSize: 14),
                decoration: _dec('Email (opcional)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: DokkoTokens.space24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            DokkoButton(
              label: 'Cancelar',
              variant: DokkoButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: DokkoTokens.space12),
            DokkoButton(
              key: const ValueKey('save-employee-btn'),
              label: 'Guardar',
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ],
    );
  }
}