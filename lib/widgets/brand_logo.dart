import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/app_theme.dart';

/// Shared brand mark (splash + bottom nav).
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 28,
    this.width,
  });

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width ?? height * (207 / 151),
      child: SvgPicture.asset(
        'assets/brand/logo.svg',
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(
          HpColors.primary,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
