import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/admin_repository.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/utils/format.dart';
import '../../widgets/common.dart';
import '../../core/utils/haptics.dart';

class ContactDetailScreen extends ConsumerStatefulWidget {
  const ContactDetailScreen({super.key, required this.contactId});

  final String contactId;

  @override
  ConsumerState<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends ConsumerState<ContactDetailScreen> {
  bool _loading = true;
  bool _granting = false;
  String? _error;
  ContactDetail? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail =
          await ref.read(adminRepositoryProvider).contactDetail(widget.contactId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _grant() async {
    var planId = 'performance';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Grant plan'),
        content: DropdownButtonFormField<String>(
          initialValue: planId,
          items: planIds
              .map((p) => DropdownMenuItem(value: p, child: Text(planLabel(p))))
              .toList(),
          onChanged: AppHaptics.wrapChanged((v) => planId = v ?? planId),
        ),
        actions: [
          TextButton(
            onPressed: AppHaptics.wrap(() => Navigator.pop(ctx, false)),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: AppHaptics.wrap(() => Navigator.pop(ctx, true)),
            child: const Text('Grant'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _granting = true);
    try {
      final result = await ref.read(adminRepositoryProvider).grantContact(
            widget.contactId,
            planId: planId,
          );
      if (!mounted) return;
      final subId = result.subscription?.id;
      if (subId != null) {
        context.go('/clients/$subId');
      } else {
        await _load();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _granting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    final s = d?.submission;

    return Scaffold(
      appBar: AppBar(title: Text(s?.name ?? 'Contact')),
      body: AsyncBody(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: s == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(s.email),
                          if (s.phone.isNotEmpty) Text(s.phone),
                          const SizedBox(height: 8),
                          Text('Status: ${s.status}'),
                          Text('Received ${formatDateTime(s.createdAt)}'),
                        ],
                      ),
                    ),
                  ),
                  const SectionTitle('Goal'),
                  Text(s.goal.isEmpty ? '—' : s.goal),
                  if (d?.clientId != null) ...[
                    const SectionTitle('Existing client'),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(d!.clientPlan ?? 'Client'),
                      subtitle: Text(d.clientStatus ?? ''),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: AppHaptics.wrap(() => context.push('/clients/${d.clientId}')),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: AppHaptics.wrap(_granting ? null : _grant),
                    child: Text(_granting ? 'Granting…' : 'Grant plan'),
                  ),
                ],
              ),
      ),
    );
  }
}
