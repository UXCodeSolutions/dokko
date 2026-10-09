class SalonService {
  final String id;
  final String name;
  final String? description;
  final String category;
  final int durationMinutes;
  final double price;
  final bool isActive;

  SalonService({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.durationMinutes,
    required this.price,
    this.isActive = true,
  });

  factory SalonService.fromJson(Map<String, dynamic> json) => SalonService(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        category: json['category'] ?? 'general',
        durationMinutes: json['duration_minutes'] ?? 30,
        price: (json['price'] as num).toDouble(),
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'category': category,
        'duration_minutes': durationMinutes,
        'price': price,
        'is_active': isActive,
      };
}

class SalonEmployee {
  final String id;
  final String? resourceId;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? email;
  final List<String> specialties;
  final double commissionRate;
  final String color;
  final bool isActive;

  SalonEmployee({
    required this.id,
    this.resourceId,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.email,
    this.specialties = const [],
    this.commissionRate = 0.0,
    this.color = '#3ECF8E',
    this.isActive = true,
  });

  factory SalonEmployee.fromJson(Map<String, dynamic> json) => SalonEmployee(
        id: json['id'],
        resourceId: json['resource_id'],
        firstName: json['first_name'],
        lastName: json['last_name'],
        phone: json['phone'],
        email: json['email'],
        specialties: json['specialties'] != null ? List<String>.from(json['specialties']) : [],
        commissionRate: json['commission_rate'] != null ? (json['commission_rate'] as num).toDouble() : 0.0,
        color: json['color'] ?? '#3ECF8E',
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'resource_id': resourceId,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'email': email,
        'specialties': specialties,
        'commission_rate': commissionRate,
        'color': color,
        'is_active': isActive,
      };
}

class SalonClient {
  final String id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? email;
  final String? notes;
  final Map<String, dynamic> preferences;
  final DateTime? lastVisitDate;
  final int totalVisits;
  final DateTime? consentGrantedAt;

  SalonClient({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.email,
    this.notes,
    this.preferences = const {},
    this.lastVisitDate,
    this.totalVisits = 0,
    this.consentGrantedAt,
  });

  factory SalonClient.fromJson(Map<String, dynamic> json) => SalonClient(
        id: json['id'],
        firstName: json['first_name'],
        lastName: json['last_name'],
        phone: json['phone'],
        email: json['email'],
        notes: json['notes'],
        preferences: json['preferences'] is Map ? Map<String, dynamic>.from(json['preferences']) : {},
        lastVisitDate: json['last_visit_date'] != null ? DateTime.parse(json['last_visit_date']) : null,
        totalVisits: json['total_visits'] ?? 0,
        consentGrantedAt: json['consent_granted_at'] != null
            ? DateTime.parse(json['consent_granted_at'])
            : null,
      );

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'email': email,
        'notes': notes,
        'preferences': preferences,
      };
}

class SalonAppointment {
  final String id;
  final String resourceId;
  final String? clientId;
  final String? clientName;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final String? notes;

  SalonAppointment({
    required this.id,
    required this.resourceId,
    this.clientId,
    this.clientName,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.notes,
  });

  factory SalonAppointment.fromJson(Map<String, dynamic> json) => SalonAppointment(
        id: json['id'],
        resourceId: json['resource_id'],
        clientId: json['client_id'],
        clientName: json['client_name'],
        startTime: DateTime.parse(json['start_time']),
        endTime: DateTime.parse(json['end_time']),
        status: json['status'] ?? 'scheduled',
        notes: json['notes'],
      );
}

// ── Mensajería (FASE 28) ─────────────────────────────────────────────────────

class MessagingSettings {
  final bool remindersEnabled;
  final int reminderHoursBefore;
  final bool feedbackEnabled;
  final String feedbackUrl;

  const MessagingSettings({
    this.remindersEnabled = true,
    this.reminderHoursBefore = 24,
    this.feedbackEnabled = false,
    this.feedbackUrl = '',
  });

  factory MessagingSettings.fromJson(Map<String, dynamic> json) => MessagingSettings(
        remindersEnabled: json['reminders_enabled'] ?? true,
        reminderHoursBefore: (json['reminder_hours_before'] as num?)?.toInt() ?? 24,
        feedbackEnabled: json['feedback_enabled'] ?? false,
        feedbackUrl: json['feedback_url'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'reminders_enabled': remindersEnabled,
        'reminder_hours_before': reminderHoursBefore,
        'feedback_enabled': feedbackEnabled,
        'feedback_url': feedbackUrl,
      };
}

class OutboundMessage {
  final String id;
  final String recipientName;
  final String phone;
  final String body;
  final String status;
  final String source;
  final DateTime scheduledFor;

  const OutboundMessage({
    required this.id,
    required this.recipientName,
    required this.phone,
    required this.body,
    required this.status,
    required this.source,
    required this.scheduledFor,
  });

  factory OutboundMessage.fromJson(Map<String, dynamic> json) => OutboundMessage(
        id: json['id'],
        recipientName: json['recipient_name'],
        phone: json['phone'],
        body: json['body'],
        status: json['status'] ?? 'ready',
        source: json['source'] ?? 'manual',
        scheduledFor: DateTime.parse(json['scheduled_for']),
      );
}

class MessageBatch {
  final String id;
  final String module;
  final String status;
  final DateTime? createdAt;
  final List<OutboundMessage> messages;

  const MessageBatch({
    required this.id,
    required this.module,
    required this.status,
    this.createdAt,
    this.messages = const [],
  });

  factory MessageBatch.fromJson(Map<String, dynamic> json) => MessageBatch(
        id: json['id'],
        module: json['module'],
        status: json['status'] ?? 'pending',
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
        messages: (json['messages'] as List? ?? [])
            .map((e) => OutboundMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String get sourceLabel {
    if (messages.isEmpty) return 'Manual';
    final source = messages.first.source;
    return switch (source) {
      'reminder' => 'Recordatorios',
      'waitlist' => 'Lista de espera',
      'feedback' => 'Feedback',
      _ => 'Manual',
    };
  }
}

class WaitlistEntry {
  final String id;
  final String? clientId;
  final String clientName;
  final String? phone;
  final String? serviceName;
  final String? notes;
  final String status;
  final DateTime createdAt;

  const WaitlistEntry({
    required this.id,
    this.clientId,
    required this.clientName,
    this.phone,
    this.serviceName,
    this.notes,
    required this.status,
    required this.createdAt,
  });

  factory WaitlistEntry.fromJson(Map<String, dynamic> json) => WaitlistEntry(
        id: json['id'],
        clientId: json['client_id'],
        clientName: json['client_name'],
        phone: json['phone'],
        serviceName: json['service_name'],
        notes: json['notes'],
        status: json['status'] ?? 'waiting',
        createdAt: DateTime.parse(json['created_at']),
      );
}
