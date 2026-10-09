class AgendaResource {
  final String id;
  final String name;
  final String type;
  final String? referenceId;
  final bool isActive;

  AgendaResource({
    required this.id,
    required this.name,
    required this.type,
    this.referenceId,
    required this.isActive,
  });

  factory AgendaResource.fromJson(Map<String, dynamic> json) {
    return AgendaResource(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      referenceId: json['reference_id'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'reference_id': referenceId,
        'is_active': isActive,
      };
}

class AgendaAppointment {
  final String id;
  final String resourceId;
  final String? clientName;
  final String? clientId;
  final DateTime startTime;
  final DateTime endTime;
  final String status; // scheduled, completed, cancelled, no_show
  final String? moduleReference;
  final String? notes;

  AgendaAppointment({
    required this.id,
    required this.resourceId,
    this.clientName,
    this.clientId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.moduleReference,
    this.notes,
  });

  factory AgendaAppointment.fromJson(Map<String, dynamic> json) {
    return AgendaAppointment(
      id: json['id'],
      resourceId: json['resource_id'],
      clientName: json['client_name'],
      clientId: json['client_id'],
      startTime: DateTime.parse(json['start_time']).toLocal(),
      endTime: DateTime.parse(json['end_time']).toLocal(),
      status: json['status'] ?? 'scheduled',
      moduleReference: json['module_reference'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'resource_id': resourceId,
        'client_name': clientName,
        'client_id': clientId,
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'status': status,
        'module_reference': moduleReference,
        'notes': notes,
      };
}
