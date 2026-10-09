import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tenant_provider.dart';

// ── Contraste legible (mismo algoritmo que branding.py) ──────────────────────

double _linearize(int channel) {
  final c = channel / 255.0;
  return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color c) =>
    0.2126 * _linearize((c.r * 255).round()) +
    0.7152 * _linearize((c.g * 255).round()) +
    0.0722 * _linearize((c.b * 255).round());

double contrastRatio(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final l = la > lb ? [la, lb] : [lb, la];
  return (l[0] + 0.05) / (l[1] + 0.05);
}

Color pickTextColor(Color bg, {double threshold = 4.5}) {
  for (final cand in [Colors.white, const Color(0xFF0A0A0B), Colors.black]) {
    if (contrastRatio(bg, cand) >= threshold) return cand;
  }
  return Colors.white;
}

Color _pickTextColorSoft(Color bg) {
  for (final cand in [Colors.white, const Color(0xFF0A0A0B), Colors.black]) {
    if (contrastRatio(bg, cand) >= 3.0) return cand;
  }
  return Colors.white;
}

// ── BrandPalette ─────────────────────────────────────────────────────────────

class BrandPalette {
  final Color accent;
  final Color secondary;
  final Color onAccent;
  final Color onSecondary;
  final double textContrast;
  final String level; // 'AAA' | 'AA' | 'FALLA'
  final bool isValid;

  const BrandPalette({
    required this.accent,
    required this.secondary,
    required this.onAccent,
    required this.onSecondary,
    required this.textContrast,
    required this.level,
    required this.isValid,
  });

  factory BrandPalette.fromTenant(TenantData tenant) {
    final accent = tenant.accentColor;
    final secondary = tenant.secondaryColor;
    final onAccent = pickTextColor(accent);
    final onSecondary = _pickTextColorSoft(secondary);
    final ratio = contrastRatio(accent, onAccent);
    final level = ratio >= 7.0 ? 'AAA' : (ratio >= 4.5 ? 'AA' : 'FALLA');
    return BrandPalette(
      accent: accent,
      secondary: secondary,
      onAccent: onAccent,
      onSecondary: onSecondary,
      textContrast: double.parse(ratio.toStringAsFixed(2)),
      level: level,
      isValid: ratio >= 4.5,
    );
  }
}

// ── ThemeExtension para que sea accesible vía Theme.of(context) ──────────────

class BrandColors extends ThemeExtension<BrandColors> {
  final Color accent;
  final Color onAccent;
  final Color secondary;
  final Color onSecondary;

  const BrandColors({
    required this.accent,
    required this.onAccent,
    required this.secondary,
    required this.onSecondary,
  });

  static const fallback = BrandColors(
    accent: Color(0xFF3E63DD),
    onAccent: Colors.white,
    secondary: Color(0xFF111113),
    onSecondary: Colors.white,
  );

  @override
  BrandColors copyWith({Color? accent, Color? onAccent, Color? secondary, Color? onSecondary}) {
    return BrandColors(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
    );
  }

  @override
  BrandColors lerp(BrandColors? other, double t) {
    if (other is! BrandColors) return this;
    return BrandColors(
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
    );
  }
}

// ── Provider derivado ────────────────────────────────────────────────────────

final brandPaletteProvider = Provider<BrandPalette?>((ref) {
  final tenant = ref.watch(tenantProvider).value;
  if (tenant == null) return null;
  return BrandPalette.fromTenant(tenant);
});

final brandColorsProvider = Provider<BrandColors>((ref) {
  final palette = ref.watch(brandPaletteProvider);
  if (palette == null) return BrandColors.fallback;
  return BrandColors(
    accent: palette.accent,
    onAccent: palette.onAccent,
    secondary: palette.secondary,
    onSecondary: palette.onSecondary,
  );
});
