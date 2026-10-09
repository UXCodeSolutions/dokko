import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_card.dart';
import '../../../core/widgets/dokko_input.dart';
import '../data/gym_api.dart';
import '../providers/gym_provider.dart';

class GymMemberFormScreen extends ConsumerStatefulWidget {
  /// Si es null, es modo creación. Si tiene valor, es modo edición.
  final Map<String, dynamic>? member;

  const GymMemberFormScreen({super.key, this.member});

  @override
  ConsumerState<GymMemberFormScreen> createState() => _GymMemberFormScreenState();
}

class _GymMemberFormScreenState extends ConsumerState<GymMemberFormScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _idCtrl        = TextEditingController();
  final _notesCtrl     = TextEditingController();

  bool _isLoading = false;
  bool _consent = false;

  bool get _isEditing => widget.member != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final m = widget.member!;
      _firstNameCtrl.text = m['first_name'] ?? '';
      _lastNameCtrl.text  = m['last_name']  ?? '';
      _emailCtrl.text     = m['email']      ?? '';
      _phoneCtrl.text     = m['phone']      ?? '';
      _idCtrl.text        = m['id_number']  ?? '';
      _notesCtrl.text     = m['notes']      ?? '';
      _consent            = m['consent_granted_at'] != null;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _idCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName  = _lastNameCtrl.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) return;

    setState(() => _isLoading = true);

    final data = {
      'first_name': firstName,
      'last_name':  lastName,
      'email':      _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      'phone':      _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      'id_number':  _idCtrl.text.trim().isEmpty    ? null : _idCtrl.text.trim(),
      'notes':      _notesCtrl.text.trim().isEmpty  ? null : _notesCtrl.text.trim(),
      // FASE 25 — Ley 172-13: marca de consentimiento individual.
      'consent_granted_at': _consent ? DateTime.now().toUtc().toIso8601String() : null,
    };

    try {
      final api = ref.read(gymApiProvider);
      if (_isEditing) {
        await api.updateMember(widget.member!['id'], data);
      } else {
        await api.createMember(data);
      }
      // Invalidar cache para refrescar lista
      ref.invalidate(gymMembersProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: DokkoTokens.text),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: DokkoTokens.space8),
                Text(
                  _isEditing ? 'Editar Miembro' : 'Nuevo Miembro',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: DokkoTokens.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DokkoTokens.space24),
            Expanded(
              child: SingleChildScrollView(
                child: DokkoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DokkoInput(
                              label: 'Nombre *',
                              placeholder: 'Juan',
                              controller: _firstNameCtrl,
                            ),
                          ),
                          const SizedBox(width: DokkoTokens.space16),
                          Expanded(
                            child: DokkoInput(
                              label: 'Apellido *',
                              placeholder: 'Pérez',
                              controller: _lastNameCtrl,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DokkoTokens.space16),
                      Row(
                        children: [
                          Expanded(
                            child: DokkoInput(
                              label: 'Email',
                              placeholder: 'juan@email.com',
                              controller: _emailCtrl,
                            ),
                          ),
                          const SizedBox(width: DokkoTokens.space16),
                          Expanded(
                            child: DokkoInput(
                              label: 'Teléfono',
                              placeholder: '+1 809 000 0000',
                              controller: _phoneCtrl,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DokkoTokens.space16),
                      DokkoInput(
                        label: 'Cédula / ID',
                        placeholder: '000-0000000-0',
                        controller: _idCtrl,
                      ),
                      const SizedBox(height: DokkoTokens.space16),
                      Container(
                        padding: const EdgeInsets.all(DokkoTokens.space16),
                        decoration: BoxDecoration(
                          color: DokkoTokens.surface,
                          borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
                          border: Border.all(color: _consent ? DokkoTokens.green : DokkoTokens.lineStrong),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _consent,
                              onChanged: (v) => setState(() => _consent = v ?? false),
                            ),
                            const SizedBox(width: DokkoTokens.space12),
                            const Expanded(
                              child: Text(
                                'Acepto el tratamiento de mis datos personales conforme a la Ley 172-13 (Protección de Datos Personales).',
                                style: TextStyle(color: DokkoTokens.text, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: DokkoTokens.space16),
                      DokkoInput(
                        label: 'Notas',
                        placeholder: 'Lesión en rodilla, objetivo: pérdida de peso...',
                        controller: _notesCtrl,
                        maxLines: 3,
                      ),
                      const SizedBox(height: DokkoTokens.space24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          DokkoButton(
                            label: 'Cancelar',
                            variant: DokkoButtonVariant.ghost,
                            onPressed: () => context.pop(),
                          ),
                          const SizedBox(width: DokkoTokens.space16),
                          DokkoButton(
                            label: _isEditing ? 'Guardar Cambios' : 'Crear Miembro',
                            isLoading: _isLoading,
                            onPressed: _handleSave,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
