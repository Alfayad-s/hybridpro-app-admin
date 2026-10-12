import 'package:flutter/material.dart';

import 'app_modal_sheet.dart';

/// Fixed-height keyboard-safe modal sheet (matches member app behavior).
class KeyboardAwareSheet extends StatelessWidget {
  const KeyboardAwareSheet({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.88,
    this.backgroundColor,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(24)),
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxHeightFactor;
  final Color? backgroundColor;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    Color? backgroundColor,
    Color? barrierColor,
    bool useSafeArea = true,
    double maxHeightFactor = 0.88,
  }) {
    return showAppModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: useSafeArea,
      backgroundColor: Colors.transparent,
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => KeyboardAwareSheet(
        maxHeightFactor: maxHeightFactor,
        backgroundColor: backgroundColor,
        child: builder(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final maxHeight = (media.size.height - keyboard - 12)
        .clamp(280.0, media.size.height * maxHeightFactor);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: maxHeight,
          width: double.infinity,
          child: Material(
            color: backgroundColor ?? Colors.transparent,
            borderRadius: borderRadius,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
