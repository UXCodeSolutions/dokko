import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_card.dart';
import '../../../core/widgets/dokko_table.dart';
import '../../../core/widgets/dokko_empty_state.dart';

class AccountOwnersListScreen extends ConsumerStatefulWidget {
  const AccountOwnersListScreen({super.key});

  @override
  ConsumerState<AccountOwnersListScreen> createState() =>
      _AccountOwnersListScreenState();
}

class _AccountOwnersListScreenState
    extends ConsumerState<AccountOwnersListScreen> {
  List<Map<String, dynamic>> _owners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOwners();
  }

  Future<void> _fetchOwners() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('account_owners')
          .select('*');
      setState(() {
        _owners = List<Map<String, dynamic>>.from(response);
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
            'Account Owners',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: DokkoTokens.text,
            ),
          ),
          const SizedBox(height: DokkoTokens.space24),
          Expanded(
            child: DokkoCard(
              padding: EdgeInsets.zero,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _owners.isEmpty
                      ? const DokkoEmptyState(
                          icon: Icons.manage_accounts_rounded,
                          message: 'No hay Account Owners registrados.',
                        )
                      : DokkoTable<Map<String, dynamic>>(
                          columns: const [
                            DokkoTableColumn(title: 'Email', flex: 2),
                            DokkoTableColumn(title: 'Creado', width: 120),
                          ],
                          data: _owners,
                          cellValue: (item, index) {
                            switch (index) {
                              case 0:
                                return item['email'] ?? '';
                              case 1:
                                final date =
                                    DateTime.parse(item['created_at']);
                                return '${date.day}/${date.month}/${date.year}';
                              default:
                                return '';
                            }
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
