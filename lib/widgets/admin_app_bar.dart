import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../core/auth/auth_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/haptics.dart';

const adminProfileHeroTag = 'admin_profile_avatar';

/// Unique per shell tab so IndexedStack keep-alives don't share one Hero tag.
String profileHeroTagFor(BuildContext context) {
  final loc = GoRouterState.of(context).matchedLocation;
  return '$adminProfileHeroTag@$loc';
}

class ProfileAvatarButton extends ConsumerWidget {
  const ProfileAvatarButton({
    super.key,
    this.size = 36,
    this.hero = true,
  });

  final double size;
  final bool hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authControllerProvider).email ?? '';
    final letter = email.isNotEmpty ? email[0].toUpperCase() : 'C';
    final tag = profileHeroTagFor(context);

    final avatar = _ProfileAvatar(
      size: size,
      letter: letter,
      borderWidth: 1,
    );

    final child = hero
        ? Hero(
            tag: tag,
            createRectTween: (begin, end) =>
                MaterialRectArcTween(begin: begin, end: end),
            child: Material(
              type: MaterialType.transparency,
              child: avatar,
            ),
          )
        : avatar;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: AppHaptics.wrap(() => context.push('/settings', extra: tag)),
        child: child,
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.size,
    required this.letter,
    this.borderWidth = 1,
  });

  final double size;
  final String letter;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HpColors.card,
        border: Border.all(color: HpColors.border, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: Text(
          letter,
          style: GoogleFonts.inter(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: HpColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Title on the left; filled search icon + profile on the right.
/// Tapping search expands a full-width search field.
class AdminAppBar extends StatefulWidget implements PreferredSizeWidget {
  const AdminAppBar({
    super.key,
    required this.title,
    this.searchController,
    this.onSearchChanged,
    this.searchHint = 'Search…',
    this.extraActions = const [],
    this.enableSearch = true,
  });

  final String title;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final String searchHint;
  final List<Widget> extraActions;
  final bool enableSearch;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<AdminAppBar> createState() => _AdminAppBarState();
}

class _AdminAppBarState extends State<AdminAppBar> {
  bool _searchOpen = false;
  late final FocusNode _focus;

  /// Bold / filled Iconsax search mark
  static const _searchFilled = Iconsax.search_normal_1_copy;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _openSearch() {
    AppHaptics.tap();
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _closeSearch() {
    AppHaptics.tap();
    _focus.unfocus();
    widget.searchController?.clear();
    widget.onSearchChanged?.call('');
    setState(() => _searchOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final searching = _searchOpen && widget.enableSearch;
    final barWidth = MediaQuery.sizeOf(context).width - 24;

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: searching ? 12 : 16,
      centerTitle: false,
      leadingWidth: 0,
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          );
        },
        child: searching
            ? SizedBox(
                key: const ValueKey('search-bar'),
                width: barWidth,
                height: 44,
                child: TextField(
                  controller: widget.searchController,
                  focusNode: _focus,
                  onChanged: widget.onSearchChanged,
                  style: GoogleFonts.inter(
                    color: HpColors.foreground,
                    fontSize: 16,
                  ),
                  cursorColor: HpColors.primary,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.searchHint,
                    hintStyle: GoogleFonts.inter(color: HpColors.mutedForeground),
                    filled: true,
                    fillColor: HpColors.popover,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: HpColors.primary, width: 1.2),
                    ),
                    prefixIcon: const Icon(
                      _searchFilled,
                      size: 20,
                      color: HpColors.primary,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Close search',
                      onPressed: _closeSearch,
                      icon: const Icon(
                        Iconsax.close_circle,
                        size: 20,
                        color: HpColors.mutedForeground,
                      ),
                    ),
                  ),
                ),
              )
            : Align(
                key: const ValueKey('title'),
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: HpColors.foreground,
                  ),
                ),
              ),
      ),
      actions: searching
          ? null
          : [
              ...widget.extraActions,
              if (widget.enableSearch)
                IconButton(
                  tooltip: 'Search',
                  onPressed: _openSearch,
                  icon: const Icon(_searchFilled, size: 22),
                  color: HpColors.foreground,
                ),
              const ProfileAvatarButton(size: 34),
            ],
    );
  }
}
