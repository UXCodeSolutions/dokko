import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import '../../super_admin/providers/super_admin_provider.dart';

final apiClientProvider = Provider<DokkoApiClient>((ref) {
  final supportTenantId = ref.watch(superAdminAuthProvider).supportTenantId;
  return DokkoApiClient(baseUrl: 'http://localhost:8000', supportTenantId: supportTenantId);
});
