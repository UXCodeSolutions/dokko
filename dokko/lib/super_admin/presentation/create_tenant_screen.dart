import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_card.dart';
import '../../../core/widgets/dokko_input.dart';

class CreateTenantScreen extends ConsumerStatefulWidget {
  const CreateTenantScreen({super.key});

  @override
  ConsumerState<CreateTenantScreen> createState() => _CreateTenantScreenState();
}

class _CreateTenantScreenState extends ConsumerState<CreateTenantScreen> {
  final _nameCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _adminPasswordCtrl = TextEditingController();
  
  String? _selectedModule;
  List<Map<String, dynamic>> _availableModules = [];
  bool _isLoadingModules = true;
  bool _isLoading = false;

  Uint8List? _logoBytes;
  String? _logoExt;
  Color? _extractedPrimaryColor;
  Color? _extractedSecondaryColor;

  @override
  void initState() {
    super.initState();
    _fetchModules();
  }

  Future<void> _fetchModules() async {
    try {
      final res = await Supabase.instance.client
          .from('system_modules')
          .select('slug, name')
          .eq('is_active', true)
          .order('name');
      
      if (mounted) {
        setState(() {
          _availableModules = List<Map<String, dynamic>>.from(res);
          if (_availableModules.isNotEmpty) {
            _selectedModule = _availableModules.first['slug'];
          }
          _isLoadingModules = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingModules = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar módulos: $e')),
        );
      }
    }
  }

  Future<void> _pickLogo() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'svg', 'webp'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        setState(() {
          _logoBytes = bytes;
          _logoExt = file.extension ?? 'png';
          _extractedPrimaryColor = null;
          _extractedSecondaryColor = null;
        });
        _extractColor(bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seleccionando imagen: $e')),
        );
      }
    }
  }

  Color? _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      if (val != null) return Color(val);
    }
    return null;
  }

  Future<void> _extractColor(Uint8List imageBytes) async {
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/super-admin/brand/extract'),
      );
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'logo.${_logoExt ?? "png"}',
      ));
      final streamed = await request.send();
      if (streamed.statusCode == 200) {
        final respStr = await streamed.stream.bytesToString();
        final data = jsonDecode(respStr) as Map<String, dynamic>;
        final pColor = _hexToColor(data['primary_color'] as String?);
        final sColor = _hexToColor(data['secondary_color'] as String?);
        if (pColor != null && mounted) {
          setState(() {
            _extractedPrimaryColor = pColor;
            _extractedSecondaryColor = sColor ??
                HSLColor.fromColor(pColor).withLightness(0.15).withSaturation(0.3).toColor();
          });
          return;
        }
      }
    } catch (_) {
      // Fallback local si el backend no responde
    }

    try {
      final ui.Image image = await decodeImageFromList(imageBytes);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      int rSum = 0, gSum = 0, bSum = 0;
      final step = (bytes.length ~/ 400).clamp(1, 1000) * 4;
      int sampled = 0;
      for (int i = 0; i < bytes.length; i += step) {
        rSum += bytes[i];
        gSum += bytes[i + 1];
        bSum += bytes[i + 2];
        sampled++;
      }
      if (sampled == 0) return;
      final dominant = Color.fromARGB(255, rSum ~/ sampled, gSum ~/ sampled, bSum ~/ sampled);

      if (mounted) {
        setState(() {
          _extractedPrimaryColor = dominant;
          _extractedSecondaryColor = HSLColor.fromColor(dominant)
              .withLightness(0.15)
              .withSaturation(0.3)
              .toColor();
        });
      }
    } catch (e) {
      debugPrint('Error extrayendo color: $e');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _nameCtrl.text.trim();
    final adminEmail = _adminEmailCtrl.text.trim();
    final adminPassword = _adminPasswordCtrl.text.trim();
    final module = _selectedModule;

    if (name.isEmpty || adminEmail.isEmpty || adminPassword.isEmpty || module == null || module.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      String? logoUrl;
      
      // Subir imagen a Supabase Storage si existe
      if (_logoBytes != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${name.replaceAll(' ', '_')}.$_logoExt';
        final path = 'tenants/$fileName';
        
        await Supabase.instance.client.storage
            .from('logos')
            .uploadBinary(path, _logoBytes!);
            
        logoUrl = Supabase.instance.client.storage.from('logos').getPublicUrl(path);
      }

      // Convertir el color a Hex
      final primaryHex = _extractedPrimaryColor != null 
          ? '#${(_extractedPrimaryColor!.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}'
          : '#3E63DD';

      final secondaryHex = _extractedSecondaryColor != null 
          ? '#${(_extractedSecondaryColor!.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}'
          : '#111113';

      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      final response = await http.post(
        Uri.parse('$baseUrl/super-admin/tenants'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'module_slug': module,
          'primary_color': primaryHex,
          'secondary_color': secondaryHex,
          'admin_email': adminEmail,
          'admin_password': adminPassword,
          'logo_url': ?logoUrl,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Error del servidor: ${response.body}');
      }

      if (mounted) {
        context.go('/super-admin/tenants');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DokkoTokens.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: DokkoTokens.text),
                onPressed: () => context.go('/super-admin/tenants'),
              ),
              const SizedBox(width: DokkoTokens.space8),
              const Text(
                'Nuevo Tenant',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: DokkoTokens.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: DokkoTokens.space24),
          DokkoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DokkoInput(
                  label: 'Nombre del negocio',
                  placeholder: 'Ej. Gym Fitness',
                  controller: _nameCtrl,
                ),
                const SizedBox(height: DokkoTokens.space16),
                const Text(
                  'Módulo',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: DokkoTokens.text,
                  ),
                ),
                const SizedBox(height: DokkoTokens.space8),
                if (_isLoadingModules)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButton<String>(
                    value: _selectedModule,
                    isExpanded: true,
                    dropdownColor: DokkoTokens.surface,
                    style: const TextStyle(color: DokkoTokens.text),
                    underline: Container(
                      height: 1,
                      color: DokkoTokens.line,
                    ),
                    items: _availableModules.map((m) {
                      return DropdownMenuItem<String>(
                        value: m['slug'] as String,
                        child: Text(m['name'] as String),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedModule = val;
                      });
                    },
                  ),
                const SizedBox(height: DokkoTokens.space16),
                const Text(
                  'Logo de la Empresa',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: DokkoTokens.text,
                  ),
                ),
                const SizedBox(height: DokkoTokens.space8),
                Row(
                  children: [
                    DokkoButton(
                      label: 'Seleccionar Logo',
                      variant: DokkoButtonVariant.secondary,
                      onPressed: _pickLogo,
                    ),
                    const SizedBox(width: DokkoTokens.space16),
                    if (_logoBytes != null) ...[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
                          image: DecorationImage(
                            image: MemoryImage(_logoBytes!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: DokkoTokens.space16),
                    ],
                    if (_extractedPrimaryColor != null) ...[
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _extractedPrimaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: DokkoTokens.line),
                        ),
                      ),
                      const SizedBox(width: DokkoTokens.space8),
                      if (_extractedSecondaryColor != null) ...[
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _extractedSecondaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: DokkoTokens.line),
                          ),
                        ),
                        const SizedBox(width: DokkoTokens.space8),
                      ],
                      const Text(
                        'Colores extraídos',
                        style: TextStyle(fontSize: 12, color: DokkoTokens.text2),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: DokkoTokens.space24),
                const Divider(color: DokkoTokens.line),
                const SizedBox(height: DokkoTokens.space24),
                const Text(
                  'Credenciales del Administrador',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: DokkoTokens.text,
                  ),
                ),
                const SizedBox(height: DokkoTokens.space16),
                DokkoInput(
                  label: 'Email del administrador',
                  placeholder: 'admin@negocio.com',
                  controller: _adminEmailCtrl,
                ),
                const SizedBox(height: DokkoTokens.space16),
                DokkoInput(
                  label: 'Contraseña temporal',
                  placeholder: 'Mínimo 6 caracteres',
                  controller: _adminPasswordCtrl,
                  obscureText: true,
                ),
                const SizedBox(height: DokkoTokens.space24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    DokkoButton(
                      label: 'Cancelar',
                      variant: DokkoButtonVariant.ghost,
                      onPressed: () => context.go('/super-admin/tenants'),
                    ),
                    const SizedBox(width: DokkoTokens.space16),
                    DokkoButton(
                      label: 'Crear Cliente',
                      isLoading: _isLoading,
                      onPressed: _handleCreate,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
