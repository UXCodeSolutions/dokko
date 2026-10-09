import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared_components/pos/pos_data_source.dart';
import '../../../shared_components/pos/pos_screen.dart';

/// POS del Módulo Salón/Barbería: reutiliza el componente POS compartido de
/// FASE 13 con el catálogo de productos del salón (FASE 22).
class SalonPosScreen extends ConsumerWidget {
  const SalonPosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PosScreen(dataSource: ref.watch(salonPosDataSourceProvider));
  }
}