import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../modules/gym/data/gym_api.dart';
import '../../modules/salon/data/salon_api.dart';

/// Contrato de fuentes de datos para el componente POS compartido.
/// Un solo componente (ligado a la UI) reutilizado por FASE 13 (gym) y
/// FASE 22 (salón/barbería) con su propio catálogo, clientes y personal.
abstract class PosDataSource {
  String get title;

  String get customerLabel;

  bool get hasStaff;

  String get staffLabel;

  Future<List<dynamic>> fetchProducts();

  Future<List<dynamic>> fetchSales();

  /// Crea una venta. El mapa usa claves genéricas:
  /// `customer_id` (miembro/cliente), `staff_id` (estilista, si aplica),
  /// `payment_method`, `notes` e `items`.
  Future<Map<String, dynamic>> createSale(Map<String, dynamic> data);

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data);

  Future<Map<String, dynamic>> updateProduct(
      String id, Map<String, dynamic> data);

  Future<List<dynamic>> fetchCustomers();

  Future<List<dynamic>>? fetchStaff();
}

final gymPosDataSourceProvider = Provider<PosDataSource>((ref) {
  final api = ref.watch(gymApiProvider);
  return _GymPosDataSource(api);
});

final salonPosDataSourceProvider = Provider<PosDataSource>((ref) {
  final api = ref.watch(salonApiProvider);
  return _SalonPosDataSource(api);
});

class _GymPosDataSource implements PosDataSource {
  final GymApi _api;
  _GymPosDataSource(this._api);

  @override
  String get title => 'POS / Productos';

  @override
  String get customerLabel => 'Asignar a miembro (opcional)';

  @override
  bool get hasStaff => false;

  @override
  String get staffLabel => 'Asignar a estilista (opcional)';

  @override
  Future<List<dynamic>> fetchProducts() => _api.getProducts();

  @override
  Future<List<dynamic>> fetchSales() => _api.getSales();

  @override
  Future<Map<String, dynamic>> createSale(Map<String, dynamic> data) async {
    final payload = <String, dynamic>{
      'payment_method': data['payment_method'] ?? 'cash',
      'notes': data['notes'],
      'items': data['items'],
    };
    if (data['customer_id'] != null) {
      payload['member_id'] = data['customer_id'];
    }
    return _api.createSale(payload);
  }

  @override
  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) =>
      _api.createProduct(data);

  @override
  Future<Map<String, dynamic>> updateProduct(
          String id, Map<String, dynamic> data) =>
      _api.updateProduct(id, data);

  @override
  Future<List<dynamic>> fetchCustomers() async {
    final members = await _api.getMembers();
    return members.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Future<List<dynamic>>? fetchStaff() => null;
}

class _SalonPosDataSource implements PosDataSource {
  final SalonApi _api;
  _SalonPosDataSource(this._api);

  @override
  String get title => 'POS del Salón';

  @override
  String get customerLabel => 'Asignar a cliente (opcional)';

  @override
  bool get hasStaff => true;

  @override
  String get staffLabel => 'Asignar a estilista (opcional)';

  @override
  Future<List<dynamic>> fetchProducts() => _api.getProducts();

  @override
  Future<List<dynamic>> fetchSales() => _api.getSales();

  @override
  Future<Map<String, dynamic>> createSale(Map<String, dynamic> data) async {
    final payload = <String, dynamic>{
      'payment_method': data['payment_method'] ?? 'cash',
      'notes': data['notes'],
      'items': data['items'],
    };
    if (data['customer_id'] != null) {
      payload['client_id'] = data['customer_id'];
    }
    if (data['staff_id'] != null) {
      payload['employee_id'] = data['staff_id'];
    }
    return _api.createSale(payload);
  }

  @override
  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) =>
      _api.createProduct(data);

  @override
  Future<Map<String, dynamic>> updateProduct(
          String id, Map<String, dynamic> data) =>
      _api.updateProduct(id, data);

  @override
  Future<List<dynamic>> fetchCustomers() async {
    final clients = await _api.getClients();
    return clients.map((c) => c.toJson()).toList();
  }

  @override
  Future<List<dynamic>>? fetchStaff() async {
    final employees = await _api.getEmployees();
    return employees.map((e) => e.toJson()).toList();
  }
}