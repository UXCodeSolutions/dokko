import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_card.dart';
import 'gym_employees_section.dart';
import '../data/gym_api.dart';

class GymSettingsScreen extends ConsumerStatefulWidget {
  const GymSettingsScreen({super.key});

  @override
  ConsumerState<GymSettingsScreen> createState() => _GymSettingsScreenState();
}

class _GymSettingsScreenState extends ConsumerState<GymSettingsScreen> {
  // Controllers – Basic info
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  String _currency = 'USD';
  String _timezone = 'America/New_York';

  // Hours: map of weekday key → {open, close, closed}
  final Map<String, Map<String, dynamic>> _hours = {
    'mon': {'open': '06:00', 'close': '22:00', 'closed': false},
    'tue': {'open': '06:00', 'close': '22:00', 'closed': false},
    'wed': {'open': '06:00', 'close': '22:00', 'closed': false},
    'thu': {'open': '06:00', 'close': '22:00', 'closed': false},
    'fri': {'open': '06:00', 'close': '22:00', 'closed': false},
    'sat': {'open': '08:00', 'close': '18:00', 'closed': false},
    'sun': {'open': '08:00', 'close': '14:00', 'closed': true},
  };

  static const _dayLabels = {
    'mon': 'Lunes', 'tue': 'Martes', 'wed': 'Miércoles',
    'thu': 'Jueves', 'fri': 'Viernes', 'sat': 'Sábado', 'sun': 'Domingo',
  };

  static const _currencies = ['USD', 'EUR', 'COP', 'MXN', 'DOP', 'PEN', 'ARS', 'BRL'];
  static const _timezones = [
    'America/New_York', 'America/Chicago', 'America/Denver',
    'America/Los_Angeles', 'America/Bogota', 'America/Lima',
    'America/Mexico_City', 'America/Santo_Domingo', 'Europe/Madrid',
    'America/Buenos_Aires', 'America/Sao_Paulo',
  ];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _websiteCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(gymApiProvider);
      final s = await api.getGymSettings();
      if (!mounted) return;
      setState(() {
        _nameCtrl.text    = s['gym_name'] ?? '';
        _phoneCtrl.text   = s['phone'] ?? '';
        _emailCtrl.text   = s['email'] ?? '';
        _addressCtrl.text = s['address'] ?? '';
        _websiteCtrl.text = s['website'] ?? '';
        _capacityCtrl.text = (s['capacity'] ?? 0).toString();
        _currency = s['currency'] ?? 'USD';
        _timezone = s['timezone'] ?? 'America/New_York';

        // Load hours
        final hoursData = s['hours'] as Map?;
        if (hoursData != null && hoursData.isNotEmpty) {
          for (final key in _hours.keys) {
            if (hoursData.containsKey(key)) {
              _hours[key] = Map<String, dynamic>.from(hoursData[key]);
            }
          }
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final api = ref.read(gymApiProvider);
      await api.updateGymSettings({
        'gym_name':  _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        'phone':     _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email':     _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'address':   _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'website':   _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        'capacity':  int.tryParse(_capacityCtrl.text) ?? 0,
        'currency':  _currency,
        'timezone':  _timezone,
        'hours':     _hours,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Configuración guardada'),
          backgroundColor: DokkoTokens.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
                          Text('Configuración',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: DokkoTokens.text)),
                          SizedBox(height: 2),
                          Text('Personaliza tu gimnasio.',
                              style: TextStyle(
                                  fontSize: 13, color: DokkoTokens.text2)),
                        ],
                      ),
                      DokkoButton(
                        label: 'Guardar Cambios',
                        isLoading: _isSaving,
                        onPressed: _save,
                      ),
                    ],
                  ),
                  const SizedBox(height: DokkoTokens.space24),

                  // Content
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Basic info
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildBasicInfo(),
                                const SizedBox(height: DokkoTokens.space16),
                                _buildOperationalSettings(),
                                const SizedBox(height: DokkoTokens.space16),
                                const GymEmployeesSection(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: DokkoTokens.space16),
                        // Right: Hours
                        SizedBox(
                          width: 340,
                          child: _buildHours(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBasicInfo() {
    return DokkoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.store_rounded, 'Información General'),
          const SizedBox(height: DokkoTokens.space16),
          _Field(
            label: 'Nombre del Gym',
            child: _textField(_nameCtrl, 'Mi Gimnasio'),
          ),
          const SizedBox(height: DokkoTokens.space12),
          Row(children: [
            Expanded(
              child: _Field(
                label: 'Teléfono',
                child: _textField(_phoneCtrl, '+1 (555) 000-0000'),
              ),
            ),
            const SizedBox(width: DokkoTokens.space12),
            Expanded(
              child: _Field(
                label: 'Email',
                child: _textField(_emailCtrl, 'gym@ejemplo.com'),
              ),
            ),
          ]),
          const SizedBox(height: DokkoTokens.space12),
          _Field(
            label: 'Dirección',
            child: _textField(_addressCtrl, 'Calle Principal #123'),
          ),
          const SizedBox(height: DokkoTokens.space12),
          _Field(
            label: 'Sitio Web',
            child: _textField(_websiteCtrl, 'https://migym.com'),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalSettings() {
    return DokkoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.settings_rounded, 'Opciones Operativas'),
          const SizedBox(height: DokkoTokens.space16),
          Row(children: [
            Expanded(
              child: _Field(
                label: 'Capacidad máxima (0 = sin límite)',
                child: _textField(_capacityCtrl, '0',
                    type: TextInputType.number),
              ),
            ),
            const SizedBox(width: DokkoTokens.space12),
            Expanded(
              child: _Field(
                label: 'Moneda',
                child: _dropdownField(
                  value: _currency,
                  items: _currencies,
                  onChanged: (v) => setState(() => _currency = v!),
                ),
              ),
            ),
          ]),
          const SizedBox(height: DokkoTokens.space12),
          _Field(
            label: 'Zona Horaria',
            child: _dropdownField(
              value: _timezone,
              items: _timezones,
              onChanged: (v) => setState(() => _timezone = v!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHours() {
    return DokkoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionHeader(Icons.access_time_rounded, 'Horario de Atención'),
          const SizedBox(height: DokkoTokens.space16),
          ..._hours.entries.map((entry) {
            final key = entry.key;
            final day = entry.value;
            final isClosed = day['closed'] as bool? ?? false;

            return Padding(
              padding: const EdgeInsets.only(bottom: DokkoTokens.space12),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      _dayLabels[key] ?? key,
                      style: const TextStyle(
                          fontSize: 13, color: DokkoTokens.text),
                    ),
                  ),
                  // Closed toggle
                  Switch(
                    value: !isClosed,
                    onChanged: (v) => setState(
                        () => _hours[key]!['closed'] = !v),
                    activeThumbColor: DokkoTokens.green,
                  ),
                  const SizedBox(width: DokkoTokens.space8),
                  if (isClosed)
                    const Expanded(
                      child: Text('Cerrado',
                          style: TextStyle(
                              fontSize: 12, color: DokkoTokens.text2)),
                    )
                  else ...[
                    Expanded(
                      child: _TimeField(
                        value: day['open'] as String? ?? '06:00',
                        onChanged: (v) =>
                            setState(() => _hours[key]!['open'] = v),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: DokkoTokens.space8),
                      child: Text('—',
                          style:
                              TextStyle(color: DokkoTokens.text2)),
                    ),
                    Expanded(
                      child: _TimeField(
                        value: day['close'] as String? ?? '22:00',
                        onChanged: (v) =>
                            setState(() => _hours[key]!['close'] = v),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Helper builders ────────────────────────────────────────────────────────

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: DokkoTokens.accentDefault),
        const SizedBox(width: DokkoTokens.space8),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: DokkoTokens.text)),
      ],
    );
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

  Widget _textField(TextEditingController ctrl, String hint,
          {TextInputType type = TextInputType.text}) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(color: DokkoTokens.text, fontSize: 14),
        decoration: _dec(hint),
      );

  Widget _dropdownField({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: DokkoTokens.surface,
        style: const TextStyle(color: DokkoTokens.text, fontSize: 14),
        decoration: _dec(''),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: onChanged,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Field label wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: DokkoTokens.text2)),
          const SizedBox(height: DokkoTokens.space4),
          child,
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Time field (HH:MM text input)
// ─────────────────────────────────────────────────────────────────────────────
class _TimeField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _TimeField({required this.value, required this.onChanged});

  @override
  State<_TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<_TimeField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      textAlign: TextAlign.center,
      style: const TextStyle(
          fontSize: 13, color: DokkoTokens.text),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: DokkoTokens.space8, vertical: DokkoTokens.space8),
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
      ),
      onChanged: widget.onChanged,
    );
  }
}
