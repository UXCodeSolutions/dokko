import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_card.dart';
import '../../../core/widgets/dokko_empty_state.dart';
import '../data/models/realestate_models.dart';
import '../data/realestate_api.dart';

final propertiesProvider = FutureProvider<List<RealEstateProperty>>((ref) async {
  final api = ref.read(realEstateApiProvider);
  return api.getProperties();
});

class PropertiesScreen extends ConsumerWidget {
  const PropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(propertiesProvider);

    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      appBar: AppBar(
        title: const Text('Propiedades', style: TextStyle(color: DokkoTokens.text)),
        backgroundColor: DokkoTokens.surface,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                context.push('/real_estate/properties/new');
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva Propiedad'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DokkoTokens.accentDefault,
                foregroundColor: Colors.white,
              ),
            ),
          )
        ],
      ),
      body: propertiesAsync.when(
        data: (properties) {
          if (properties.isEmpty) {
            return const DokkoEmptyState(
              icon: Icons.home_work_outlined,
              message: 'No tienes propiedades registradas.\nAgrega tu primer inmueble.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(DokkoTokens.space16),
            itemCount: properties.length,
            itemBuilder: (context, index) {
              final prop = properties[index];
              return _PropertyCard(property: prop);
            },
          );
        },
        loading: () => _buildSkeleton(),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: DokkoTokens.text2))),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(DokkoTokens.space16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: DokkoTokens.space16),
          height: 120,
          decoration: BoxDecoration(
            color: DokkoTokens.surface2,
            borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
          ),
        );
      },
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final RealEstateProperty property;

  const _PropertyCard({required this.property});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DokkoTokens.space16),
      child: DokkoCard(
        padding: const EdgeInsets.all(DokkoTokens.space16),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: DokkoTokens.surface2,
              borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
              image: property.images.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(property.images.first),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: property.images.isEmpty
                ? const Icon(Icons.image_not_supported_rounded, color: DokkoTokens.text3)
                : null,
          ),
          const SizedBox(width: DokkoTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        property.title,
                        style: const TextStyle(
                          color: DokkoTokens.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildStatusBadge(property.status),
                  ],
                ),
                const SizedBox(height: DokkoTokens.space4),
                Text(
                  '${property.propertyType.toUpperCase()} - ${property.operationType.toUpperCase()}',
                  style: const TextStyle(color: DokkoTokens.text2, fontSize: 12),
                ),
                const SizedBox(height: DokkoTokens.space8),
                Text(
                  _getPriceFormatted(),
                  style: const TextStyle(
                    color: DokkoTokens.accentDefault,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: DokkoTokens.space8),
                Row(
                  children: [
                    _buildFeature(Icons.bed_rounded, '${property.bedrooms ?? 0}'),
                    const SizedBox(width: DokkoTokens.space16),
                    _buildFeature(Icons.bathtub_rounded, '${property.bathrooms ?? 0}'),
                    const SizedBox(width: DokkoTokens.space16),
                    _buildFeature(Icons.square_foot_rounded, '${property.squareMetersBuilt ?? 0} m²'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  String _getPriceFormatted() {
    if (property.operationType == 'sale' || property.operationType == 'both') {
      return '${property.currency ?? "\$"} ${property.priceSale?.toStringAsFixed(2) ?? "0.00"}';
    } else {
      return '${property.currency ?? "\$"} ${property.priceRent?.toStringAsFixed(2) ?? "0.00"} / mes';
    }
  }

  Widget _buildFeature(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: DokkoTokens.text3),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: DokkoTokens.text2, fontSize: 12)),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    
    switch (status) {
      case 'available':
        bg = Colors.green.withValues(alpha: 0.2);
        fg = Colors.green;
        label = 'Disponible';
        break;
      case 'reserved':
        bg = Colors.orange.withValues(alpha: 0.2);
        fg = Colors.orange;
        label = 'Reservado';
        break;
      case 'sold':
        bg = DokkoTokens.accentDefault.withValues(alpha: 0.2);
        fg = DokkoTokens.accentDefault;
        label = 'Vendido';
        break;
      default:
        bg = DokkoTokens.surface2;
        fg = DokkoTokens.text2;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DokkoTokens.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
