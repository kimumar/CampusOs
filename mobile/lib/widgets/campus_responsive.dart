import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared responsive dimensions for CampusOS.
///
/// Keep layout decisions centralized so every new
/// screen follows the same mobile-first rules.
abstract final class CampusResponsive {
  static const double compactBreakpoint = 600;
  static const double tabletBreakpoint = 900;

  static const double formMaxWidth = 560;
  static const double dialogMaxWidth = 480;
  static const double contentMaxWidth = 1120;

  static bool isCompact(BuildContext context) {
    return MediaQuery.sizeOf(context).width <
        compactBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= compactBreakpoint &&
        width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >=
        tabletBreakpoint;
  }

  static double pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width < compactBreakpoint) return 16;
    if (width < tabletBreakpoint) return 24;
    return 32;
  }

  static double formWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return math.min(width, formMaxWidth);
  }

  static EdgeInsets pageInsets(BuildContext context) {
    final padding = pagePadding(context);

    return EdgeInsets.symmetric(
      horizontal: padding,
      vertical: 20,
    );
  }
}

/// Constrains page content on wide screens without
/// reducing the available width on phones.
class CampusPage extends StatelessWidget {
  const CampusPage({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth = CampusResponsive.contentMaxWidth,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ??
              CampusResponsive.pageInsets(context),
          child: child,
        ),
      ),
    );
  }
}