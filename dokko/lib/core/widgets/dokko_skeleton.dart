import 'package:flutter/material.dart';
import '../theme/dokko_tokens.dart';

class DokkoSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const DokkoSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = DokkoTokens.radiusMd,
  });

  @override
  State<DokkoSkeleton> createState() => _DokkoSkeletonState();
}

class _DokkoSkeletonState extends State<DokkoSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _opacity = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: DokkoTokens.surface,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}
