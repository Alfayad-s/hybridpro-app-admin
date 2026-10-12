import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/admin_providers.dart';
import '../../core/api/admin_repository.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../widgets/keyboard_aware_sheet.dart';

Future<bool> showOrderDetailSheet(
  BuildContext context,
  ShopOrderAdmin order,
) async {
  final changed = await KeyboardAwareSheet.show<bool>(
    context: context,
    backgroundColor: HpColors.card,
    maxHeightFactor: 0.92,
    builder: (ctx) => _OrderDetailSheet(order: order),
  );
  return changed == true;
}

class _OrderDetailSheet extends ConsumerStatefulWidget {
  const _OrderDetailSheet({required this.order});

  final ShopOrderAdmin order;

  @override
  ConsumerState<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends ConsumerState<_OrderDetailSheet> {
  late ShopOrderAdmin _order;
  late List<ShopOrderItemAdmin> _items;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _items = List.of(widget.order.items);
  }

  bool get _dirty {
    if (_items.length != _order.items.length) return true;
    for (var i = 0; i < _items.length; i++) {
      final next = _items[i];
      final current = _order.items[i];
      if (next.slug != current.slug ||
          next.qty != current.qty ||
          next.stockOut != current.stockOut) {
        return true;
      }
    }
    return false;
  }

  int get _total => _items.fold(0, (sum, item) => sum + item.linePaise);

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await ref.read(adminRepositoryProvider).updateShopOrder(
            _order.id,
            _items,
          );
      if (!mounted) return;
      setState(() {
        _order = saved;
        _items = List.of(saved.items);
        _busy = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err.message;
      });
    }
  }

  Future<void> _accept() async {
    if (_dirty) await _save();
    if (_error != null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await ref.read(adminRepositoryProvider).acceptShopOrder(_order.id);
      if (!mounted) return;
      setState(() {
        _order = saved;
        _items = List.of(saved.items);
        _busy = false;
      });
      Navigator.of(context).pop(true);
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err.message;
      });
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => const _RejectDialog(),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(adminRepositoryProvider)
          .rejectShopOrder(_order.id, reason.trim());
      if (!mounted) return;
      setState(() {
        _order = saved;
        _items = List.of(saved.items);
        _busy = false;
      });
      Navigator.of(context).pop(true);
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err.message;
      });
    }
  }

  Future<void> _addProduct() async {
    final products = await ref.read(storeProductsProvider('').future);
    if (!mounted) return;
    final taken = _items.map((item) => item.slug).toSet();
    final choices = products
        .where((product) => product.active && !product.comingSoon && !taken.contains(product.slug))
        .toList();
    final picked = await showModalBottomSheet<StoreProductAdmin>(
      context: context,
      backgroundColor: HpColors.card,
      builder: (ctx) {
        if (choices.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Every product is already on this order.'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
          itemCount: choices.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final product = choices[i];
            return ListTile(
              leading: _ItemPhoto(url: product.imageUrl, size: 44),
              title: Text(product.title),
              subtitle: Text(product.priceLabel),
              onTap: () => Navigator.of(ctx).pop(product),
            );
          },
        );
      },
    );
    if (picked == null || !mounted) return;
    final unit = picked.pricePaise ?? _rupeesFromLabel(picked.priceLabel);
    setState(() {
      _items = [
        ..._items,
        ShopOrderItemAdmin(
          slug: picked.slug,
          title: picked.title,
          size: '',
          qty: 1,
          unitPaise: unit,
          image: picked.imageUrl ?? '',
          stockOut: false,
        ),
      ];
    });
  }

  int _rupeesFromLabel(String label) {
    final digits = label.replaceAll(RegExp(r'[^0-9]'), '');
    return (int.tryParse(digits) ?? 0) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final editable = _order.canEdit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HpColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _order.customerName.isEmpty ? _order.email : _order.customerName,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                [_order.email, _order.mobile].where((part) => part.isNotEmpty).join(' · '),
                style: GoogleFonts.inter(fontSize: 13, color: HpColors.mutedForeground),
              ),
              if (_order.deliveryLine.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _order.deliveryLine,
                  style: GoogleFonts.inter(fontSize: 13, color: HpColors.mutedForeground),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                _line(i, editable),
                const SizedBox(height: 12),
              ],
              if (editable)
                OutlinedButton.icon(
                  onPressed: _busy ? null : AppHaptics.wrap(_addProduct),
                  icon: const Icon(Icons.add),
                  label: const Text('Add product'),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Total', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(
                    formatOrderRupees(_total),
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              if (_order.rejectReason.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Rejected: ${_order.rejectReason}',
                  style: GoogleFonts.inter(color: Colors.red.shade700),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: GoogleFonts.inter(color: Colors.red.shade700)),
              ],
            ],
          ),
        ),
        if (editable)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_dirty)
                    FilledButton(
                      onPressed: _busy ? null : AppHaptics.wrap(_save),
                      child: Text(_busy ? 'Saving…' : 'Save changes'),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : AppHaptics.wrap(_reject),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy || _order.status != 'paid'
                              ? null
                              : AppHaptics.wrap(_accept),
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                  if (_order.status != 'paid')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Accept is available after the customer pays.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: HpColors.mutedForeground,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _line(int index, bool editable) {
    final item = _items[index];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ItemPhoto(url: item.image, size: 56),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              if (item.size.isNotEmpty)
                Text(
                  'Size ${item.size}',
                  style: GoogleFonts.inter(fontSize: 12, color: HpColors.mutedForeground),
                ),
              if (item.stockOut)
                Text(
                  'Stock out',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade700,
                  ),
                )
              else
                Text(
                  'Qty ${item.qty} · ${item.amountLabel}',
                  style: GoogleFonts.inter(fontSize: 13, color: HpColors.mutedForeground),
                ),
              if (editable)
                Row(
                  children: [
                    IconButton(
                      onPressed: _busy
                          ? null
                          : AppHaptics.wrap(() {
                              setState(() {
                                if (item.stockOut) return;
                                if (item.qty <= 1) {
                                  _items[index] = item.copyWith(qty: 0, stockOut: true);
                                } else {
                                  _items[index] = item.copyWith(qty: item.qty - 1);
                                }
                              });
                            }),
                      icon: const Icon(Icons.remove),
                    ),
                    IconButton(
                      onPressed: _busy || item.stockOut || item.qty >= 10
                          ? null
                          : AppHaptics.wrap(() {
                              setState(() {
                                _items[index] = item.copyWith(qty: item.qty + 1);
                              });
                            }),
                      icon: const Icon(Icons.add),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : AppHaptics.wrap(() {
                              setState(() {
                                _items[index] = item.stockOut
                                    ? item.copyWith(qty: 1, stockOut: false)
                                    : item.copyWith(qty: 0, stockOut: true);
                              });
                            }),
                      child: Text(item.stockOut ? 'Restore' : 'Stock out'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemPhoto extends StatelessWidget {
  const _ItemPhoto({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = url?.trim() ?? '';
    final network = image.startsWith('http://') || image.startsWith('https://');
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: network
            ? Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(color: HpColors.subtle),
              )
            : const ColoredBox(
                color: HpColors.subtle,
                child: Icon(Icons.image_outlined, size: 18),
              ),
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject order'),
      content: TextField(
        controller: _reason,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Reason'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
