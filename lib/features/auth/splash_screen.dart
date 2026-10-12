import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/brand_nav_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  static const _startSize = 88.0;
  static const _endSize = 28.0;

  late final AnimationController _entrance;
  late final AnimationController _fly;
  late final Animation<double> _entranceT;
  late final Animation<double> _flyT;

  bool _showLogo = false;
  bool _flying = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _fly = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _entranceT = CurvedAnimation(
      parent: _entrance,
      curve: Curves.easeOutBack,
    );
    _flyT = CurvedAnimation(
      parent: _fly,
      curve: Curves.easeInOutCubicEmphasized,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _runIntro());
  }

  @override
  void dispose() {
    _entrance.dispose();
    _fly.dispose();
    super.dispose();
  }

  Future<void> _celebratoryHaptics() async {
    await HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.selectionClick();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.heavyImpact();
  }

  Future<void> _waitForAuth() async {
    var status = ref.read(authControllerProvider).status;
    if (status != AuthStatus.unknown) return;
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      status = ref.read(authControllerProvider).status;
      if (status != AuthStatus.unknown) return;
    }
  }

  Offset _navTarget(Size size, EdgeInsets padding) {
    const navHeight = 64.0;
    return Offset(
      size.width / 2,
      size.height - padding.bottom - (navHeight / 2),
    );
  }

  Future<void> _runIntro() async {
    if (!mounted || _done) return;
    ref.read(brandLogoLandedProvider.notifier).reset();

    setState(() => _showLogo = true);
    await _entrance.forward();
    if (!mounted || _done) return;

    await Future.wait([
      Future<void>.delayed(const Duration(milliseconds: 250)),
      _celebratoryHaptics(),
      _waitForAuth(),
    ]);
    if (!mounted || _done) return;

    final status = ref.read(authControllerProvider).status;

    if (status == AuthStatus.authenticated) {
      setState(() => _flying = true);
      await HapticFeedback.mediumImpact();
      await _fly.forward();
      if (!mounted) return;
      _done = true;
      final container = ProviderScope.containerOf(context);
      context.go('/dashboard');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        container.read(brandLogoLandedProvider.notifier).markLanded();
      });
      return;
    }

    _done = true;
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final start = Offset(size.width / 2, size.height / 2);
    final end = _navTarget(size, padding);

    return Scaffold(
      backgroundColor: HpColors.background,
      body: AnimatedBuilder(
        animation: Listenable.merge([_entranceT, _flyT]),
        builder: (context, _) {
          if (!_showLogo) return const SizedBox.expand();

          final fly = _flying ? _flyT.value : 0.0;
          final pos = Offset.lerp(start, end, fly)!;
          final logoSize =
              lerpDouble(_startSize, _endSize, fly) ?? _startSize;
          final logoWidth = logoSize * (207 / 151);
          final entrance = _flying ? 1.0 : _entranceT.value;
          final scale = 0.5 + (0.5 * entrance);
          final opacity = entrance.clamp(0.0, 1.0);

          return Stack(
            children: [
              Positioned(
                left: pos.dx - logoWidth / 2,
                top: pos.dy - logoSize / 2,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: BrandLogo(height: logoSize),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
