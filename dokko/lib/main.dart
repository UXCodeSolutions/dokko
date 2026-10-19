import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/routing/app_router.dart';
import 'core/theme/brand_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    const ProviderScope(
      child: DokkoApp(),
    ),
  );
}

class DokkoApp extends ConsumerWidget {
  const DokkoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final brand = ref.watch(brandColorsProvider);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: brand.accent,
      brightness: Brightness.dark,
      surface: const Color(0xFF111113),
    );

    return MaterialApp.router(
      title: 'Dokko',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        extensions: [brand],
        textTheme: const TextTheme(
          bodySmall: TextStyle(fontSize: 13.0, color: Color(0xFF8B8B92)),
          bodyMedium: TextStyle(fontSize: 14.5, color: Color(0xFFEDEDEF)),
          bodyLarge: TextStyle(fontSize: 16.0, color: Color(0xFFEDEDEF)),
          titleSmall: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Color(0xFFEDEDEF)),
          titleMedium: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: Color(0xFFEDEDEF)),
          titleLarge: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w700, color: Color(0xFFEDEDEF)),
          headlineSmall: TextStyle(fontSize: 25.0, fontWeight: FontWeight.w700, color: Color(0xFFEDEDEF)),
          labelSmall: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: Color(0xFF8B8B92)),
        ),
      ),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final width = mediaQuery.size.width;
        final isMobile = width < 800;

        // Factor de escala calculado de forma responsiva para teléfono y laptop:
        // En Móvil (<800px):
        // Mínimo estricto de 1.08x (evita palabras diminutas en pantallas pequeñas)
        // Máximo estricto de 1.20x (evita desbordamientos o textos excesivamente grandes).
        // En Laptop / Escritorio (>=800px):
        // Mínimo estricto de 1.04x (mejora la legibilidad en pantallas de alta densidad)
        // Máximo estricto de 1.16x (mantiene la elegancia sin gigantismo).
        final double baseResponsiveFactor;
        if (isMobile) {
          // Escala fluida para teléfonos (320px a 799px)
          final progress = ((width - 320) / (800 - 320)).clamp(0.0, 1.0);
          baseResponsiveFactor = (1.10 + (progress * 0.08)).clamp(1.08, 1.20);
        } else {
          // Escala fluida para laptops y monitores (800px a 1600px)
          final progress = ((width - 800) / (1600 - 800)).clamp(0.0, 1.0);
          baseResponsiveFactor = (1.05 + (progress * 0.09)).clamp(1.04, 1.16);
        }

        // Se combina con la preferencia de escala del sistema/navegador respetando los límites
        final systemScale = mediaQuery.textScaler.scale(10.0) / 10.0;
        final clampedScale = (baseResponsiveFactor * systemScale).clamp(
          isMobile ? 1.08 : 1.04,
          isMobile ? 1.22 : 1.16,
        );

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(clampedScale),
          ),
          child: child ?? const SizedBox(),
        );
      },
      routerConfig: router,
    );
  }
}
