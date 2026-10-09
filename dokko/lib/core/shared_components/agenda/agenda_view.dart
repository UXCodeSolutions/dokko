import 'package:flutter/material.dart';
import '../../theme/dokko_tokens.dart';
import 'agenda_models.dart';

class AgendaCalendarView extends StatelessWidget {
  final DateTime selectedDate;
  final List<AgendaAppointment> appointments;
  final List<AgendaResource> resources;
  final Function(DateTime) onDateSelected;
  final Function(AgendaAppointment) onAppointmentTap;
  final Function(DateTime, AgendaResource) onTimeSlotTap;

  const AgendaCalendarView({
    super.key,
    required this.selectedDate,
    required this.appointments,
    required this.resources,
    required this.onDateSelected,
    required this.onAppointmentTap,
    required this.onTimeSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    if (resources.isEmpty) {
      return const Center(
        child: Text(
          'No hay recursos disponibles en la agenda.',
          style: TextStyle(color: DokkoTokens.text2),
        ),
      );
    }

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTimeColumn(),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: resources.map((res) {
                      return SizedBox(
                        width: 250,
                        child: _buildResourceColumn(res),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(DokkoTokens.space16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DokkoTokens.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: DokkoTokens.text),
                onPressed: () => onDateSelected(
                  selectedDate.subtract(const Duration(days: 1)),
                ),
              ),
              const SizedBox(width: DokkoTokens.space8),
              Text(
                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                style: const TextStyle(
                  color: DokkoTokens.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: DokkoTokens.space8),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: DokkoTokens.text),
                onPressed: () => onDateSelected(
                  selectedDate.add(const Duration(days: 1)),
                ),
              ),
            ],
          ),
          const Text(
            'Vista Diaria',
            style: TextStyle(color: DokkoTokens.text2, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeColumn() {
    return Container(
      width: 60,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: DokkoTokens.line)),
        color: DokkoTokens.surface2,
      ),
      child: ListView.builder(
        itemCount: 15, // 08:00 to 22:00
        itemBuilder: (context, index) {
          final hour = index + 8;
          return Container(
            height: 60,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: DokkoTokens.space4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: DokkoTokens.line)),
            ),
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: const TextStyle(color: DokkoTokens.text3, fontSize: 12),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResourceColumn(AgendaResource resource) {
    final resAppointments = appointments
        .where((a) => a.resourceId == resource.id)
        .toList();

    return Column(
      children: [
        Container(
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: DokkoTokens.line),
              right: BorderSide(color: DokkoTokens.line),
            ),
            color: DokkoTokens.surface2,
          ),
          child: Text(
            resource.name,
            style: const TextStyle(
              color: DokkoTokens.text,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: DokkoTokens.line)),
            ),
            child: Stack(
              children: [
                // Render time slots
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 15, // 08:00 to 22:00
                  itemBuilder: (context, index) {
                    final hour = index + 8;
                    final slotTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      hour,
                    );
                    return InkWell(
                      onTap: () => onTimeSlotTap(slotTime, resource),
                      child: Container(
                        height: 60,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: DokkoTokens.lineStrong),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Render appointments on top
                ...resAppointments.map((app) {
                  final startHour = app.startTime.hour + (app.startTime.minute / 60.0);
                  final endHour = app.endTime.hour + (app.endTime.minute / 60.0);
                  
                  // Offset from 08:00
                  final topOffset = (startHour - 8) * 60;
                  final height = (endHour - startHour) * 60;
                  
                  if (topOffset < 0 || topOffset > 15 * 60) return const SizedBox();

                  return Positioned(
                    top: topOffset,
                    left: 2,
                    right: 2,
                    height: height,
                    child: GestureDetector(
                      onTap: () => onAppointmentTap(app),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: DokkoTokens.accentDefault.withValues(alpha: 0.2),
                          border: Border.all(color: DokkoTokens.accentDefault),
                          borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.clientName ?? 'Ocupado',
                              style: const TextStyle(
                                color: DokkoTokens.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (app.notes != null)
                              Expanded(
                                child: Text(
                                  app.notes!,
                                  style: const TextStyle(
                                    color: DokkoTokens.text2,
                                    fontSize: 10,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
