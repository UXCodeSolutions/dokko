import 'module_definition.dart';
import '../../modules/gym/gym_module.dart';
import '../../modules/real_estate/real_estate_module.dart';
import '../../modules/salon/salon_module.dart';

/// Registro global de módulos disponibles en la plataforma Dokko.
/// Solo los módulos listados aquí existen en la app.
/// El código de un módulo no activo nunca se instancia.
final Map<String, ModuleDefinition> availableModules = {
  'gym': GymModule(),
  'real_estate': RealEstateModule(),
  'salon': SalonModule(),
};

/// Obtiene el módulo activo por slug. Retorna null si no existe.
ModuleDefinition? getModule(String slug) => availableModules[slug];
