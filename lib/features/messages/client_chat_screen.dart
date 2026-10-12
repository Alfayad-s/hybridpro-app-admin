import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptics.dart';
import '../../../widgets/profile_photo.dart';
import '../clients/widgets/client_chat_section.dart';

/// Full-screen chat with a single client (WhatsApp-style conversation).
class ClientChatScreen extends StatelessWidget {
  const ClientChatScreen({
    super.key,
    required this.clientId,
    this.title,
    this.subtitle,
    this.avatarUrl,
  });

  final String clientId;
  final String? title;
  final String? subtitle;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final name = (title ?? '').trim().isEmpty ? 'Chat' : title!.trim();
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: HpColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1E),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: AppHaptics.wrap(() => context.pop()),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: InkWell(
          onTap: AppHaptics.wrap(() => context.push('/clients/$clientId')),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                ProfilePhoto(
                  imageUrl: avatarUrl,
                  letter: letter,
                  size: 40,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: HpColors.foreground,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if ((subtitle ?? '').trim().isNotEmpty)
                        Text(
                          subtitle!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: HpColors.mutedForeground,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Client profile',
            onPressed:
                AppHaptics.wrap(() => context.push('/clients/$clientId')),
            icon: const Icon(Iconsax.user, size: 20),
          ),
        ],
      ),
      body: ClientChatSection(clientId: clientId, expanded: true),
    );
  }
}
