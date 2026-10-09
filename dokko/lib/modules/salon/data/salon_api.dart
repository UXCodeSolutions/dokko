import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_provider.dart';
import '../../../core/api/api_client.dart';
import 'models/salon_models.dart';

final salonApiProvider = Provider<SalonApi>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SalonApi(apiClient);
});

class SalonApi {
  final DokkoApiClient _apiClient;

  SalonApi(this._apiClient);

  // ── Services ──────────────────────────────────────────────────────────────
  Future<List<SalonService>> getServices() async {
    final res = await _apiClient.get('/salon/services');
    return (res as List).map((e) => SalonService.fromJson(e)).toList();
  }

  Future<SalonService> createService(Map<String, dynamic> data) async {
    final res = await _apiClient.post('/salon/services', body: data);
    return SalonService.fromJson(res);
  }

  // ── Employees ─────────────────────────────────────────────────────────────
  Future<List<SalonEmployee>> getEmployees() async {
    final res = await _apiClient.get('/salon/employees');
    return (res as List).map((e) => SalonEmployee.fromJson(e)).toList();
  }

  Future<SalonEmployee> createEmployee(Map<String, dynamic> data) async {
    final res = await _apiClient.post('/salon/employees', body: data);
    return SalonEmployee.fromJson(res);
  }

  // ── Clients ───────────────────────────────────────────────────────────────
  Future<List<SalonClient>> getClients() async {
    final res = await _apiClient.get('/salon/clients');
    return (res as List).map((e) => SalonClient.fromJson(e)).toList();
  }

  Future<SalonClient> createClient(Map<String, dynamic> data) async {
    final res = await _apiClient.post('/salon/clients', body: data);
    return SalonClient.fromJson(res);
  }

  Future<SalonClient> updateClient(String id, Map<String, dynamic> data) async {
    final res = await _apiClient.patch('/salon/clients/$id', body: data);
    return SalonClient.fromJson(res);
  }

  Future<Map<String, dynamic>> exportClientData(String id) async {
    return await _apiClient.get('/salon/clients/$id/export-data');
  }

  Future<void> deleteClient(String id) async {
    await _apiClient.delete('/salon/clients/$id');
  }

  // ── Appointments ──────────────────────────────────────────────────────────
  Future<List<SalonAppointment>> getAppointments() async {
    final res = await _apiClient.get('/salon/appointments');
    return (res as List).map((e) => SalonAppointment.fromJson(e)).toList();
  }

  Future<SalonAppointment> createAppointment(Map<String, dynamic> data) async {
    final res = await _apiClient.post('/salon/appointments', body: data);
    return SalonAppointment.fromJson(res);
  }

  Future<SalonAppointment> updateAppointment(String id, Map<String, dynamic> data) async {
    final res = await _apiClient.patch('/salon/appointments/$id', body: data);
    return SalonAppointment.fromJson(res);
  }

  // ── Products (POS) — devuelven JSON crudo para el componente POS compartido ──
  Future<List<dynamic>> getProducts() async {
    final res = await _apiClient.get('/salon/products');
    return res as List;
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    final res = await _apiClient.post('/salon/products', body: data);
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProduct(String id, Map<String, dynamic> data) async {
    final res = await _apiClient.patch('/salon/products/$id', body: data);
    return res as Map<String, dynamic>;
  }

  // ── Sales (POS) ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createSale(Map<String, dynamic> data) async {
    final res = await _apiClient.post('/salon/sales', body: data);
    return res as Map<String, dynamic>;
  }

  Future<List<dynamic>> getSales() async {
    final res = await _apiClient.get('/salon/sales');
    return res as List;
  }

  // ── Reports (POS) ───────────────────────────────────────────────────────────
  Future<List<dynamic>> getCommissionSummary({int days = 30}) async {
    final res = await _apiClient.get('/salon/reports/commissions?days=$days');
    return res as List;
  }

  Future<List<dynamic>> getRevenueReport({int days = 30}) async {
    final res = await _apiClient.get('/salon/reports/revenue?days=$days');
    return res as List;
  }

  // ── Mensajería (FASE 28) ────────────────────────────────────────────────────
  Future<MessagingSettings> getMessagingSettings() async {
    final res = await _apiClient.get('/messaging/settings?module=salon');
    final data = res as Map<String, dynamic>;
    return MessagingSettings.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<MessagingSettings> updateMessagingSettings(
    MessagingSettings settings,
  ) async {
    final res = await _apiClient.put('/messaging/settings', body: {
      'module': 'salon',
      'data': settings.toJson(),
    });
    final data = res as Map<String, dynamic>;
    return MessagingSettings.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getMessagingTemplates() async {
    final res = await _apiClient.get('/messaging/templates?module=salon');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveMessagingTemplate({
    required String key,
    String? label,
    required String body,
  }) async {
    await _apiClient.put('/messaging/templates', body: {
      'module': 'salon',
      'key': key,
      'label': label,
      'body': body,
    });
  }

  Future<List<MessageBatch>> getMessagingPending() async {
    final res = await _apiClient.get('/messaging/pending?module=salon');
    final data = res as Map<String, dynamic>;
    final batches = (data['batches'] as List? ?? [])
        .map((e) => MessageBatch.fromJson(e as Map<String, dynamic>))
        .toList();
    return batches;
  }

  Future<Map<String, dynamic>> confirmBatch(String batchId) async {
    return (await _apiClient.post('/messaging/batches/$batchId/confirm'))
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelBatch(String batchId) async {
    return (await _apiClient.post('/messaging/batches/$batchId/cancel'))
        as Map<String, dynamic>;
  }

  Future<List<OutboundMessage>> getMessagingHistory({int limit = 50}) async {
    final res = await _apiClient.get(
        '/messaging/history?module=salon&limit=$limit');
    final data = res as Map<String, dynamic>;
    return (data['messages'] as List? ?? [])
        .map((e) => OutboundMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Waitlist (lista de espera, FASE 28) ─────────────────────────────────────
  Future<List<WaitlistEntry>> getWaitlist() async {
    final res = await _apiClient.get('/salon/waitlist');
    return (res as List)
        .map((e) => WaitlistEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WaitlistEntry> addWaitlist(Map<String, dynamic> data) async {
    final res = await _apiClient.post('/salon/waitlist', body: data);
    return WaitlistEntry.fromJson(res as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> updateWaitlist(
    String id,
    Map<String, dynamic> data,
  ) async {
    return (await _apiClient.patch('/salon/waitlist/$id', body: data))
        as Map<String, dynamic>;
  }

  Future<void> removeWaitlist(String id) async {
    await _apiClient.delete('/salon/waitlist/$id');
  }
}
