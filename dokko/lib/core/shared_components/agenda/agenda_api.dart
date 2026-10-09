import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/api_client.dart';
import '../../api/api_provider.dart';
import 'agenda_models.dart';

final agendaApiProvider = Provider<AgendaApi>((ref) {
  return AgendaApi(ref.read(apiClientProvider));
});

class AgendaApi {
  final DokkoApiClient _apiClient;

  AgendaApi(this._apiClient);

  // ── Resources ──────────────────────────────────────────────────────────────

  Future<List<AgendaResource>> getResources({String? module}) async {
    final query = module != null ? '?module=$module' : '';
    final List<dynamic> res = await _apiClient.get('/agenda/resources$query');
    return res.map((e) => AgendaResource.fromJson(e)).toList();
  }

  Future<AgendaResource> createResource(Map<String, dynamic> data) async {
    final res = await _apiClient.post('/agenda/resources', body: data);
    return AgendaResource.fromJson(res);
  }

  // ── Appointments ───────────────────────────────────────────────────────────

  Future<List<AgendaAppointment>> getAppointments({
    required DateTime startDate,
    required DateTime endDate,
    String? resourceId,
  }) async {
    final start = startDate.toUtc().toIso8601String();
    final end = endDate.toUtc().toIso8601String();
    
    String query = '?start_date=$start&end_date=$end';
    if (resourceId != null) query += '&resource_id=$resourceId';

    final List<dynamic> res = await _apiClient.get('/agenda/appointments$query');
    return res.map((e) => AgendaAppointment.fromJson(e)).toList();
  }

  Future<AgendaAppointment> createAppointment(Map<String, dynamic> data) async {
    final res = await _apiClient.post('/agenda/appointments', body: data);
    return AgendaAppointment.fromJson(res);
  }

  Future<AgendaAppointment> updateAppointment(String id, Map<String, dynamic> data) async {
    final res = await _apiClient.patch('/agenda/appointments/$id', body: data);
    return AgendaAppointment.fromJson(res);
  }

  Future<void> deleteAppointment(String id) async {
    await _apiClient.delete('/agenda/appointments/$id');
  }
}
