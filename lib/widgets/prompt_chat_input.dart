import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/haptics.dart';

class PromptChatAttachment {
  const PromptChatAttachment({
    required this.path,
    required this.name,
    this.isImage = true,
  });

  final String path;
  final String name;
  final bool isImage;
}

/// Prompt-kit style chat composer — dark theme, link attach + circular send.
class PromptChatInput extends StatefulWidget {
  const PromptChatInput({
    super.key,
    this.controller,
    this.isLoading = false,
    this.enabled = true,
    this.hintText = 'Type a message or drop files...',
    this.onSubmit,
    this.maxFiles = 6,
  });

  final TextEditingController? controller;
  final bool isLoading;
  final bool enabled;
  final String hintText;
  final Future<bool> Function(String text, List<PromptChatAttachment> files)?
      onSubmit;
  final int maxFiles;

  @override
  State<PromptChatInput> createState() => _PromptChatInputState();
}

class _PromptChatInputState extends State<PromptChatInput> {
  static const _surface = Color(0xFF1A1A1E);
  static const _chip = Color(0xFF27272A);
  static const _iconBtn = Color(0xFF2A2A30);

  late final TextEditingController _controller;
  late final bool _ownsController;
  final _focus = FocusNode();
  final _picker = ImagePicker();
  final _files = <PromptChatAttachment>[];

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onText);
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _focus.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  bool get _canSend {
    if (widget.isLoading || !widget.enabled) return false;
    return _controller.text.trim().isNotEmpty || _files.isNotEmpty;
  }

  Future<void> _pickFiles() async {
    if (!widget.enabled || widget.isLoading) return;
    AppHaptics.selection();
    final remaining = widget.maxFiles - _files.length;
    if (remaining <= 0) return;

    final picked = await _picker.pickMultiImage(
      imageQuality: 85,
      limit: remaining,
    );
    if (picked.isEmpty || !mounted) return;

    setState(() {
      for (final file in picked) {
        if (_files.length >= widget.maxFiles) break;
        final name = file.name.trim().isNotEmpty
            ? file.name
            : file.path.split(Platform.pathSeparator).last;
        _files.add(
          PromptChatAttachment(
            path: file.path,
            name: name,
            isImage: true,
          ),
        );
      }
    });
  }

  void _removeFile(int index) {
    AppHaptics.selection();
    setState(() => _files.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_canSend || widget.onSubmit == null) return;
    AppHaptics.selection();
    final text = _controller.text.trim();
    final files = List<PromptChatAttachment>.from(_files);
    final ok = await widget.onSubmit!(text, files);
    if (!mounted || !ok) return;
    _controller.clear();
    setState(() => _files.clear());
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.enabled && !widget.isLoading;

    return Material(
      color: _surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: HpColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_files.isNotEmpty) ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _files.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 3.2,
                ),
                itemBuilder: (context, index) {
                  final file = _files[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: _chip,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Iconsax.link,
                          size: 16,
                          color: HpColors.mutedForeground,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: HpColors.foreground,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _removeFile(index),
                          borderRadius: BorderRadius.circular(99),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: HpColors.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: interactive,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: HpColors.foreground,
                height: 1.35,
              ),
              cursorColor: HpColors.primary,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: HpColors.mutedForeground,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) {
                if (_canSend) _submit();
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Tooltip(
                  message: 'Attach files',
                  child: Material(
                    color: _iconBtn,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: interactive ? _pickFiles : null,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Iconsax.link,
                          size: 18,
                          color: interactive
                              ? HpColors.foreground
                              : HpColors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: widget.isLoading ? 'Sending…' : 'Send message',
                  child: Material(
                    color: _canSend || widget.isLoading
                        ? HpColors.primary
                        : _iconBtn,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _canSend ? _submit : null,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: widget.isLoading
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: HpColors.primaryForeground,
                                  ),
                                )
                              : Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 20,
                                  color: _canSend
                                      ? HpColors.primaryForeground
                                      : HpColors.mutedForeground,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
