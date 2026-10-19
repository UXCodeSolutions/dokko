import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_empty_state.dart';

class ModulesCatalogScreen extends ConsumerStatefulWidget {
  const ModulesCatalogScreen({super.key});

  @override
  ConsumerState<ModulesCatalogScreen> createState() =>
      _ModulesCatalogScreenState();
}

class _ModulesCatalogScreenState extends ConsumerState<ModulesCatalogScreen> {
  List<Map<String, dynamic>> _modules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('system_modules')
          .select('*');
      if (mounted) {
        setState(() {
          _modules = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showModuleDetails(BuildContext context, Map<String, dynamic> module) {
    final slug = module['slug']?.toString() ?? '';
    final def = _getModuleDefinition(slug, module);

    showDialog(
      context: context,
      builder: (ctx) => _ModuleDetailDialog(module: module, definition: def),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DokkoTokens.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Módulos de la Plataforma',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: DokkoTokens.text,
                    ),
                  ),
                  SizedBox(height: DokkoTokens.space4),
                  Text(
                    'Haz clic en cualquier módulo para conocer a fondo sus capacidades, funciones y herramientas.',
                    style: TextStyle(
                      fontSize: 14,
                      color: DokkoTokens.text2,
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Actualizar lista',
                icon: const Icon(Icons.refresh_rounded, color: DokkoTokens.text2),
                onPressed: _fetchData,
              ),
            ],
          ),
          const SizedBox(height: DokkoTokens.space24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _modules.isEmpty
                    ? const DokkoEmptyState(
                        icon: Icons.view_module_rounded,
                        message: 'No hay módulos registrados en el sistema.',
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final isGrid = width >= 800;

                          if (!isGrid) {
                            return ListView.separated(
                              itemCount: _modules.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: DokkoTokens.space16),
                              itemBuilder: (context, index) {
                                final module = _modules[index];
                                final def = _getModuleDefinition(
                                    module['slug']?.toString() ?? '', module);
                                return _ModuleCard(
                                  module: module,
                                  definition: def,
                                  onTap: () => _showModuleDetails(context, module),
                                );
                              },
                            );
                          }

                          return GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 460,
                              mainAxisSpacing: DokkoTokens.space20,
                              crossAxisSpacing: DokkoTokens.space20,
                              childAspectRatio: 1.45,
                            ),
                            itemCount: _modules.length,
                            itemBuilder: (context, index) {
                              final module = _modules[index];
                              final def = _getModuleDefinition(
                                  module['slug']?.toString() ?? '', module);
                              return _ModuleCard(
                                module: module,
                                definition: def,
                                onTap: () => _showModuleDetails(context, module),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tarjeta de Módulo Interactiva
// ─────────────────────────────────────────────────────────────
class _ModuleCard extends StatefulWidget {
  final Map<String, dynamic> module;
  final _ModuleDefinition definition;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.module,
    required this.definition,
    required this.onTap,
  });

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final def = widget.definition;
    final color = def.color;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: DokkoTokens.bg,
            borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
            border: Border.all(
              color: _hovered ? color.withValues(alpha: 0.6) : DokkoTokens.line,
              width: _hovered ? 1.5 : 1.0,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de color superior
              Container(height: 3, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(DokkoTokens.space20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabecera: Icono + Título + Slug
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius:
                                  BorderRadius.circular(DokkoTokens.radiusMd),
                              border: Border.all(
                                color: color.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(def.icon, color: color, size: 24),
                          ),
                          const SizedBox(width: DokkoTokens.space12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.module['name'] ?? def.title,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: DokkoTokens.text,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: DokkoTokens.surface,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: DokkoTokens.line),
                                  ),
                                  child: Text(
                                    'slug: ${widget.module['slug']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: DokkoTokens.text3,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DokkoTokens.space16),

                      // Descripción
                      Text(
                        widget.module['description'] ?? def.subtitle,
                        style: const TextStyle(
                          color: DokkoTokens.text2,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),

                      // Pills de características clave
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: def.highlights.take(3).map((h) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: DokkoTokens.surface,
                              borderRadius:
                                  BorderRadius.circular(DokkoTokens.radiusSm),
                              border: Border.all(
                                color: DokkoTokens.lineStrong,
                              ),
                            ),
                            child: Text(
                              h,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: DokkoTokens.text2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: DokkoTokens.space16),

                      // Botón visual para explorar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Explorar lo que ofrece',
                            style: TextStyle(
                              color: _hovered ? color : DokkoTokens.text3,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: _hovered ? color : DokkoTokens.text3,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Modal Detallado con Toda la Información del Módulo
// ─────────────────────────────────────────────────────────────
class _ModuleDetailDialog extends StatelessWidget {
  final Map<String, dynamic> module;
  final _ModuleDefinition definition;

  const _ModuleDetailDialog({
    required this.module,
    required this.definition,
  });

  @override
  Widget build(BuildContext context) {
    final def = definition;
    final color = def.color;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 740),
        decoration: BoxDecoration(
          color: DokkoTokens.bg,
          borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
          border: Border.all(color: DokkoTokens.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Header del diálogo
            Container(
              padding: const EdgeInsets.all(DokkoTokens.space20),
              decoration: BoxDecoration(
                color: DokkoTokens.surface,
                border: const Border(bottom: BorderSide(color: DokkoTokens.line)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Icon(def.icon, color: color, size: 26),
                  ),
                  const SizedBox(width: DokkoTokens.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              module['name'] ?? def.title,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: DokkoTokens.text,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Módulo Activo',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          def.subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: DokkoTokens.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: DokkoTokens.text3, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Contenido escroleable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(DokkoTokens.space24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sección 1: Propósito y Función
                    const Text(
                      'FUNCIÓN PRINCIPAL',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: DokkoTokens.text3,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: DokkoTokens.space8),
                    Container(
                      padding: const EdgeInsets.all(DokkoTokens.space16),
                      decoration: BoxDecoration(
                        color: DokkoTokens.surface,
                        borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
                        border: Border.all(color: DokkoTokens.lineStrong),
                      ),
                      child: Text(
                        def.function,
                        style: const TextStyle(
                          color: DokkoTokens.text,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: DokkoTokens.space24),

                    // Sección 2: Lo que Ofrece (Características y Capacidades)
                    const Text(
                      'LO QUE OFRECE (FUNCIONALIDADES CLAVE)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: DokkoTokens.text3,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: DokkoTokens.space12),
                    ...def.features.map((feat) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: DokkoTokens.space12),
                        padding: const EdgeInsets.all(DokkoTokens.space16),
                        decoration: BoxDecoration(
                          color: DokkoTokens.bg,
                          borderRadius:
                              BorderRadius.circular(DokkoTokens.radiusMd),
                          border: Border.all(color: DokkoTokens.line),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(DokkoTokens.radiusSm),
                              ),
                              child: Icon(feat.icon, color: color, size: 18),
                            ),
                            const SizedBox(width: DokkoTokens.space12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    feat.title,
                                    style: const TextStyle(
                                      color: DokkoTokens.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    feat.description,
                                    style: const TextStyle(
                                      color: DokkoTokens.text2,
                                      fontSize: 12.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: DokkoTokens.space20),

                    // Sección 3: Público Objetivo
                    const Text(
                      'DISEÑADO PARA',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: DokkoTokens.text3,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: DokkoTokens.space12),
                    Wrap(
                      spacing: DokkoTokens.space8,
                      runSpacing: DokkoTokens.space8,
                      children: def.targetAudience.map((target) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: DokkoTokens.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: DokkoTokens.lineStrong),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded,
                                  size: 14, color: color),
                              const SizedBox(width: 6),
                              Text(
                                target,
                                style: const TextStyle(
                                  color: DokkoTokens.text,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Footer con botón de cerrar
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: DokkoTokens.space20, vertical: DokkoTokens.space12),
              decoration: const BoxDecoration(
                color: DokkoTokens.surface,
                border: Border(top: BorderSide(color: DokkoTokens.line)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DokkoButton(
                    label: 'Entendido',
                    variant: DokkoButtonVariant.primary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Modelos y Datos Enriquecidos de Cada Módulo
// ─────────────────────────────────────────────────────────────
class _ModuleFeatureItem {
  final IconData icon;
  final String title;
  final String description;

  const _ModuleFeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _ModuleDefinition {
  final String title;
  final String subtitle;
  final String function;
  final IconData icon;
  final Color color;
  final List<String> highlights;
  final List<_ModuleFeatureItem> features;
  final List<String> targetAudience;

  const _ModuleDefinition({
    required this.title,
    required this.subtitle,
    required this.function,
    required this.icon,
    required this.color,
    required this.highlights,
    required this.features,
    required this.targetAudience,
  });
}

_ModuleDefinition _getModuleDefinition(
    String slug, Map<String, dynamic> rawModule) {
  switch (slug) {
    case 'gym':
      return const _ModuleDefinition(
        title: 'Gimnasio y Centros Fitness',
        subtitle: 'Gestión integral de membresías, acceso e inventario deportivo',
        function:
            'Digitaliza el control de acceso y check-in de socios en tiempo real, gestiona membresías recurrentes con alertas de vencimiento, administra entrenadores y vende productos o suplementos con control de stock instantáneo.',
        icon: Icons.fitness_center_rounded,
        color: Color(0xFFFF9A3C),
        highlights: [
          'Membresías Recurrentes',
          'Check-ins de Acceso',
          'Punto de Venta POS',
          'Entrenadores',
        ],
        features: [
          _ModuleFeatureItem(
            icon: Icons.card_membership_rounded,
            title: 'Control de Membresías y Pagos',
            description:
                'Configuración de planes mensuales, trimestrales y anuales con registro de cobros y estados de suscripción.',
          ),
          _ModuleFeatureItem(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Check-in y Control de Asistencia',
            description:
                'Validación rápida del socio en la entrada verificando en segundos si su membresía está activa.',
          ),
          _ModuleFeatureItem(
            icon: Icons.point_of_sale_rounded,
            title: 'Punto de Venta (POS) & Inventario',
            description:
                'Catálogo de bebidas, suplementos y accesorios con descuento de existencias automático tras cada venta.',
          ),
          _ModuleFeatureItem(
            icon: Icons.badge_rounded,
            title: 'Gestión de Entrenadores y Personal',
            description:
                'Registro de instructores, control de turnos y supervisión de clientes asignados.',
          ),
          _ModuleFeatureItem(
            icon: Icons.analytics_outlined,
            title: 'Historial y Métricas de Afluencia',
            description:
                'Monitoreo de horas de mayor concurrencia y retención de miembros.',
          ),
        ],
        targetAudience: [
          'Gimnasios Tradicionales',
          'Boxes de Crossfit',
          'Estudios de Pilates & Yoga',
          'Centros de Entrenamiento Funcional',
        ],
      );

    case 'salon':
      return const _ModuleDefinition(
        title: 'Salón de Belleza, Barbería y Spa',
        subtitle: 'Agenda interactiva, catálogo de servicios y fichas de clientes',
        function:
            'Optimiza la programación de citas con calendario en vivo, calcula comisiones automáticamente para estilistas y barberos, reduce cancelaciones mediante listas de espera y registra el historial y fórmulas de cada cliente.',
        icon: Icons.content_cut_rounded,
        color: Color(0xFFD946EF),
        highlights: [
          'Agenda de Citas en Vivo',
          'Catálogo de Servicios',
          'Fichas de Clientes',
          'Lista de Espera',
        ],
        features: [
          _ModuleFeatureItem(
            icon: Icons.calendar_month_rounded,
            title: 'Agenda de Citas en Tiempo Real',
            description:
                'Visualización de turnos por profesional, horarios ocupados y programación de servicios sin solapamientos.',
          ),
          _ModuleFeatureItem(
            icon: Icons.spa_rounded,
            title: 'Catálogo de Servicios & Comisiones',
            description:
                'Servicios con tiempos estimados de atención y porcentajes automáticos de comisión para cada estilista.',
          ),
          _ModuleFeatureItem(
            icon: Icons.face_rounded,
            title: 'Ficha Histórica del Cliente',
            description:
                'Historial de visitas previas, fórmulas de coloración capilar, preferencias y datos de contacto.',
          ),
          _ModuleFeatureItem(
            icon: Icons.hourglass_top_rounded,
            title: 'Lista de Espera Dinámica',
            description:
                'Reasigna rápidamente turnos cancelados a clientes esperando disponibilidad.',
          ),
          _ModuleFeatureItem(
            icon: Icons.shopping_bag_outlined,
            title: 'Venta de Productos y Cuidado Personal',
            description:
                'Control de inventario para champús, aceites y cosméticos comercializados en el salón.',
          ),
        ],
        targetAudience: [
          'Salones de Belleza',
          'Barberías Modernas',
          'Spas & Estéticas',
          'Centros de Uñas y Pestañas',
        ],
      );

    case 'real_estate':
    case 'realestate':
      return const _ModuleDefinition(
        title: 'Inmobiliaria y Bienes Raíces',
        subtitle: 'Inventario de inmuebles, CRM de prospectos y liquidación de comisiones',
        function:
            'Centraliza el catálogo completo de propiedades para venta y alquiler, administra el embudo de ventas de clientes potenciales (leads) y automatiza el cálculo de comisiones para asesores y agentes inmobiliarios.',
        icon: Icons.home_work_rounded,
        color: Color(0xFF38BDF8),
        highlights: [
          'Catálogo de Inmuebles',
          'CRM de Leads',
          'Comisiones de Agentes',
          'Historial de Visitas',
        ],
        features: [
          _ModuleFeatureItem(
            icon: Icons.apartment_rounded,
            title: 'Catálogo de Propiedades',
            description:
                'Ficha completa de inmuebles con metraje, habitaciones, baños, precio, estado y fotos.',
          ),
          _ModuleFeatureItem(
            icon: Icons.filter_alt_rounded,
            title: 'Embudo de Clientes Potenciales (CRM)',
            description:
                'Captación y seguimiento de prospectos desde la primera consulta hasta el cierre de la firma.',
          ),
          _ModuleFeatureItem(
            icon: Icons.real_estate_agent_rounded,
            title: 'Directorio de Asesores Inmobiliarios',
            description:
                'Asignación de cartera de propiedades a agentes con control de licencia profesional.',
          ),
          _ModuleFeatureItem(
            icon: Icons.paid_rounded,
            title: 'Control y Liquidación de Comisiones',
            description:
                'Cálculo exacto del porcentaje de comisión pactado por venta o arrendamiento cerrado.',
          ),
          _ModuleFeatureItem(
            icon: Icons.event_available_rounded,
            title: 'Coordinación de Visitas',
            description:
                'Registro y calendarización de recorridos presenciales con clientes interesados.',
          ),
        ],
        targetAudience: [
          'Agencias Inmobiliarias',
          'Desarrolladoras y Constructoras',
          'Corredores de Propiedades Independientes',
          'Administradoras de Alquileres',
        ],
      );

    default:
      return _ModuleDefinition(
        title: rawModule['name'] ?? slug.toUpperCase(),
        subtitle: rawModule['description'] ?? 'Módulo operativo de Dokko',
        function: rawModule['description'] ??
            'Módulo de gestión especializado para operaciones comerciales y administración de negocios.',
        icon: Icons.dashboard_rounded,
        color: DokkoTokens.accentDefault,
        highlights: const ['Gestión Integral', 'Operaciones', 'Seguridad'],
        features: const [
          _ModuleFeatureItem(
            icon: Icons.check_circle_outline_rounded,
            title: 'Aislamiento de Datos por Tenant',
            description:
                'Seguridad mediante políticas Row Level Security (RLS) en la base de datos.',
          ),
          _ModuleFeatureItem(
            icon: Icons.settings_rounded,
            title: 'Panel de Administración',
            description:
                'Herramientas personalizadas según el flujo de trabajo de la industria.',
          ),
        ],
        targetAudience: const ['Empresas y Negocios en Crecimiento'],
      );
  }
}
