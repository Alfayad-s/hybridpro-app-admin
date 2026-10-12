import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/chat/chat_inbox_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../widgets/app_modal_sheet.dart';
import '../../widgets/brand_nav_logo.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Visible tab items map to shell branches 1–4 (0 is Dashboard via logo).
  /// In iconsax_flutter, `*_copy` is the outline (unfilled) glyph;
  /// the base name is the bold/filled glyph.
  static const _tabs = [
    _NavTab(
      label: 'Clients',
      outlineIcon: Iconsax.people_copy,
      filledIcon: Iconsax.people,
      branch: 1,
    ),
    _NavTab(
      label: 'Library',
      outlineIcon: Iconsax.weight_copy,
      filledIcon: Iconsax.weight,
      branch: 2,
    ),
    _NavTab(
      label: 'Payments',
      outlineIcon: Iconsax.wallet_money_copy,
      filledIcon: Iconsax.wallet_money,
      branch: 3,
    ),
    _NavTab(
      label: 'Store',
      outlineIcon: Iconsax.shop_copy,
      filledIcon: Iconsax.shop,
      branch: 4,
    ),
  ];

  /// Visual slot index in the 5-slot bar (logo sits at center = 2).
  static int slotForBranch(int branch) {
    switch (branch) {
      case 0:
        return 2;
      case 1:
        return 0;
      case 2:
        return 1;
      case 3:
        return 3;
      case 4:
        return 4;
      default:
        return 2;
    }
  }

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  /// Last non-dashboard slot — keeps the pill from sliding onto the logo.
  late int _pillSlot;

  @override
  void initState() {
    super.initState();
    final index = widget.navigationShell.currentIndex;
    _pillSlot = index == 0 ? 0 : AdminShell.slotForBranch(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chatInboxProvider.notifier).refresh();
    });
  }

  @override
  void didUpdateWidget(covariant AdminShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = widget.navigationShell.currentIndex;
    if (index != 0) {
      final slot = AdminShell.slotForBranch(index);
      if (slot != _pillSlot) {
        _pillSlot = slot;
      }
    }
  }

  void _goBranch(int branch) {
    AppHaptics.selection();
    if (branch != 0) {
      setState(() => _pillSlot = AdminShell.slotForBranch(branch));
    }
    final current = widget.navigationShell.currentIndex;
    widget.navigationShell.goBranch(
      branch,
      initialLocation: current == branch,
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.navigationShell.currentIndex;
    final onDashboard = index == 0;
    final sheetOpen = ref.watch(shellSheetDepthProvider) > 0;
    // Hide message FAB when a tab already has its own FAB, or a sheet is open.
    final showMessageFab =
        !sheetOpen && index != 1 && index != 2 && index != 4;
    final unread = ref.watch(chatInboxProvider).fold<int>(
          0,
          (sum, item) => sum + item.conversation.unreadCount,
        );

    return Scaffold(
      backgroundColor: HpColors.background,
      body: SizedBox.expand(child: widget.navigationShell),
      floatingActionButton: showMessageFab
          ? FloatingActionButton(
              heroTag: 'admin_messages_fab',
              backgroundColor: HpColors.primary,
              foregroundColor: HpColors.primaryForeground,
              onPressed: AppHaptics.wrap(() => context.push('/messages')),
              child: Badge(
                isLabelVisible: unread > 0,
                backgroundColor: const Color(0xFFEF4444),
                label: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                child: const Icon(Iconsax.message, size: 22),
              ),
            )
          : null,
      bottomNavigationBar: _AnimatedShellNav(
        visible: !sheetOpen,
        child: Material(
          color: HpColors.navBar,
          elevation: 8,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 68,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: HpColors.navBar,
                  border: Border(
                    top: BorderSide(color: HpColors.border),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final slotW = constraints.maxWidth / 5;
                      const inset = 4.0;

                      return Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 340),
                            curve: Curves.easeOutCubic,
                            left: _pillSlot * slotW + inset,
                            width: slotW - inset * 2,
                            top: 0,
                            bottom: 0,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              opacity: onDashboard ? 0 : 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: HpColors.primary,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: HpColors.primary
                                          .withValues(alpha: 0.28),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              for (var i = 0;
                                  i < AdminShell._tabs.length;
                                  i++) ...[
                                if (i == 2)
                                  Expanded(
                                    child: _BrandCenter(
                                      selected: onDashboard,
                                      onTap: () => _goBranch(0),
                                    ),
                                  ),
                                Expanded(
                                  child: _NavItem(
                                    tab: AdminShell._tabs[i],
                                    selected:
                                        index == AdminShell._tabs[i].branch,
                                    onTap: () => _goBranch(
                                      AdminShell._tabs[i].branch,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slides + fades the nav away and collapses its layout height.
class _AnimatedShellNav extends StatefulWidget {
  const _AnimatedShellNav({
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  State<_AnimatedShellNav> createState() => _AnimatedShellNavState();
}

class _AnimatedShellNavState extends State<_AnimatedShellNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    value: widget.visible ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _AnimatedShellNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) return;
    if (widget.visible) {
      _c.animateTo(1, curve: Curves.easeOutCubic);
    } else {
      _c.animateTo(0, curve: Curves.easeInCubic);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOutCubic.transform(_c.value);
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 24),
                child: child,
              ),
            ),
          ),
        );
      },
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: widget.child,
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.label,
    required this.outlineIcon,
    required this.filledIcon,
    required this.branch,
  });

  final String label;
  final IconData outlineIcon;
  final IconData filledIcon;
  final int branch;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _NavTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? HpColors.primaryForeground : HpColors.mutedForeground;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? tab.filledIcon : tab.outlineIcon,
            size: 22,
            color: color,
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
            child: Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandCenter extends StatelessWidget {
  const _BrandCenter({required this.onTap, this.selected = false});

  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedScale(
          scale: selected ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: const BrandNavLogoSlot(height: 28),
        ),
      ),
    );
  }
}
