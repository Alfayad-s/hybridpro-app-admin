import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/api/admin_providers.dart';
import '../../core/api/admin_repository.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../widgets/admin_app_bar.dart';
import '../../widgets/app_modal_sheet.dart';
import '../../widgets/common.dart';
import '../../widgets/hold_button.dart';
import '../../widgets/list_cards.dart';
import '../../widgets/rubber_segment.dart';
import 'order_detail_sheet.dart';
import 'product_edit_sheet.dart';
import 'promo_edit_sheet.dart';
import 'tab_edit_sheet.dart';
import 'taxonomy_sheet.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen>
    with AutomaticKeepAliveClientMixin {
  static const _products = 'products';
  static const _banners = 'banner';
  static const _cards = 'card';
  static const _tabs = 'tabs';
  static const _orders = 'orders';

  final _search = TextEditingController();
  Timer? _debounce;
  String _q = '';
  String _section = _products;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _q = value.trim());
    });
  }

  Future<void> _edit([StoreProductAdmin? existing]) async {
    final body = await showProductEditSheet(
      context,
      ref: ref,
      existing: existing,
    );
    if (body == null || !mounted) return;
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (existing == null) {
        await repo.createProduct(body);
      } else {
        await repo.updateProduct(existing.id, body);
      }
      await ref.refresh(storeProductsProvider(_q).future);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _delete(StoreProductAdmin product) async {
    final ok = await showHoldToDeleteSheet(
      context,
      title: 'Delete product?',
      message: product.title,
    );
    if (!ok) return;
    try {
      await ref.read(adminRepositoryProvider).deleteProduct(product.id);
      await ref.refresh(storeProductsProvider(_q).future);
    } on ApiException catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.message)),
        );
      }
    }
  }

  Future<void> _editPromo(String placement, [ShopPromoAdmin? existing]) async {
    final body = await showPromoEditSheet(
      context,
      ref: ref,
      placement: placement,
      existing: existing,
    );
    if (body == null || !mounted) return;
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (existing == null) {
        await repo.createShopPromo(body);
      } else {
        await repo.updateShopPromo(existing.id, body);
      }
      await ref.refresh(shopPromosProvider(placement).future);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _deletePromo(ShopPromoAdmin promo) async {
    final ok = await showHoldToDeleteSheet(
      context,
      title: promo.placement == 'banner' ? 'Delete banner?' : 'Delete card promo?',
      message: promo.alt,
    );
    if (!ok) return;
    try {
      await ref.read(adminRepositoryProvider).deleteShopPromo(promo.id);
      await ref.refresh(shopPromosProvider(promo.placement).future);
    } on ApiException catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.message)),
        );
      }
    }
  }

  Future<void> _editTab([StoreTaxonomyAdmin? existing]) async {
    final body = await showTabEditSheet(context, existing: existing);
    if (body == null || !mounted) return;
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (existing == null) {
        await repo.createProductCategory(body);
      } else {
        await repo.updateProductCategory(existing.id, body);
      }
        await ref.refresh(storeCategoriesProvider.future);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save the tab. $e')),
        );
      }
    }
  }

  Future<void> _deleteTab(StoreTaxonomyAdmin tab) async {
    final ok = await showHoldToDeleteSheet(
      context,
      title: 'Delete tab?',
      message: tab.label,
    );
    if (!ok) return;
    try {
      await ref.read(adminRepositoryProvider).deleteProductCategory(tab.id);
      await ref.refresh(storeCategoriesProvider.future);
    } on ApiException catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.message)),
        );
      }
    }
  }

  bool _isNetwork(String? url) {
    final u = url?.trim() ?? '';
    return u.startsWith('http://') || u.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(storeProductsProvider(_q));
    final items = async.asData?.value ?? const <StoreProductAdmin>[];
    final bannersAsync = ref.watch(shopPromosProvider(_banners));
    final cardsAsync = ref.watch(shopPromosProvider(_cards));
    final tabsAsync = ref.watch(storeCategoriesProvider);
    final ordersAsync = ref.watch(shopOrdersProvider(_q));
    final promosAsync = _section == _cards ? cardsAsync : bannersAsync;
    final promos = (promosAsync.asData?.value ?? const <ShopPromoAdmin>[])
        .where((promo) {
      if (_q.isEmpty) return true;
      final haystack = '${promo.alt} ${promo.label} ${promo.category}'.toLowerCase();
      return haystack.contains(_q.toLowerCase());
    }).toList();
    final onTabs = _section == _tabs;
    final onOrders = _section == _orders;
    final onPromos = _section == _banners || _section == _cards;
    final showBlocking = onOrders
        ? ordersAsync.isLoading && ordersAsync.asData?.value == null
        : onTabs
            ? tabsAsync.isLoading && tabsAsync.asData?.value == null
            : _section == _products
                ? async.isLoading && async.asData?.value == null
                : promosAsync.isLoading && promosAsync.asData?.value == null;
    final AsyncValue<Object> listError = onOrders
        ? ordersAsync
        : onTabs
            ? tabsAsync
            : _section == _products
                ? async
                : promosAsync;
    final sheetOpen = ref.watch(shellSheetDepthProvider) > 0;
    final tabs = (tabsAsync.asData?.value ?? const <StoreTaxonomyAdmin>[])
        .where((tab) {
      if (_q.isEmpty) return true;
      final haystack = '${tab.label} ${tab.slug}'.toLowerCase();
      return haystack.contains(_q.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AdminAppBar(
        title: 'Store',
        searchController: _search,
        searchHint: onOrders
            ? 'Search orders'
            : onTabs
                ? 'Search tabs'
                : onPromos
                    ? 'Search promos'
                    : 'Search products',
        onSearchChanged: _onSearchChanged,
        extraActions: [
          if (listError.isLoading && listError.asData?.value != null)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Categories & kinds',
            onPressed: AppHaptics.wrap(
              () => showStoreTaxonomySheet(context),
            ),
            icon: const Icon(Iconsax.category, size: 20),
          ),
        ],
      ),
      floatingActionButton: sheetOpen || onOrders
          ? null
          : FloatingActionButton(
              heroTag: 'products_add_fab',
              onPressed: AppHaptics.wrap(
                () => onTabs
                    ? _editTab()
                    : onPromos
                        ? _editPromo(_section)
                        : _edit(),
              ),
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width < 560
                    ? 560
                    : MediaQuery.sizeOf(context).width - 32,
                child: RubberSegment(
                  items: const [
                    RubberSegmentItem(value: _products, label: 'Products'),
                    RubberSegmentItem(value: _banners, label: 'Banners'),
                    RubberSegmentItem(value: _cards, label: 'Cards'),
                    RubberSegmentItem(value: _tabs, label: 'Tabs'),
                    RubberSegmentItem(value: _orders, label: 'Orders'),
                  ],
                  value: _section,
                  onChanged: (value) => setState(() => _section = value),
                ),
              ),
            ),
          ),
          Expanded(
            child: onOrders
                ? _orderList(ordersAsync, showBlocking)
                : onTabs
                    ? _tabList(tabsAsync, tabs, showBlocking)
                    : _section == _products
                        ? _productList(async, items, showBlocking)
                        : _promoList(promosAsync, promos, showBlocking),
          ),
        ],
      ),
    );
  }

  Widget _orderList(
    AsyncValue<List<ShopOrderAdmin>> async,
    bool showBlocking,
  ) {
    final orders = async.asData?.value ?? const <ShopOrderAdmin>[];
    return AsyncBody(
      loading: showBlocking,
      error: async.hasError && async.asData?.value == null
          ? async.error.toString()
          : null,
      onRetry: () => ref.refresh(shopOrdersProvider(_q).future),
      empty: !showBlocking && orders.isEmpty,
      emptyLabel: 'No website orders yet',
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(shopOrdersProvider(_q).future),
        child: ListView.separated(
          padding: PageInsets.page,
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: PageInsets.cardGap),
          itemBuilder: (_, i) {
            final order = orders[i];
            final when = DateTime.tryParse(order.createdAt)?.toLocal();
            final whenLabel = when == null
                ? ''
                : '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')}/${when.year}';
            final statusLabel = switch (order.status) {
              'paid' => 'Paid',
              'accepted' => 'Accepted',
              'rejected' => 'Rejected',
              _ => 'Waiting for payment',
            };
            return AdminListCard(
              margin: EdgeInsets.zero,
              onTap: AppHaptics.wrap(() async {
                final changed = await showOrderDetailSheet(context, order);
                if (changed) {
                  await ref.refresh(shopOrdersProvider(_q).future);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.customerName.isEmpty ? order.email : order.customerName,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          order.amountLabel,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _OrderPhotoStack(items: order.items),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: HpColors.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (order.deliveryLine.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        order.deliveryLine,
                        style: GoogleFonts.outfit(fontSize: 13, color: HpColors.mutedForeground),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          statusLabel,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: order.status == 'paid' || order.status == 'accepted'
                                ? HpColors.primary
                                : HpColors.mutedForeground,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          whenLabel,
                          style: GoogleFonts.outfit(fontSize: 12, color: HpColors.mutedForeground),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _productList(
    AsyncValue<List<StoreProductAdmin>> async,
    List<StoreProductAdmin> items,
    bool showBlocking,
  ) {
    return AsyncBody(
        loading: showBlocking,
        error: async.hasError && async.asData?.value == null
            ? async.error.toString()
            : null,
        onRetry: () => ref.refresh(storeProductsProvider(_q).future),
        empty: !showBlocking && items.isEmpty,
        emptyLabel: 'No products yet',
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(storeProductsProvider(_q).future),
          child: ListView.separated(
            padding: PageInsets.page,
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: PageInsets.cardGap),
            itemBuilder: (_, i) {
              final p = items[i];
              return AdminListCard(
                margin: EdgeInsets.zero,
                onTap: AppHaptics.wrap(() => _edit(p)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: _isNetwork(p.imageUrl)
                              ? Image.network(
                                  p.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => ColoredBox(
                                    color: HpColors.subtle,
                                    child: Icon(
                                      Iconsax.shop,
                                      color: HpColors.mutedForeground,
                                    ),
                                  ),
                                )
                              : ColoredBox(
                                  color: HpColors.subtle,
                                  child: Icon(
                                    Iconsax.shop,
                                    color: HpColors.mutedForeground,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: CardTitle(p.title)),
                                if (p.comingSoon)
                                  Text(
                                    'Coming soon',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: HpColors.mutedForeground,
                                    ),
                                  )
                                else if (!p.active)
                                  Text(
                                    'Hidden',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: HpColors.mutedForeground,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            MetaText(
                              [
                                p.category,
                                p.kind,
                                p.priceLabel,
                                if (p.planId != null) 'plan:${p.planId}',
                              ].join(' · '),
                            ),
                            if (p.subtitle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                p.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: HpColors.mutedForeground,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: AppHaptics.wrap(() => _delete(p)),
                        icon: const Icon(Iconsax.trash, size: 18),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
    );
  }

  Widget _promoList(
    AsyncValue<List<ShopPromoAdmin>> async,
    List<ShopPromoAdmin> items,
    bool showBlocking,
  ) {
    final emptyLabel =
        _section == _banners ? 'No banners yet' : 'No card promos yet';
    return AsyncBody(
      loading: showBlocking,
      error: async.hasError && async.asData?.value == null
          ? async.error.toString()
          : null,
      onRetry: () => ref.refresh(shopPromosProvider(_section).future),
      empty: !showBlocking && items.isEmpty,
      emptyLabel: emptyLabel,
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(shopPromosProvider(_section).future),
        child: ListView.separated(
          padding: PageInsets.page,
          itemCount: items.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: PageInsets.cardGap),
          itemBuilder: (_, i) {
            final promo = items[i];
            final title = promo.label.isNotEmpty ? promo.label : promo.alt;
            return AdminListCard(
              margin: EdgeInsets.zero,
              onTap: AppHaptics.wrap(() => _editPromo(promo.placement, promo)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: _isNetwork(promo.imageUrl)
                            ? Image.network(
                                promo.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => ColoredBox(
                                  color: HpColors.subtle,
                                  child: Icon(
                                    Iconsax.gallery,
                                    color: HpColors.mutedForeground,
                                  ),
                                ),
                              )
                            : ColoredBox(
                                color: HpColors.subtle,
                                child: Icon(
                                  Iconsax.gallery,
                                  color: HpColors.mutedForeground,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: CardTitle(title)),
                              if (!promo.active)
                                Text(
                                  'Hidden',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: HpColors.mutedForeground,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          MetaText(
                            [
                              if (promo.category.isNotEmpty) promo.category,
                              'sort ${promo.sortOrder}',
                            ].join(' · '),
                          ),
                          if (promo.label.isNotEmpty && promo.alt.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              promo.alt,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: HpColors.mutedForeground,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: AppHaptics.wrap(() => _deletePromo(promo)),
                      icon: const Icon(Iconsax.trash, size: 18),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tabList(
    AsyncValue<List<StoreTaxonomyAdmin>> async,
    List<StoreTaxonomyAdmin> items,
    bool showBlocking,
  ) {
    return AsyncBody(
      loading: showBlocking,
      error: async.hasError && async.asData?.value == null
          ? async.error.toString()
          : null,
      onRetry: () => ref.refresh(storeCategoriesProvider.future),
      empty: !showBlocking && items.isEmpty,
      emptyLabel: 'No tabs yet',
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(storeCategoriesProvider.future),
        child: ListView.separated(
          padding: PageInsets.page,
          itemCount: items.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: PageInsets.cardGap),
          itemBuilder: (_, i) {
            final tab = items[i];
            return AdminListCard(
              margin: EdgeInsets.zero,
              onTap: AppHaptics.wrap(() => _editTab(tab)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: CardTitle(tab.label)),
                              if (tab.comingSoon)
                                Text(
                                  'Coming soon',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: HpColors.mutedForeground,
                                  ),
                                )
                              else if (!tab.active)
                                Text(
                                  'Hidden',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: HpColors.mutedForeground,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          MetaText('${tab.slug} · sort ${tab.sortOrder}'),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: AppHaptics.wrap(() => _deleteTab(tab)),
                      icon: const Icon(Iconsax.trash, size: 18),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrderPhotoStack extends StatelessWidget {
  const _OrderPhotoStack({required this.items});

  final List<ShopOrderItemAdmin> items;

  @override
  Widget build(BuildContext context) {
    final photos = items.take(3).toList();
    if (photos.isEmpty) return const SizedBox(width: 36, height: 36);
    final width = 36.0 + (photos.length - 1) * 18;
    return SizedBox(
      width: width,
      height: 36,
      child: Stack(
        children: [
          for (var i = 0; i < photos.length; i++)
            Positioned(
              left: i * 18,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: HpColors.card, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _OrderThumb(url: photos[i].image),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderThumb extends StatelessWidget {
  const _OrderThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final network = url.startsWith('http://') || url.startsWith('https://');
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 32,
        height: 32,
        child: network
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(color: HpColors.subtle),
              )
            : const ColoredBox(
                color: HpColors.subtle,
                child: Icon(Icons.image_outlined, size: 14),
              ),
      ),
    );
  }
}
