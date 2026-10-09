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
      brightness: Brightness.light,
      surface: const Color(0xFFF8F8FA),
    );

    return MaterialApp.router(
      title: 'Dokko',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        extensions: [brand],
      ),
      routerConfig: router,
    );
  }
}
