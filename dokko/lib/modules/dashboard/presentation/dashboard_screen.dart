import 'package:flutter/material.dart';
import '../../../core/theme/dokko_tokens.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: DokkoTokens.bg,
      body: Center(
        child: Text(
          'Dashboard Temporal (Fase 2)',
          style: TextStyle(color: DokkoTokens.text, fontSize: 20),
        ),
      ),
    );
  }
}
