import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../data/realestate_api.dart';

class PropertyWizardScreen extends ConsumerStatefulWidget {
  const PropertyWizardScreen({super.key});

  @override
  ConsumerState<PropertyWizardScreen> createState() => _PropertyWizardScreenState();
}

class _PropertyWizardScreenState extends ConsumerState<PropertyWizardScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();

  // Form Data
  String _title = '';
  String _description = '';
  String _propertyType = 'house';
  String _operationType = 'sale';
  double? _priceSale;
  double? _priceRent;
  int _bedrooms = 0;
  double _bathrooms = 0;
  double? _sqmBuilt;
  String _address = '';

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);
    
    try {
      final api = ref.read(realEstateApiProvider);
      await api.createProperty({
        'title': _title,
        'description': _description,
        'property_type': _propertyType,
        'operation_type': _operationType,
        'price_sale': _priceSale,
        'price_rent': _priceRent,
        'bedrooms': _bedrooms,
        'bathrooms': _bathrooms,
        'square_meters_built': _sqmBuilt,
        'address': _address,
      });
      if (mounted) {
        context.pop(); // Go back on success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Propiedad creada exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      appBar: AppBar(
        title: const Text('Nueva Propiedad', style: TextStyle(color: DokkoTokens.text)),
        backgroundColor: DokkoTokens.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: DokkoTokens.text),
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() => _currentStep++);
            } else {
              _submit();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            }
          },
          controlsBuilder: (context, details) {
            final isLastStep = _currentStep == 2;
            return Padding(
              padding: const EdgeInsets.only(top: DokkoTokens.space24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DokkoTokens.accentDefault,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isLastStep ? 'Crear Propiedad' : 'Siguiente'),
                    ),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: DokkoTokens.space16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : details.onStepCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Atrás', style: TextStyle(color: DokkoTokens.text)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Básicos'),
              content: _buildBasicStep(),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text('Características'),
              content: _buildFeaturesStep(),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text('Financiero'),
              content: _buildFinancialStep(),
              isActive: _currentStep >= 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          decoration: const InputDecoration(labelText: 'Título del Anuncio'),
          validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
          onSaved: (v) => _title = v ?? '',
        ),
        const SizedBox(height: DokkoTokens.space16),
        TextFormField(
          decoration: const InputDecoration(labelText: 'Descripción'),
          maxLines: 3,
          onSaved: (v) => _description = v ?? '',
        ),
        const SizedBox(height: DokkoTokens.space16),
        DropdownButtonFormField<String>(
          initialValue: _propertyType,
          decoration: const InputDecoration(labelText: 'Tipo de Inmueble'),
          items: const [
            DropdownMenuItem(value: 'house', child: Text('Casa')),
            DropdownMenuItem(value: 'apartment', child: Text('Apartamento')),
            DropdownMenuItem(value: 'commercial', child: Text('Comercial')),
            DropdownMenuItem(value: 'land', child: Text('Terreno')),
          ],
          onChanged: (v) => setState(() => _propertyType = v!),
        ),
        const SizedBox(height: DokkoTokens.space16),
        DropdownButtonFormField<String>(
          initialValue: _operationType,
          decoration: const InputDecoration(labelText: 'Tipo de Operación'),
          items: const [
            DropdownMenuItem(value: 'sale', child: Text('Venta')),
            DropdownMenuItem(value: 'rent', child: Text('Alquiler')),
            DropdownMenuItem(value: 'both', child: Text('Venta y Alquiler')),
          ],
          onChanged: (v) => setState(() => _operationType = v!),
        ),
      ],
    );
  }

  Widget _buildFeaturesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(labelText: 'Habitaciones'),
                keyboardType: TextInputType.number,
                initialValue: '0',
                onSaved: (v) => _bedrooms = int.tryParse(v ?? '0') ?? 0,
              ),
            ),
            const SizedBox(width: DokkoTokens.space16),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(labelText: 'Baños'),
                keyboardType: TextInputType.number,
                initialValue: '0',
                onSaved: (v) => _bathrooms = double.tryParse(v ?? '0') ?? 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: DokkoTokens.space16),
        TextFormField(
          decoration: const InputDecoration(labelText: 'Metros Cuadrados Construidos'),
          keyboardType: TextInputType.number,
          onSaved: (v) => _sqmBuilt = double.tryParse(v ?? ''),
        ),
        const SizedBox(height: DokkoTokens.space16),
        TextFormField(
          decoration: const InputDecoration(labelText: 'Dirección'),
          onSaved: (v) => _address = v ?? '',
        ),
      ],
    );
  }

  Widget _buildFinancialStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_operationType == 'sale' || _operationType == 'both') ...[
          TextFormField(
            decoration: const InputDecoration(labelText: 'Precio de Venta', prefixText: '\$ '),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (_operationType == 'sale' && (v == null || v.isEmpty)) return 'Requerido';
              return null;
            },
            onSaved: (v) => _priceSale = double.tryParse(v ?? ''),
          ),
          const SizedBox(height: DokkoTokens.space16),
        ],
        if (_operationType == 'rent' || _operationType == 'both') ...[
          TextFormField(
            decoration: const InputDecoration(labelText: 'Precio de Alquiler', prefixText: '\$ '),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (_operationType == 'rent' && (v == null || v.isEmpty)) return 'Requerido';
              return null;
            },
            onSaved: (v) => _priceRent = double.tryParse(v ?? ''),
          ),
          const SizedBox(height: DokkoTokens.space16),
        ],
      ],
    );
  }
}
