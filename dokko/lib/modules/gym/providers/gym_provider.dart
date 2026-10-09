import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/gym_api.dart';

final gymKpisProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(gymApiProvider);
  return await api.getDashboardKpis();
});

final gymMembersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(gymApiProvider);
  return await api.getMembers();
});

final gymChurnProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(gymApiProvider);
  return await api.getChurnOverview();
});

final gymEmployeesProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(gymApiProvider);
  return await api.getEmployees();
});
