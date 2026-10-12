import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/api/admin_repository.dart';
import '../../core/api/engagement_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';

class EngagementSettingsScreen extends ConsumerStatefulWidget {
  const EngagementSettingsScreen({super.key});

  @override
  ConsumerState<EngagementSettingsScreen> createState() => _EngagementSettingsScreenState();
}

class _EngagementSettingsScreenState extends ConsumerState<EngagementSettingsScreen> {
  EngagementAdminConfig? _config;
  bool _loading = true;
  String? _error;
  late final TextEditingController _limit;

  @override
  void initState() {
    super.initState();
    _limit = TextEditingController(text: '6');
    _load();
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await ref.read(adminRepositoryProvider).engagementConfig();
      if (!mounted) return;
      _limit.text = '${config.dailyLimit}';
      setState(() {
        _config = config;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveWindow() async {
    final config = _config;
    if (config == null) return;
    final limit = int.tryParse(_limit.text.trim());
    if (limit == null || limit < 1 || limit > 12) {
      _toast('Daily cap must be from 1 to 12');
      return;
    }
    try {
      final next = await ref.read(adminRepositoryProvider).updateEngagementSettings(
            dailyLimit: limit,
            quietStartMinutes: config.quietStartMinutes,
            quietEndMinutes: config.quietEndMinutes,
          );
      if (!mounted) return;
      setState(() => _config = next);
      _toast('Saved');
    } catch (error) {
      _toast(error.toString());
    }
  }

  Future<void> _pickQuiet({required bool start}) async {
    final config = _config;
    if (config == null) return;
    final current = start ? config.quietStartMinutes : config.quietEndMinutes;
    final picked = await showTimePicker(
      context: context,
      helpText: start ? 'Quiet hours start' : 'Quiet hours end',
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    try {
      final next = await ref.read(adminRepositoryProvider).updateEngagementSettings(
            dailyLimit: int.tryParse(_limit.text.trim()) ?? config.dailyLimit,
            quietStartMinutes: start ? minutes : config.quietStartMinutes,
            quietEndMinutes: start ? config.quietEndMinutes : minutes,
          );
      if (!mounted) return;
      setState(() => _config = next);
    } catch (error) {
      _toast(error.toString());
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    return Scaffold(
      backgroundColor: HpColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: AppHaptics.wrap(() => context.pop()),
          icon: const Icon(Iconsax.arrow_left_2),
        ),
        title: Text(
          'Engagement',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HpColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Could not load engagement settings.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: HpColors.mutedForeground),
                        ),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    Text(
                      'A member’s own switches still win. Quiet hours here apply when a member has not set their own.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.4,
                        color: HpColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Daily cap', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _limit,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        hintText: '6',
                        helperText: 'Most reminders one member can receive in a day',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Quiet hours start'),
                      subtitle: Text(
                        config == null ? '' : formatMinutes(config.quietStartMinutes),
                      ),
                      trailing: const Icon(Iconsax.clock, size: 18),
                      onTap: AppHaptics.wrap(() => _pickQuiet(start: true)),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Quiet hours end'),
                      subtitle: Text(
                        config == null ? '' : formatMinutes(config.quietEndMinutes),
                      ),
                      trailing: const Icon(Iconsax.clock, size: 18),
                      onTap: AppHaptics.wrap(() => _pickQuiet(start: false)),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: AppHaptics.wrap(_saveWindow),
                        child: const Text('Save cap'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Messages',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    for (final template in config?.templates ?? const <EngagementTemplate>[])
                      _TemplateEditor(
                        key: ValueKey('${template.type}-${template.title}-${template.enabled}'),
                        template: template,
                        onSaved: (next) => setState(() => _config = next),
                        onError: _toast,
                      ),
                  ],
                ),
    );
  }
}

class _TemplateEditor extends ConsumerStatefulWidget {
  const _TemplateEditor({
    super.key,
    required this.template,
    required this.onSaved,
    required this.onError,
  });

  final EngagementTemplate template;
  final ValueChanged<EngagementAdminConfig> onSaved;
  final ValueChanged<String> onError;

  @override
  ConsumerState<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends ConsumerState<_TemplateEditor> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late bool _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.template.title);
    _body = TextEditingController(text: widget.template.body);
    _enabled = widget.template.enabled;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      widget.onError('Title and message are required');
      return;
    }
    setState(() => _saving = true);
    try {
      final next = await ref.read(adminRepositoryProvider).updateEngagementTemplate(
            type: widget.template.type,
            title: title,
            body: body,
            enabled: _enabled,
          );
      widget.onSaved(next);
    } catch (error) {
      widget.onError(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: HpColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HpColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.template.label,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              Switch(
                value: _enabled,
                activeThumbColor: HpColors.primary,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
          ),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: _body,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Message'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _saving ? null : AppHaptics.wrap(_save),
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }
}
