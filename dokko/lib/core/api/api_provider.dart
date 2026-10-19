import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_client.dart';
import '../../super_admin/providers/super_admin_provider.dart';

final apiClientProvider = Provider<DokkoApiClient>((ref) {
  final supportTenantId = ref.watch(superAdminAuthProvider).supportTenantId;
  final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
  return DokkoApiClient(baseUrl: baseUrl, supportTenantId: supportTenantId);
});
