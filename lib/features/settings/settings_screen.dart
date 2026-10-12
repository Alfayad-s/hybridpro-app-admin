import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../widgets/admin_app_bar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.heroTag = adminProfileHeroTag});

  final String heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authControllerProvider).email ?? 'Coach';
    final letter = email.isNotEmpty ? email[0].toUpperCase() : 'C';

    return Scaffold(
      backgroundColor: HpColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: AppHaptics.wrap(() => context.pop()),
          icon: const Icon(Iconsax.arrow_left_2),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Hero(
              tag: heroTag,
              createRectTween: (begin, end) =>
                  MaterialRectArcTween(begin: begin, end: end),
              flightShuttleBuilder: (
                flightContext,
                animation,
                direction,
                fromHeroContext,
                toHeroContext,
              ) {
                final size = Tween<double>(begin: 34, end: 96).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                );
                final border = Tween<double>(begin: 1, end: 1.5).animate(animation);
                final fontSize = Tween<double>(begin: 13.6, end: 36).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                );
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    return Material(
                      type: MaterialType.transparency,
                      child: Container(
                        width: size.value,
                        height: size.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: HpColors.card,
                          border: Border.all(
                            color: HpColors.border,
                            width: border.value,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          letter,
                          style: GoogleFonts.inter(
                            fontSize: fontSize.value,
                            fontWeight: FontWeight.w700,
                            color: HpColors.primary,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HpColors.card,
                    border: Border.all(color: HpColors.border, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      letter,
                      style: GoogleFonts.inter(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: HpColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Coach',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: HpColors.foreground,
            ),
          ).animate().fadeIn(delay: 80.ms, duration: 350.ms),
          const SizedBox(height: 4),
          Text(
            email,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: HpColors.mutedForeground,
            ),
          ).animate().fadeIn(delay: 120.ms, duration: 350.ms),
          const SizedBox(height: 28),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Iconsax.info_circle,
                title: 'API',
                subtitle: AppConfig.backendUrl,
              ),
              const Divider(height: 1, color: HpColors.border),
              _SettingsTile(
                icon: Iconsax.shield_tick,
                title: 'Role',
                subtitle: 'Coach admin',
              ),
              const Divider(height: 1, color: HpColors.border),
              _SettingsTile(
                icon: Iconsax.sms,
                title: 'Contacts',
                subtitle: 'Website leads inbox',
                onTap: () => context.push('/contacts'),
              ),
              const Divider(height: 1, color: HpColors.border),
              _SettingsTile(
                icon: Iconsax.calendar,
                title: 'Hours',
                subtitle: 'Weekly availability and upcoming sessions',
                onTap: () => context.push('/availability'),
              ),
              const Divider(height: 1, color: HpColors.border),
              _SettingsTile(
                icon: Iconsax.notification,
                title: 'Engagement',
                subtitle: 'Reminders, daily cap, quiet hours',
                onTap: () => context.push('/engagement'),
              ),
            ],
          ).animate().fadeIn(delay: 160.ms, duration: 400.ms).slideY(
                begin: 0.06,
                end: 0,
                delay: 160.ms,
                duration: 400.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 16),
          Material(
            color: HpColors.destructive.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: AppHaptics.wrap(() async {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Iconsax.logout, color: HpColors.destructive),
                    const SizedBox(width: 12),
                    Text(
                      'Sign out',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: HpColors.destructive,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(delay: 220.ms, duration: 400.ms),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HpColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HpColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: HpColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: HpColors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: HpColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Iconsax.arrow_right_3, size: 18, color: HpColors.mutedForeground),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: AppHaptics.wrap(onTap),
      child: row,
    );
  }
}
