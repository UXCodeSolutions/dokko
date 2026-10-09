import 'package:flutter/material.dart';
import '../theme/dokko_tokens.dart';

class DokkoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DokkoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DokkoTokens.space24),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DokkoTokens.bg,
        border: Border.all(color: DokkoTokens.line),
        borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
      ),
      padding: padding,
      child: child,
    );
  }
}
