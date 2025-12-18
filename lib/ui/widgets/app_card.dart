import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared card widget used throughout the app.
/// 
/// Replaces duplicate `_Card` widgets that were in multiple files.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.color,
    this.borderColor,
    this.borderRadius,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final double? borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: color ?? AppColors.cardBackground,
        borderRadius: BorderRadius.circular(borderRadius ?? AppSizes.cardRadius),
        border: Border.all(color: borderColor ?? AppColors.cardBorder),
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

/// Card with bottom margin (common pattern).
class AppCardSpaced extends StatelessWidget {
  const AppCardSpaced({
    super.key,
    required this.child,
    this.bottomMargin = AppSizes.itemSpacing,
  });

  final Widget child;
  final double bottomMargin;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.only(bottom: bottomMargin),
      child: child,
    );
  }
}
