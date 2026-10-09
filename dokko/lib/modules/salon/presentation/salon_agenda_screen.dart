import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../data/models/salon_models.dart';
import '../data/salon_api.dart';
import 'salon_dashboard_screen.dart'; // reuse providers

class SalonAgendaScreen extends ConsumerStatefulWidget {
  const SalonAgendaScreen({super.key});

  @override
  ConsumerState<SalonAgendaScreen> createState() => _SalonAgendaScreenState();
}

class _SalonAgendaScreenState extends ConsumerState<SalonAgendaScreen> {
  DateTime _selectedWeekStart = _getWeekStart(DateTime.now());

  static DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1)); // Monday
  }

  void _prevWeek() => setState(() => _selectedWeekStart = _selectedWeekStart.subtract(const Duration(days: 7)));
  void _nextWeek() => setState(() => _selectedWeekStart = _selectedWeekStart.add(const Duration(days: 7)));

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(salonEmployeesProvider);
    final appointmentsAsync = ref.watch(salonAppointmentsProvider);

    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      appBar: AppBar(
        title: const Text('Agenda', style: TextStyle(color: DokkoTokens.text)),
        backgroundColor: DokkoTokens.surface,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () => _showNewAppointmentDialog(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva Cita'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DokkoTokens.accentDefault,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Week navigation header
          Container(
            color: DokkoTokens.surface,
            padding: const EdgeInsets.symmetric(horizontal: DokkoTokens.space16, vertical: DokkoTokens.space8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: _prevWeek, icon: const Icon(Icons.chevron_left_rounded, color: DokkoTokens.text)),
                Text(
                  _weekRangeLabel(),
                  style: const TextStyle(color: DokkoTokens.text, fontWeight: FontWeight.w600, fontSize: 15),
                ),
                IconButton(onPressed: _nextWeek, icon: const Icon(Icons.chevron_right_rounded, color: DokkoTokens.text)),
              ],
            ),
          ),
          Expanded(
            child: employeesAsync.when(
              data: (employees) {
                if (employees.isEmpty) {
                  return const Center(
                    child: Text('No hay empleados activos.\nAgrega empleados para ver la agenda.', textAlign: TextAlign.center, style: TextStyle(color: DokkoTokens.text2)),
                  );
                }
                return appointmentsAsync.when(
                  data: (appointments) => _buildCalendarGrid(employees, appointments),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error cargando empleados: $e')),
            ),
          ),
        ],
      ),
    );
  }

  String _weekRangeLabel() {
    final end = _selectedWeekStart.add(const Duration(days: 6));
    final months = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${_selectedWeekStart.day} ${months[_selectedWeekStart.month]} – ${end.day} ${months[end.month]} ${end.year}';
  }

  Widget _buildCalendarGrid(List<SalonEmployee> employees, List<SalonAppointment> appointments) {
    final days = List.generate(7, (i) => _selectedWeekStart.add(Duration(days: i)));
    final dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    return LayoutBuilder(
      builder: (context, constraints) {
        const timeColWidth = 60.0;
        final colWidth = ((constraints.maxWidth - timeColWidth) / employees.length).clamp(160.0, 280.0);

        final headerWidth = timeColWidth + colWidth * 7;
        final gridWidth = timeColWidth + colWidth * employees.length;
        final totalWidth = gridWidth > headerWidth ? gridWidth : headerWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Column(
              children: [
                // Day header row
                Row(
                  children: [
                    SizedBox(width: timeColWidth),
                    ...days.map((day) {
                      final isToday = day.day == DateTime.now().day &&
                          day.month == DateTime.now().month &&
                          day.year == DateTime.now().year;
                      return Container(
                        width: colWidth,
                        padding: const EdgeInsets.symmetric(vertical: DokkoTokens.space8),
                        decoration: BoxDecoration(
                          color: isToday ? DokkoTokens.accentDefault.withValues(alpha: 0.1) : null,
                          border: Border(bottom: BorderSide(color: DokkoTokens.surface2)),
                        ),
                        child: Center(
                          child: Text(
                            '${dayNames[day.weekday - 1]} ${day.day}',
                            style: TextStyle(
                              color: isToday ? DokkoTokens.accentDefault : DokkoTokens.text2,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                // Employee column headers
                Row(
                  children: [
                    SizedBox(width: timeColWidth),
                    ...employees.map((emp) {
                      final color = _parseColor(emp.color);
                      return Container(
                        width: colWidth,
                        padding: const EdgeInsets.all(DokkoTokens.space8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.07),
                          border: Border(left: BorderSide(color: DokkoTokens.surface2), bottom: BorderSide(color: DokkoTokens.surface2)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: color.withValues(alpha: 0.2),
                              foregroundColor: color,
                              child: Text(emp.firstName[0], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${emp.firstName} ${emp.lastName}',
                                style: const TextStyle(fontSize: 12, color: DokkoTokens.text, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
                // Scrollable time slots
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: List.generate(24, (hour) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: timeColWidth,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4, right: 8),
                                child: Text(
                                  '${hour.toString().padLeft(2, '0')}:00',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 11, color: DokkoTokens.text3),
                                ),
                              ),
                            ),
                            ...employees.map((emp) {
                              final empAppts = appointments.where((a) {
                                final sameDay = days.any((d) =>
                                  d.day == a.startTime.toLocal().day &&
                                  d.month == a.startTime.toLocal().month &&
                                  d.year == a.startTime.toLocal().year);
                                return a.resourceId == emp.resourceId && sameDay && a.startTime.toLocal().hour == hour;
                              }).toList();

                              return Container(
                                width: colWidth,
                                height: 56,
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(color: DokkoTokens.surface2),
                                    bottom: BorderSide(color: DokkoTokens.surface2.withValues(alpha: 0.5)),
                                  ),
                                ),
                                child: empAppts.isEmpty
                                    ? null
                                    : Column(
                                        children: empAppts.map((appt) {
                                          final color = _parseColor(emp.color);
                                          return Padding(
                                            padding: const EdgeInsets.all(2),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: color.withValues(alpha: 0.5)),
                                              ),
                                              child: Text(
                                                appt.clientName ?? 'Cliente',
                                                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              );
                            }),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return DokkoTokens.accentDefault;
    }
  }

  void _showNewAppointmentDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const _NewAppointmentModal(),
    ).then((val) {
      if (val == true) {
        ref.invalidate(salonAppointmentsProvider);
      }
    });
  }
}

class _NewAppointmentModal extends ConsumerStatefulWidget {
  const _NewAppointmentModal();

  @override
  ConsumerState<_NewAppointmentModal> createState() => _NewAppointmentModalState();
}

class _NewAppointmentModalState extends ConsumerState<_NewAppointmentModal> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedEmployeeResourceId;
  String? _clientName;
  // ignore: prefer_final_fields
  DateTime _startTime = DateTime.now().copyWith(minute: 0, second: 0);
  bool _isLoading = false;

  void _submit() async {
    if (!_formKey.currentState!.validate() || _selectedEmployeeResourceId == null) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);
    try {
      await ref.read(salonApiProvider).createAppointment({
        'resource_id': _selectedEmployeeResourceId,
        'client_name': _clientName,
        'start_time': _startTime.toIso8601String(),
        'end_time': _startTime.add(const Duration(hours: 1)).toIso8601String(),
        'service_ids': [],
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
    final employeesAsync = ref.watch(salonEmployeesProvider);

    return Dialog(
      backgroundColor: DokkoTokens.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DokkoTokens.radiusLg)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(DokkoTokens.space24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nueva Cita', style: TextStyle(color: DokkoTokens.text, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: DokkoTokens.space16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Nombre del Cliente'),
                onSaved: (v) => _clientName = v,
              ),
              const SizedBox(height: DokkoTokens.space16),
              employeesAsync.when(
                data: (employees) => DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Empleado'),
                  items: employees
                      .where((e) => e.resourceId != null)
                      .map((e) => DropdownMenuItem(value: e.resourceId, child: Text('${e.firstName} ${e.lastName}')))
                      .toList(),
                  onChanged: (v) => _selectedEmployeeResourceId = v,
                  validator: (v) => v == null ? 'Selecciona un empleado' : null,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => const Text('Error cargando empleados'),
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
