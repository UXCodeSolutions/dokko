import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_provider.dart';
import '../../../core/api/api_client.dart';
import 'models/realestate_models.dart';

final realEstateApiProvider = Provider<RealEstateApi>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RealEstateApi(apiClient);
});

class RealEstateApi {
  final DokkoApiClient _apiClient;

  RealEstateApi(this._apiClient);

  Future<List<RealEstateProperty>> getProperties({String? status}) async {
    final query = status != null ? '?status=$status' : '';
    final res = await _apiClient.get('/realestate/properties$query');
    return (res as List).map((e) => RealEstateProperty.fromJson(e)).toList();
  }

  Future<RealEstateProperty> createProperty(Map<String, dynamic> data) async {
    final res = await _apiClient.post('/realestate/properties', body: data);
    return RealEstateProperty.fromJson(res);
  }

  Future<RealEstateProperty> updateProperty(String id, Map<String, dynamic> data) async {
    final res = await _apiClient.patch('/realestate/properties/$id', body: data);
    return RealEstateProperty.fromJson(res);
  }

  Future<void> deleteProperty(String id) async {
    await _apiClient.delete('/realestate/properties/$id');
  }

  // ── Leads ──────────────────────────────────────────────────────────────────
  Future<List<RealEstateLead>> getLeads({String? status}) async {
    final query = status != null ? '?status=$status' : '';
    final res = await _apiClient.get('/realestate/leads$query');
    return (res as List).map((e) => RealEstateLead.fromJson(e)).toList();
  }

  Future<RealEstateLead> createLead(Map<String, dynamic> data) async {
    final res = await _apiClient.post('/realestate/leads', body: data);
    return RealEstateLead.fromJson(res);
  }

  Future<RealEstateLead> updateLead(String id, Map<String, dynamic> data) async {
    final res = await _apiClient.patch('/realestate/leads/$id', body: data);
    return RealEstateLead.fromJson(res);
  }

  Future<void> deleteLead(String id) async {
    await _apiClient.delete('/realestate/leads/$id');
  }

  // FASE 25 — Ley 172-13: exportación de datos personales de un lead.
  Future<Map<String, dynamic>> exportLeadData(String id) async {
    return await _apiClient.get('/realestate/leads/$id/export-data');
  }

  // ── Agents ─────────────────────────────────────────────────────────────────
  Future<List<RealEstateAgent>> getAgents() async {
    final res = await _apiClient.get('/realestate/agents');
    return (res as List).map((e) => RealEstateAgent.fromJson(e)).toList();
  }

  Future<RealEstateAgent> createAgent(Map<String, dynamic> data) async {
    final res = await _apiClient.post('/realestate/agents', body: data);
    return RealEstateAgent.fromJson(res);
  }

  Future<RealEstateAgent> updateAgent(String id, Map<String, dynamic> data) async {
    final res = await _apiClient.patch('/realestate/agents/$id', body: data);
    return RealEstateAgent.fromJson(res);
  }

  // ── Commissions ────────────────────────────────────────────────────────────
  Future<List<RealEstateCommission>> getCommissions() async {
    final res = await _apiClient.get('/realestate/commissions');
    return (res as List).map((e) => RealEstateCommission.fromJson(e)).toList();
  }

  Future<RealEstateCommission> createCommission(Map<String, dynamic> data) async {
    final res = await _apiClient.post('/realestate/commissions', body: data);
    return RealEstateCommission.fromJson(res);
  }

  Future<RealEstateCommission> updateCommission(String id, Map<String, dynamic> data) async {
    final res = await _apiClient.patch('/realestate/commissions/$id', body: data);
    return RealEstateCommission.fromJson(res);
  }
}


