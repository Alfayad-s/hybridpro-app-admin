import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/haptics.dart';
import 'list_cards.dart';

String friendlyErrorMessage(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return 'Something went wrong';
  if (RegExp(
    r'ENOTFOUND|EAI_AGAIN|getaddrinfo|ECONNREFUSED|ETIMEDOUT|Failed query:',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'Cannot reach the database right now. Check your internet connection, then tap Retry.';
  }
  if (text.length > 180) {
    return '${text.substring(0, 177)}…';
  }
  return text;
}

class AsyncBody extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.child,
    this.empty = false,
    this.emptyLabel = 'Nothing here yet',
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final Widget child;
  final bool empty;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                friendlyErrorMessage(error),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: HpColors.mutedForeground),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: AppHaptics.wrap(onRetry),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (empty) {
      return Center(
        child: Text(
          emptyLabel,
          style: GoogleFonts.inter(color: HpColors.mutedForeground),
        ),
      );
    }
    return child;
  }
}

class MoneyChip extends StatelessWidget {
  const MoneyChip({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: HpColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HpColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: HpColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: HpColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatsRow extends StatelessWidget {
  const StatsRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(children: children),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: HpColors.foreground,
        ),
      ),
    );
  }
}

class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PageInsets.sectionGap),
      child: Wrap(
        spacing: PageInsets.chipGap,
        runSpacing: PageInsets.chipGap,
        children: children,
      ),
    );
  }
}
