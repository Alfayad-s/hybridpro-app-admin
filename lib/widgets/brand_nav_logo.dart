import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'brand_logo.dart';

class BrandLogoLanded extends Notifier<bool> {
  @override
  bool build() => false;

  void markLanded() => state = true;

  void reset() => state = false;
}

final brandLogoLandedProvider =
    NotifierProvider<BrandLogoLanded, bool>(BrandLogoLanded.new);

/// Bottom-nav brand mark. Opacity stays 0 until splash flight finishes.
class BrandNavLogoSlot extends ConsumerWidget {
  const BrandNavLogoSlot({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landed = ref.watch(brandLogoLandedProvider);
    return Opacity(
      opacity: landed ? 1 : 0,
      child: BrandLogo(height: height),
    );
  }
}
