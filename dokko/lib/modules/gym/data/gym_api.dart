import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_provider.dart';

final gymApiProvider = Provider<GymApi>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GymApi(apiClient);
});

class GymApi {
  final DokkoApiClient _apiClient;

  GymApi(this._apiClient);

  Future<Map<String, dynamic>> getDashboardKpis() async {
    return await _apiClient.get('/gym/dashboard/kpis');
  }

  Future<List<dynamic>> getMembers() async {
    return await _apiClient.get('/gym/members');
  }

  Future<Map<String, dynamic>> getMember(String id) async {
    return await _apiClient.get('/gym/members/$id');
  }

  Future<Map<String, dynamic>> createMember(Map<String, dynamic> data) async {
    return await _apiClient.post('/gym/members', body: data);
  }

  Future<Map<String, dynamic>> updateMember(String id, Map<String, dynamic> data) async {
    return await _apiClient.patch('/gym/members/$id', body: data);
  }

  Future<Map<String, dynamic>> exportMemberData(String id) async {
    return await _apiClient.get('/gym/members/$id/export-data');
  }

  Future<void> deleteMember(String id) async {
    await _apiClient.delete('/gym/members/$id');
  }

  Future<List<dynamic>> getMemberPayments(String memberId) async {
    return await _apiClient.get('/gym/members/$memberId/payments');
  }

  Future<Map<String, dynamic>> registerPayment(Map<String, dynamic> data) async {
    return await _apiClient.post('/gym/payments', body: data);
  }

  Future<List<dynamic>> getMembershipPlans() async {
    return await _apiClient.get('/gym/plans');
  }

  Future<Map<String, dynamic>> createPlan(Map<String, dynamic> data) async {
    return await _apiClient.post('/gym/plans', body: data);
  }

  Future<Map<String, dynamic>> updatePlan(String id, Map<String, dynamic> data) async {
    return await _apiClient.patch('/gym/plans/$id', body: data);
  }

  Future<void> deletePlan(String id) async {
    await _apiClient.delete('/gym/plans/$id');
  }

  Future<List<dynamic>> getTodaysCheckins() async {
    return await _apiClient.get('/gym/checkins/today');
  }

  Future<Map<String, dynamic>> checkIn(String memberId, {String? notes}) async {
    return await _apiClient.post('/gym/checkins', body: {
      'member_id': memberId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }

  // ── Products ────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getProducts() async {
    return await _apiClient.get('/gym/products');
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    return await _apiClient.post('/gym/products', body: data);
  }

  Future<Map<String, dynamic>> updateProduct(String id, Map<String, dynamic> data) async {
    return await _apiClient.patch('/gym/products/$id', body: data);
  }

  Future<void> deleteProduct(String id) async {
    await _apiClient.delete('/gym/products/$id');
  }

  // ── Sales ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createSale(Map<String, dynamic> data) async {
    return await _apiClient.post('/gym/sales', body: data);
  }

  Future<List<dynamic>> getSales() async {
    return await _apiClient.get('/gym/sales');
  }

  // ── Reports ────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getRevenueReport({int days = 30}) async {
    return await _apiClient.get('/gym/reports/revenue?days=$days');
  }

  Future<List<dynamic>> getCheckinsReport({int days = 30}) async {
    return await _apiClient.get('/gym/reports/checkins?days=$days');
  }

  Future<Map<String, dynamic>> getMembersStatusReport() async {
    return await _apiClient.get('/gym/reports/members/status');
  }

  // ── Churn / Revenue Recovery ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getChurnOverview() async {
    return await _apiClient.get('/gym/churn/overview');
  }

  Future<void> sendChurnReminder(String memberId) async {
    await _apiClient.post('/gym/churn/remind/$memberId');
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getGymSettings() async {
    return await _apiClient.get('/gym/settings');
  }

  Future<Map<String, dynamic>> updateGymSettings(Map<String, dynamic> data) async {
    return await _apiClient.patch('/gym/settings', body: data);
  }

  // ── Employees (FASE 15) ───────────────────────────────────────────────────

  Future<List<dynamic>> getEmployees() async {
    return await _apiClient.get('/gym/employees');
  }

  Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> data) async {
    return await _apiClient.post('/gym/employees', body: data);
  }

  Future<Map<String, dynamic>> updateEmployee(
      String id, Map<String, dynamic> data) async {
    return await _apiClient.patch('/gym/employees/$id', body: data);
  }

  Future<void> deleteEmployee(String id) async {
    await _apiClient.delete('/gym/employees/$id');
  }
}
