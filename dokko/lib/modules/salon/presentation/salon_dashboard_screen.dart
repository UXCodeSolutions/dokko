import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_card.dart';
import '../data/models/salon_models.dart';
import '../data/salon_api.dart';

final salonAppointmentsProvider = FutureProvider<List<SalonAppointment>>((ref) async {
  return ref.read(salonApiProvider).getAppointments();
});

final salonEmployeesProvider = FutureProvider<List<SalonEmployee>>((ref) async {
  return ref.read(salonApiProvider).getEmployees();
});

class SalonDashboardScreen extends ConsumerWidget {
  const SalonDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(salonAppointmentsProvider);
    final employeesAsync = ref.watch(salonEmployeesProvider);

    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      appBar: AppBar(
        title: const Text('Dashboard — SalonOS', style: TextStyle(color: DokkoTokens.text)),
        backgroundColor: DokkoTokens.surface,
        elevation: 0,
      ),
      body: appointmentsAsync.when(
        data: (appointments) {
          final today = DateTime.now();
          final todayAppts = appointments.where((a) {
            final d = a.startTime;
            return d.year == today.year && d.month == today.month && d.day == today.day && a.status != 'cancelled';
          }).toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));

          return ListView(
            padding: const EdgeInsets.all(DokkoTokens.space16),
            children: [
              // KPI Row
              Row(
                children: [
                  Expanded(child: _buildKpi('Citas Hoy', todayAppts.length.toString(), Icons.event_rounded, Colors.blue)),
                  const SizedBox(width: DokkoTokens.space16),
                  Expanded(child: _buildKpi('Completadas', todayAppts.where((a) => a.status == 'completed').length.toString(), Icons.check_circle_rounded, Colors.green)),
                  const SizedBox(width: DokkoTokens.space16),
                  employeesAsync.when(
                    data: (emp) => Expanded(child: _buildKpi('Empleados Activos', emp.length.toString(), Icons.people_rounded, Colors.purple)),
                    loading: () => const Expanded(child: SizedBox()),
                    error: (e, stack) => const Expanded(child: SizedBox()),
                  ),
                ],
              ),
              const SizedBox(height: DokkoTokens.space24),
              const Text('Próximas citas de hoy', style: TextStyle(color: DokkoTokens.text, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: DokkoTokens.space16),
              if (todayAppts.isEmpty)
                DokkoCard(
                  padding: const EdgeInsets.all(DokkoTokens.space24),
                  child: const Center(
                    child: Text('No hay citas para hoy.', style: TextStyle(color: DokkoTokens.text3)),
                  ),
                )
              else
                ...todayAppts.take(10).map((appt) => _buildAppointmentTile(appt)),
            ],
          );
        },
        loading: () => _buildSkeleton(),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: DokkoTokens.text2))),
      ),
    );
  }

  Widget _buildKpi(String title, String value, IconData icon, Color color) {
    return DokkoCard(
      padding: const EdgeInsets.all(DokkoTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: DokkoTokens.space12),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: DokkoTokens.text)),
          const SizedBox(height: DokkoTokens.space4),
          Text(title, style: const TextStyle(fontSize: 12, color: DokkoTokens.text2)),
        ],
      ),
    );
  }

  Widget _buildAppointmentTile(SalonAppointment appt) {
    final startStr = '${appt.startTime.hour.toString().padLeft(2, '0')}:${appt.startTime.minute.toString().padLeft(2, '0')}';
    final endStr   = '${appt.endTime.hour.toString().padLeft(2, '0')}:${appt.endTime.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: DokkoTokens.space8),
      child: DokkoCard(
        padding: const EdgeInsets.all(DokkoTokens.space12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: appt.status == 'completed' ? Colors.green : DokkoTokens.accentDefault,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: DokkoTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appt.clientName ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.w600, color: DokkoTokens.text)),
                  Text('$startStr – $endStr', style: const TextStyle(fontSize: 12, color: DokkoTokens.text2)),
                ],
              ),
            ),
            _statusBadge(appt.status),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final (label, color) = switch (status) {
      'completed' => ('Completada', Colors.green),
      'cancelled' => ('Cancelada', Colors.red),
      'no_show'   => ('No vino', Colors.orange),
      _           => ('Programada', DokkoTokens.accentDefault),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(DokkoTokens.space16),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: DokkoTokens.space16),
        height: 80,
        decoration: BoxDecoration(color: DokkoTokens.surface2, borderRadius: BorderRadius.circular(DokkoTokens.radiusLg)),
      ),
    );
  }
}
