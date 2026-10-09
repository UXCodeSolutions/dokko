import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Normaliza un teléfono a dígitos E.164 (sin '+') para enlaces wa.me.
/// Espeja la lógica del backend (assume República Dominicana: 10 dígitos → '+1').
String? normalizePhoneToDigits(String? phone) {
  if (phone == null || phone.isEmpty) return null;
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('1') && digits.length == 11) return digits;
  if (digits.length == 10) return '1$digits';
  if (digits.length == 11 || digits.length == 12) return digits;
  return null;
}

/// Construye un enlace wa.me con el mensaje prefabricado (texto URL-encoded).
String buildWaDeepLink({required String phoneDigits, required String body}) {
  return 'https://wa.me/$phoneDigits?text=${Uri.encodeComponent(body)}';
}

/// Lanza una URL externa (deep-link de WhatsApp). Expuesto como Provider para
/// inyectar un no-op en los tests E2E.
typedef WaLauncher = Future<void> Function(String url);

Future<void> _defaultLauncher(String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok) throw StateError('No se pudo abrir $url');
}

final waLauncherProvider = Provider<WaLauncher>((ref) => _defaultLauncher);

/// Genera el enlace wa.me de un mensaje listo para enviar y lo abre con el
/// launcher configurado (deep-link hacia la app/web de WhatsApp).
Future<void> openWaDeepLink(
  WidgetRef ref, {
  required String phoneDigits,
  required String body,
}) async {
  final launcher = ref.read(waLauncherProvider);
  await launcher(buildWaDeepLink(phoneDigits: phoneDigits, body: body));
}