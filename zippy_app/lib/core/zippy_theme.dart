import 'package:flutter/material.dart';

/// Centralized design tokens and theme styling for the Zippy application.
///
/// Implements world-class dark aesthetic tokens based on anthropics/frontend-design
/// and Apple design system principles.
abstract final class ZippyTheme {
  // --- Semantic Color Palette ---
  /// Primary emerald green for merchant payments, verified indicators, and success states.
  static const Color primaryGreen = Color(0xFF16C784);

  /// Primary accent for Split Fare actions, chips, and progress bars.
  /// Unified with [primaryGreen] to maintain consistent emerald branding across Merchant and Split Fare.
  static const Color splitPurple = primaryGreen;

  /// Deep navy / black background (#080D18).
  static const Color background = Color(0xFF080D18);

  /// Surface color for cards, panels, and input containers (#0F172A).
  static const Color surface = Color(0xFF0F172A);

  /// Elevated surface color for active pills and overlays (#1E293B).
  static const Color surfaceElevated = Color(0xFF1E293B);

  /// Alternative card surface token (#0F172A).
  static const Color cardBackground = Color(0xFF0F172A);

  /// High-contrast off-white primary text.
  static const Color textPrimary = Color(0xFFF8FAFC);

  /// Secondary muted blue-grey text.
  static const Color textSecondary = Color(0xFF94A3B8);

  /// Subtle tertiary grey for captions and timestamps.
  static const Color textTertiary = Color(0xFF64748B);

  /// Subtle 1px border for containers and dividers (rgba(255,255,255,0.06)).
  static final Color border = Colors.white.withValues(alpha: 0.06);

  /// Active border highlight for merchant selection.
  static final Color borderActive = primaryGreen.withValues(alpha: 0.4);

  /// Active border highlight for split fare selection.
  static final Color borderActivePurple = primaryGreen.withValues(alpha: 0.4);

  // --- Strict Spacing Scale (4, 8, 12, 16, 24, 32) ---
  /// Spacing scale 4px.
  static const double space4 = 4.0;

  /// Spacing scale 8px.
  static const double space8 = 8.0;

  /// Spacing scale 12px.
  static const double space12 = 12.0;

  /// Spacing scale 16px.
  static const double space16 = 16.0;

  /// Spacing scale 20px (standard screen padding).
  static const double space20 = 20.0;

  /// Spacing scale 24px (standard section gap).
  static const double space24 = 24.0;

  /// Spacing scale 32px (large component gap).
  static const double space32 = 32.0;

  // --- Border Radii ---
  /// Small radius: 8px.
  static const double radiusSm = 8.0;

  /// Medium radius: 12px.
  static const double radiusMd = 12.0;

  /// Standard card/button radius: 16px.
  static const double radiusLg = 16.0;

  /// Pill/circular radius: 24px.
  static const double radiusPill = 24.0;
}
