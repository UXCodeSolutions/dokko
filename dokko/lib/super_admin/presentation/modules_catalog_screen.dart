import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_card.dart';
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
          .select('*, subscription_plans(*)');
      setState(() {
        _modules = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DokkoTokens.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Catálogo de Módulos y Planes',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: DokkoTokens.text,
            ),
          ),
          const SizedBox(height: DokkoTokens.space24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _modules.isEmpty
                    ? const DokkoEmptyState(
                        icon: Icons.view_module_rounded,
                        message: 'No hay módulos configurados.',
                      )
                    : ListView.builder(
                        itemCount: _modules.length,
                        itemBuilder: (context, index) {
                          final module = _modules[index];
                          final plans = List<Map<String, dynamic>>.from(
                              module['subscription_plans'] ?? []);
                          return _buildModuleCard(module, plans);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(
      Map<String, dynamic> module, List<Map<String, dynamic>> plans) {
    return Container(
      margin: const EdgeInsets.only(bottom: DokkoTokens.space16),
      child: DokkoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.dashboard_rounded,
                    color: DokkoTokens.amber, size: 24),
                const SizedBox(width: DokkoTokens.space12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: DokkoTokens.text,
                      ),
                    ),
                    Text(
                      'Slug: ${module['slug']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: DokkoTokens.text3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: DokkoTokens.space16),
            Text(
              module['description'] ?? '',
              style: const TextStyle(color: DokkoTokens.text2, fontSize: 14),
            ),
            const SizedBox(height: DokkoTokens.space16),
            const Text(
              'PLANES BASE',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: DokkoTokens.text3,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: DokkoTokens.space8),
            if (plans.isEmpty)
              const Text('No hay planes configurados para este módulo.',
                  style: TextStyle(color: DokkoTokens.text3, fontSize: 13))
            else
              ...plans.map((plan) {
                return Container(
                  margin: const EdgeInsets.only(bottom: DokkoTokens.space8),
                  padding: const EdgeInsets.all(DokkoTokens.space12),
                  decoration: BoxDecoration(
                    color: DokkoTokens.surface2,
                    borderRadius: BorderRadius.circular(DokkoTokens.radiusSm),
                    border: Border.all(color: DokkoTokens.line),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        plan['name'],
                        style: const TextStyle(
                          color: DokkoTokens.text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '\$${plan['base_price']} / ${plan['interval']}',
                        style: const TextStyle(
                          color: DokkoTokens.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
