import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/tenant_provider.dart';
import '../../../core/theme/dokko_tokens.dart';
import '../../../core/widgets/dokko_button.dart';
import '../../../core/widgets/dokko_card.dart';
import '../../../core/widgets/dokko_empty_state.dart';
import 'pos_data_source.dart';

// ─── Imagen de producto ───────────────────────────────────────────────────────
typedef ProductImagePicked = ({Uint8List bytes, String ext});
typedef ProductImagePicker = Future<ProductImagePicked> Function();

final productImagePickerProvider = Provider<ProductImagePicker>(
  (_) => _defaultPickProductImage,
);

Future<ProductImagePicked> _defaultPickProductImage() async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
  );
  if (files.isEmpty) {
    throw StateError('No se seleccionó ninguna imagen.');
  }
  final file = files.first;
  return (bytes: await file.readAsBytes(), ext: file.extension ?? 'png');
}

// ─── Cart item model ──────────────────────────────────────────────────────────
class _CartItem {
  final Map<String, dynamic> product;
  int qty;
  _CartItem({required this.product, required this.qty});

  double get subtotal {
    final price = product['price'];
    final p = price is num
        ? price.toDouble()
        : num.tryParse(price.toString())?.toDouble();
    return (p ?? 0) * qty;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main POS Screen — componente compartido (FASE 13 gym, FASE 22 salón)
// ─────────────────────────────────────────────────────────────────────────────
class PosScreen extends ConsumerStatefulWidget {
  final PosDataSource dataSource;

  const PosScreen({super.key, required this.dataSource});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  PosDataSource get _ds => widget.dataSource;

  // Catalog state
  List<dynamic> _products = [];
  bool _isLoadingProducts = true;
  String _searchQuery = '';

  // Cart state
  final List<_CartItem> _cart = [];
  String _paymentMethod = 'cash';
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  String? _selectedStaffId;
  String? _selectedStaffName;
  bool _isProcessingSale = false;

  // Sales history
  List<dynamic> _sales = [];
  bool _isLoadingSales = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchProducts();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final products = await _ds.fetchProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('fetchProducts falló: $e');
      setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _fetchSales() async {
    setState(() => _isLoadingSales = true);
    try {
      final sales = await _ds.fetchSales();
      if (!mounted) return;
      setState(() {
        _sales = sales;
        _isLoadingSales = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingSales = false);
    }
  }

List<dynamic> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    final q = _searchQuery.toLowerCase();
    return _products
        .where((p) =>
            (p['name'] as String? ?? '').toLowerCase().contains(q) ||
            (p['category'] as String? ?? '').toLowerCase().contains(q) ||
            (p['sku'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  int get _lowStockCount => _products.where((p) {
        final s = p['stock_quantity'] as int? ?? 0;
        final a = p['stock_alert_threshold'] as int? ?? 5;
        return s > 0 && s <= a;
      }).length;

  void _addToCart(Map<String, dynamic> product) {
    final stock = product['stock_quantity'] as int? ?? 0;
    final existing = _cart.indexWhere((i) => i.product['id'] == product['id']);
    if (existing >= 0) {
      if (_cart[existing].qty >= stock) {
        _showSnack('Stock insuficiente para ${product['name']}');
        return;
      }
      setState(() => _cart[existing].qty++);
    } else {
      if (stock <= 0) {
        _showSnack('Sin stock disponible para ${product['name']}');
        return;
      }
      setState(() => _cart.add(_CartItem(product: product, qty: 1)));
    }
  }

  void _removeFromCart(int index) => setState(() => _cart.removeAt(index));

  void _updateQty(int index, int delta) {
    final newQty = _cart[index].qty + delta;
    final stock = _cart[index].product['stock_quantity'] as int? ?? 0;
    if (newQty <= 0) {
      _removeFromCart(index);
    } else if (newQty > stock) {
      _showSnack('Stock insuficiente');
    } else {
      setState(() => _cart[index].qty = newQty);
    }
  }

  double get _cartTotal =>
      _cart.fold(0.0, (sum, item) => sum + item.subtotal);

  void _clearCart() => setState(() {
        _cart.clear();
        _selectedCustomerId = null;
        _selectedCustomerName = null;
        _selectedStaffId = null;
        _selectedStaffName = null;
        _paymentMethod = 'cash';
      });

  Future<void> _processSale() async {
    if (_cart.isEmpty) return;
    setState(() => _isProcessingSale = true);
    try {
      await _ds.createSale({
        'payment_method': _paymentMethod,
        'customer_id': _selectedCustomerId,
        'staff_id': _selectedStaffId,
        'items': _cart
            .map((i) => {
                  'product_id': i.product['id'],
                  'quantity': i.qty,
                  'unit_price': i.product['price'],
                })
            .toList(),
      });
      if (!mounted) return;
      _showSnack('✅ Venta registrada por \$${_cartTotal.toStringAsFixed(2)}',
          isSuccess: true);
      _clearCart();
      await _fetchProducts(); // refresh stock
    } catch (e) {
      if (!mounted) return;
      _showSnack('❌ Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessingSale = false);
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isSuccess ? DokkoTokens.green : DokkoTokens.surface,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openProductModal({Map<String, dynamic>? product}) {
    showDialog(
      context: context,
      builder: (_) => _ProductModal(
        dataSource: _ds,
        product: product,
        onSaved: _fetchProducts,
      ),
    );
  }

  Future<void> _selectCustomer() async {
    final customers = await _ds.fetchCustomers();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => _PersonPickerDialog(
        title: 'Seleccionar Cliente',
        people: customers,
        onSelected: (m) {
          setState(() {
            _selectedCustomerId = m['id'].toString();
            _selectedCustomerName = '${m['first_name']} ${m['last_name']}';
          });
        },
      ),
    );
  }

  Future<void> _selectStaff() async {
    final staff = await _ds.fetchStaff();
    if (staff == null || !mounted) return;
    showDialog(
      context: context,
      builder: (_) => _PersonPickerDialog(
        title: 'Seleccionar Estilista',
        people: staff,
        onSelected: (m) {
          setState(() {
            _selectedStaffId = m['id'].toString();
            _selectedStaffName = '${m['first_name']} ${m['last_name']}';
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DokkoTokens.bg,
      body: Column(
        children: [
          // ── Header with tabs ──────────────────────────────────────────────
          Container(
            color: DokkoTokens.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: DokkoTokens.space24,
              vertical: DokkoTokens.space16,
            ),
            child: Row(
              children: [
                Text(
                  _ds.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: DokkoTokens.text,
                  ),
                ),
                const SizedBox(width: DokkoTokens.space24),
                TabBar(
                  controller: _tabCtrl,
                  isScrollable: true,
                  labelColor: DokkoTokens.accentDefault,
                  unselectedLabelColor: DokkoTokens.text2,
                  indicatorColor: DokkoTokens.accentDefault,
                  tabs: const [
                    Tab(text: 'Punto de Venta'),
                    Tab(text: 'Historial'),
                  ],
                  onTap: (i) {
                    if (i == 1 && _sales.isEmpty) _fetchSales();
                  },
                ),
                const Spacer(),
                DokkoButton(
                  label: 'Gestionar Productos',
                  variant: DokkoButtonVariant.secondary,
                  onPressed: () => _openProductModal(),
                ),
              ],
            ),
          ),
          // ── Tab body ──────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildPosTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── POS Tab ──────────────────────────────────────────────────────────────
  Widget _buildPosTab() {
    return Padding(
      padding: const EdgeInsets.all(DokkoTokens.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: catalog
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Search
                TextField(
                  style: const TextStyle(color: DokkoTokens.text),
                  decoration: InputDecoration(
                    hintText: 'Buscar producto...',
                    hintStyle:
                        const TextStyle(color: DokkoTokens.text3),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: DokkoTokens.text2),
                    filled: true,
                    fillColor: DokkoTokens.surface,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DokkoTokens.radiusMd),
                      borderSide:
                          const BorderSide(color: DokkoTokens.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DokkoTokens.radiusMd),
                      borderSide:
                          const BorderSide(color: DokkoTokens.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DokkoTokens.radiusMd),
                      borderSide: const BorderSide(
                          color: DokkoTokens.accentDefault),
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: DokkoTokens.space12),
                // Alerta de stock bajo
                if (_lowStockCount > 0) ...[
                  _LowStockBanner(
                    count: _lowStockCount,
                    onAction: () {
                      final low = _products.where((p) {
                        final s = p['stock_quantity'] as int? ?? 0;
                        final a = p['stock_alert_threshold'] as int? ?? 5;
                        return s > 0 && s <= a;
                      }).toList();
                      if (low.isEmpty) return;
                      _openProductModal(product: low.first);
                    },
                  ),
                  const SizedBox(height: DokkoTokens.space12),
                ],
                // Grid
                Expanded(
                  child: _isLoadingProducts
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredProducts.isEmpty
                          ? DokkoEmptyState(
                              icon: Icons.inventory_2_rounded,
                              message: _searchQuery.isEmpty
                                  ? 'Sin productos.\nPresiona "Gestionar Productos" para añadir uno.'
                                  : 'Sin resultados para "$_searchQuery"',
                            )
                          : GridView.builder(
                              gridDelegate:
const SliverGridDelegateWithMaxCrossAxisExtent(
                                 maxCrossAxisExtent: 220,
                                 mainAxisExtent: 230,
                                 crossAxisSpacing: DokkoTokens.space8,
                                 mainAxisSpacing: DokkoTokens.space8,
                               ),
                              itemCount: _filteredProducts.length,
                              itemBuilder: (ctx, i) =>
                                  _ProductTile(
                                product: _filteredProducts[i],
                                onTap: () =>
                                    _addToCart(_filteredProducts[i]),
                                onEdit: () => _openProductModal(
                                    product: _filteredProducts[i]),
                              ),
                            ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DokkoTokens.space16),
          // Right: Cart
          SizedBox(
            width: 320,
            child: _buildCart(),
          ),
        ],
      ),
    );
  }

  Widget _buildCart() {
    return DokkoCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cart header
          Padding(
            padding: const EdgeInsets.all(DokkoTokens.space16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Venta Actual',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: DokkoTokens.text)),
                if (_cart.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded,
                        color: DokkoTokens.text2, size: 18),
                    onPressed: _clearCart,
                    tooltip: 'Vaciar carrito',
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: DokkoTokens.line),

          // Items
          Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 36, color: DokkoTokens.text3),
                        SizedBox(height: 8),
                        Text('Toca un producto para añadir',
                            style: TextStyle(
                                color: DokkoTokens.text2,
                                fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        vertical: DokkoTokens.space8),
                    itemCount: _cart.length,
                    separatorBuilder: (ctx, i) =>
                        const Divider(height: 1, color: DokkoTokens.line),
                    itemBuilder: (ctx, i) => _CartRow(
                      item: _cart[i],
                      onIncrease: () => _updateQty(i, 1),
                      onDecrease: () => _updateQty(i, -1),
                      onRemove: () => _removeFromCart(i),
                    ),
                  ),
          ),

          const Divider(height: 1, color: DokkoTokens.line),

          // Footer: total + checkout
          Padding(
            padding: const EdgeInsets.all(DokkoTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Customer (optional)
                GestureDetector(
                  onTap: _selectCustomer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: DokkoTokens.space12,
                        vertical: DokkoTokens.space8),
                    decoration: BoxDecoration(
                      color: DokkoTokens.surface2,
                      borderRadius:
                          BorderRadius.circular(DokkoTokens.radiusMd),
                      border: Border.all(color: DokkoTokens.line),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 16, color: DokkoTokens.text2),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedCustomerName ?? _ds.customerLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: _selectedCustomerName != null
                                  ? DokkoTokens.text
                                  : DokkoTokens.text3,
                            ),
                          ),
                        ),
                        if (_selectedCustomerId != null)
                          GestureDetector(
                            onTap: () => setState(() {
                              _selectedCustomerId = null;
                              _selectedCustomerName = null;
                            }),
                            child: const Icon(Icons.close_rounded,
                                size: 14, color: DokkoTokens.text2),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_ds.hasStaff) ...[
                  const SizedBox(height: DokkoTokens.space8),
                  GestureDetector(
                    onTap: _selectStaff,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: DokkoTokens.space12,
                          vertical: DokkoTokens.space8),
                      decoration: BoxDecoration(
                        color: DokkoTokens.surface2,
                        borderRadius:
                            BorderRadius.circular(DokkoTokens.radiusMd),
                        border: Border.all(color: DokkoTokens.line),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.face_retouching_natural_rounded,
                              size: 16, color: DokkoTokens.text2),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedStaffName ?? _ds.staffLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: _selectedStaffName != null
                                    ? DokkoTokens.text
                                    : DokkoTokens.text3,
                              ),
                            ),
                          ),
                          if (_selectedStaffId != null)
                            GestureDetector(
                              onTap: () => setState(() {
                                _selectedStaffId = null;
                                _selectedStaffName = null;
                              }),
                              child: const Icon(Icons.close_rounded,
                                  size: 14, color: DokkoTokens.text2),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: DokkoTokens.space8),

                // Payment method
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  dropdownColor: DokkoTokens.surface,
                  style: const TextStyle(color: DokkoTokens.text, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: DokkoTokens.surface2,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DokkoTokens.radiusMd),
                      borderSide:
                          const BorderSide(color: DokkoTokens.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DokkoTokens.radiusMd),
                      borderSide:
                          const BorderSide(color: DokkoTokens.line),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
                    DropdownMenuItem(value: 'card', child: Text('Tarjeta')),
                    DropdownMenuItem(
                        value: 'transfer', child: Text('Transferencia')),
                  ],
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                ),
                const SizedBox(height: DokkoTokens.space12),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: DokkoTokens.text)),
                    Text(
                      '\$${_cartTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: DokkoTokens.accentDefault,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DokkoTokens.space12),

                // Cobrar button
                DokkoButton(
                  label: 'Cobrar \$${_cartTotal.toStringAsFixed(2)}',
                  isLoading: _isProcessingSale,
                  onPressed: _cart.isEmpty ? null : _processSale,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── History Tab ──────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    return Padding(
      padding: const EdgeInsets.all(DokkoTokens.space16),
      child: DokkoCard(
        padding: EdgeInsets.zero,
        child: _isLoadingSales
            ? const Center(child: CircularProgressIndicator())
            : _sales.isEmpty
                ? const DokkoEmptyState(
                    icon: Icons.receipt_long_rounded,
                    message: 'Sin ventas registradas aún.',
                  )
                : Column(
                    children: [
                      // Table header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: DokkoTokens.space16,
                            vertical: DokkoTokens.space12),
                        decoration: const BoxDecoration(
                          color: DokkoTokens.surface2,
                          border: Border(
                              bottom: BorderSide(color: DokkoTokens.line)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                                child: Text('Fecha',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: DokkoTokens.text2,
                                        fontWeight: FontWeight.w500))),
                            Expanded(
                                child: Text('Método',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: DokkoTokens.text2,
                                        fontWeight: FontWeight.w500))),
                            SizedBox(
                              width: 100,
                              child: Text('Total',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: DokkoTokens.text2,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _sales.length,
                          separatorBuilder: (ctx, i) => const Divider(
                              height: 1, color: DokkoTokens.line),
                          itemBuilder: (ctx, i) {
                            final s = _sales[i];
                            final soldAt =
                                DateTime.tryParse(s['sold_at'] ?? '');
                            final dateStr = soldAt != null
                                ? '${soldAt.day}/${soldAt.month}/${soldAt.year} ${soldAt.hour.toString().padLeft(2, '0')}:${soldAt.minute.toString().padLeft(2, '0')}'
                                : '—';
                            final method = s['payment_method'] ?? '—';
                            final total = s['total'] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: DokkoTokens.space16,
                                  vertical: DokkoTokens.space12),
                              child: Row(
                                children: [
                                  Expanded(
                                      child: Text(dateStr,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: DokkoTokens.text))),
                                  Expanded(
                                      child: Text(_methodLabel(method),
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: DokkoTokens.text))),
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      '\$$total',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: DokkoTokens.green),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'cash':     return 'Efectivo';
      case 'card':     return 'Tarjeta';
      case 'transfer': return 'Transferencia';
      default:         return method;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product Tile (catalog grid)
// ─────────────────────────────────────────────────────────────────────────────
class _ProductTile extends StatelessWidget {
  final dynamic product;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ProductTile({
    required this.product,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final stock = product['stock_quantity'] as int? ?? 0;
    final alert = product['stock_alert_threshold'] as int? ?? 5;
    final outOfStock = stock <= 0;
    final lowStock = !outOfStock && stock <= alert;

    return GestureDetector(
      onTap: outOfStock ? null : onTap,
      child: AnimatedOpacity(
        opacity: outOfStock ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: DokkoCard(
          padding: const EdgeInsets.all(DokkoTokens.space12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen del producto (estilo tienda)
              ClipRRect(
                borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
                child: Stack(
                  children: [
                    Container(
                      height: 88,
                      width: double.infinity,
                      color: DokkoTokens.surface2,
                      child: _imageUrl(product) == null
                          ? Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: DokkoTokens.text3,
                                size: 28,
                              ),
                            )
                          : Image.network(
                              _imageUrl(product)!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: DokkoTokens.text3,
                                  size: 28,
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onEdit,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DokkoTokens.space4),
              Flexible(
                child: Text(
                  product['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: DokkoTokens.text,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: DokkoTokens.space4),
              Text(
                '\$${product['price']}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: DokkoTokens.accentDefault,
                ),
              ),
              const SizedBox(height: DokkoTokens.space4),
              Row(
                children: [
                  Icon(
                    outOfStock
                        ? Icons.remove_circle_outline_rounded
                        : lowStock
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                    size: 12,
                    color: outOfStock
                        ? DokkoTokens.red
                        : lowStock
                            ? DokkoTokens.amber
                            : DokkoTokens.green,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      outOfStock ? 'Sin stock' : 'Stock: $stock',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: outOfStock
                            ? DokkoTokens.red
                            : lowStock
                                ? DokkoTokens.amber
                                : DokkoTokens.text2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (lowStock)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: DokkoTokens.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text(
                          '¡Poco stock!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: DokkoTokens.amber),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _imageUrl(dynamic product) {
    final url = product['image_url'];
    if (url is String && url.isNotEmpty) return url;
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner de stock bajo
// ─────────────────────────────────────────────────────────────────────────────
class _LowStockBanner extends StatelessWidget {
  final int count;
  final VoidCallback? onAction;
  const _LowStockBanner({required this.count, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DokkoTokens.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
        border: Border.all(color: DokkoTokens.amber.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: DokkoTokens.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count == 1
                  ? '1 producto con stock bajo'
                  : '$count productos con stock bajo',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DokkoTokens.amber,
              ),
            ),
          ),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              child: const Text('Reabastecer',
                  style: TextStyle(
                      color: DokkoTokens.amber, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cart Row
// ─────────────────────────────────────────────────────────────────────────────
class _CartRow extends StatelessWidget {
  final _CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  const _CartRow({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: DokkoTokens.space12, vertical: DokkoTokens.space8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product['name'] ?? '',
                    style: const TextStyle(
                        fontSize: 13, color: DokkoTokens.text),
                    overflow: TextOverflow.ellipsis),
                Text('\$${item.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 12, color: DokkoTokens.text2)),
              ],
            ),
          ),
          // Qty controls
          Row(
            children: [
              _QtyBtn(icon: Icons.remove_rounded, onTap: onDecrease),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: DokkoTokens.space8),
                child: Text('${item.qty}',
                    style: const TextStyle(
                        fontSize: 14, color: DokkoTokens.text)),
              ),
              _QtyBtn(icon: Icons.add_rounded, onTap: onIncrease),
              const SizedBox(width: DokkoTokens.space4),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.close_rounded,
                    size: 14, color: DokkoTokens.text3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: DokkoTokens.surface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: DokkoTokens.line),
        ),
        child: Icon(icon, size: 14, color: DokkoTokens.text2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product Modal (create / edit)
// ─────────────────────────────────────────────────────────────────────────────
class _ProductModal extends ConsumerStatefulWidget {
  final PosDataSource dataSource;
  final Map<String, dynamic>? product;
  final VoidCallback onSaved;

  const _ProductModal({
    required this.dataSource,
    this.product,
    required this.onSaved,
  });

  @override
  ConsumerState<_ProductModal> createState() => _ProductModalState();
}

class _ProductModalState extends ConsumerState<_ProductModal> {
  final _nameCtrl    = TextEditingController();
  final _skuCtrl     = TextEditingController();
  final _priceCtrl   = TextEditingController();
  final _stockCtrl   = TextEditingController();
  final _alertCtrl   = TextEditingController();
  String _category   = 'general';
  bool _isLoading    = false;

  Uint8List? _imageBytes;
  String _imageExt    = 'png';
  String? _imageUrl;
  String? _imageError;

  bool get _hasImage =>
      _imageBytes != null || (_imageUrl != null && _imageUrl!.isNotEmpty);

  static const _categories = [
    'general', 'suplementos', 'bebidas', 'ropa', 'accesorios', 'equipamiento',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      final p = widget.product!;
      _nameCtrl.text  = p['name'] ?? '';
      _skuCtrl.text   = p['sku'] ?? '';
      _priceCtrl.text = p['price'].toString();
      _stockCtrl.text = p['stock_quantity'].toString();
      _alertCtrl.text = (p['stock_alert_threshold'] ?? 5).toString();
      _category       = p['category'] ?? 'general';
      _imageUrl       = p['image_url'] as String?;
    } else {
      _stockCtrl.text = '0';
      _alertCtrl.text = '5';
    }
  }

  Future<void> _pickImage() async {
    setState(() => _imageError = null);
    try {
      final picked = await ref.read(productImagePickerProvider)();
      if (!mounted) return;
      setState(() {
        _imageBytes = picked.bytes;
        _imageExt = picked.ext;
      });
      debugPrint('Imagen de producto cargada (${picked.bytes.length} bytes)');
    } catch (e) {
      if (!mounted) return;
      setState(() => _imageError = 'No se pudo cargar la imagen: $e');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _alertCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name  = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text);
    final stock = int.tryParse(_stockCtrl.text) ?? 0;
    final alert = int.tryParse(_alertCtrl.text) ?? 5;
    if (name.isEmpty || price == null) return;

    setState(() {
      _isLoading = true;
      _imageError = null;
    });
    try {
      String? imageUrl = _imageUrl;
      if (_imageBytes != null) {
        final tenantId = ref.read(tenantProvider).value?.tenantId;
        if (tenantId == null) {
          throw StateError('No se pudo identificar el negocio.');
        }
        final path =
            '$tenantId/${DateTime.now().millisecondsSinceEpoch}.$_imageExt';
        try {
          await Supabase.instance.client.storage
              .from('product-images')
              .uploadBinary(path, _imageBytes!,
                  fileOptions: const FileOptions(upsert: true));
          imageUrl = Supabase.instance.client.storage
              .from('product-images')
              .getPublicUrl(path);
        } catch (e) {
          debugPrint('Upload de imagen a Supabase Storage falló: $e');
          if (mounted && _imageBytes != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Aviso: no se pudo subir la imagen (revisa el bucket "product-images"). Se guardará el producto sin imagen.'),
              ),
            );
          }
        }
      }

      final api = widget.dataSource;
      final body = {
        'name': name,
        'sku': _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
        'price': price,
        'category': _category,
        'stock_quantity': stock,
        'stock_alert_threshold': alert,
        'image_url': ?imageUrl,
      };
      if (widget.product == null) {
        await api.createProduct(body);
      } else {
        await api.updateProduct(widget.product!['id'].toString(), body);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: DokkoTokens.text3),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: DokkoTokens.space12, vertical: DokkoTokens.space8),
        filled: true,
        fillColor: DokkoTokens.surface2,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
            borderSide: const BorderSide(color: DokkoTokens.line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
            borderSide: const BorderSide(color: DokkoTokens.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
            borderSide: const BorderSide(color: DokkoTokens.accentDefault)),
      );

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    return Dialog(
      backgroundColor: DokkoTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
        side: const BorderSide(color: DokkoTokens.line),
      ),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(DokkoTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(isEditing ? 'Editar Producto' : 'Nuevo Producto',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: DokkoTokens.text)),
              const SizedBox(height: DokkoTokens.space20),

              // Imagen del producto (obligatoria)
              ClipRRect(
                borderRadius: BorderRadius.circular(DokkoTokens.radiusMd),
                child: Container(
                  height: 100,
                  color: DokkoTokens.surface2,
                  width: double.infinity,
                  child: !_hasImage
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_photo_alternate_outlined,
                                  color: DokkoTokens.text3, size: 28),
                              const SizedBox(height: 6),
                              const Text(
                                'Imagen del producto (obligatoria)',
                                style: TextStyle(
                                    fontSize: 12, color: DokkoTokens.text3),
                              ),
                            ],
                          ),
                        )
                      : _imageBytes != null
                          ? Image.memory(
                              _imageBytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(Icons.broken_image_outlined,
                                    color: DokkoTokens.text3),
                              ),
                            )
                          : Image.network(
                              _imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(Icons.broken_image_outlined,
                                    color: DokkoTokens.text3),
                              ),
                            ),
                ),
              ),
              const SizedBox(height: DokkoTokens.space8),
              Row(
                children: [
                  DokkoButton(
                    label: _hasImage ? 'Cambiar imagen' : 'Subir imagen',
                    variant: DokkoButtonVariant.secondary,
                    onPressed: _pickImage,
                  ),
                  const SizedBox(width: DokkoTokens.space8),
                  if (_imageError != null)
                    Expanded(
                      child: Text(
                        _imageError!,
                        style: const TextStyle(
                            fontSize: 11, color: DokkoTokens.red),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: DokkoTokens.space16),

              // Name + SKU
              Row(children: [
                Expanded(
                  flex: 2,
                  child: _Field(label: 'Nombre *', child: TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: DokkoTokens.text),
                      decoration: _dec('Proteína Whey 1kg'))),
                ),
                const SizedBox(width: DokkoTokens.space12),
                Expanded(
                  child: _Field(label: 'SKU', child: TextField(
                      controller: _skuCtrl,
                      style: const TextStyle(color: DokkoTokens.text),
                      decoration: _dec('PROT-001'))),
                ),
              ]),
              const SizedBox(height: DokkoTokens.space16),

              // Price + Category
              Row(children: [
                Expanded(
                  child: _Field(label: 'Precio *', child: TextField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: DokkoTokens.text),
                      decoration: _dec('0.00').copyWith(
                          prefixText: '\$ ',
                          prefixStyle: const TextStyle(color: DokkoTokens.text2)))),
                ),
                const SizedBox(width: DokkoTokens.space12),
                Expanded(
                  child: _Field(
                    label: 'Categoría',
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      dropdownColor: DokkoTokens.surface,
                      style: const TextStyle(color: DokkoTokens.text, fontSize: 14),
                      decoration: _dec(''),
                      items: _categories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: DokkoTokens.space16),

              // Stock + Alert
              Row(children: [
                Expanded(
                  child: _Field(label: 'Stock inicial', child: TextField(
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: DokkoTokens.text),
                      decoration: _dec('0'))),
                ),
                const SizedBox(width: DokkoTokens.space12),
                Expanded(
                  child: _Field(label: 'Alerta stock bajo', child: TextField(
                      controller: _alertCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: DokkoTokens.text),
                      decoration: _dec('5'))),
                ),
              ]),
              const SizedBox(height: DokkoTokens.space24),

              // Actions
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                DokkoButton(
                    label: 'Cancelar',
                    variant: DokkoButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop()),
                const SizedBox(width: DokkoTokens.space12),
                DokkoButton(
                    label: isEditing ? 'Guardar' : 'Crear',
                    isLoading: _isLoading,
                    onPressed: _submit),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: DokkoTokens.text2)),
          const SizedBox(height: DokkoTokens.space4),
          child,
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Member Picker Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _PersonPickerDialog extends StatefulWidget {
  final String title;
  final List<dynamic> people;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const _PersonPickerDialog(
      {required this.title, required this.people, required this.onSelected});

  @override
  State<_PersonPickerDialog> createState() => _PersonPickerDialogState();
}

class _PersonPickerDialogState extends State<_PersonPickerDialog> {
  String _q = '';

  List<dynamic> get _filtered {
    if (_q.isEmpty) return widget.people;
    final q = _q.toLowerCase();
    return widget.people.where((m) {
      final name = '${m['first_name']} ${m['last_name']}'.toLowerCase();
      return name.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DokkoTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DokkoTokens.radiusLg),
        side: const BorderSide(color: DokkoTokens.line),
      ),
      child: SizedBox(
        width: 360,
        height: 480,
        child: Padding(
          padding: const EdgeInsets.all(DokkoTokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: DokkoTokens.text)),
              const SizedBox(height: DokkoTokens.space12),
              TextField(
                autofocus: true,
                style: const TextStyle(color: DokkoTokens.text),
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  hintStyle: const TextStyle(color: DokkoTokens.text3),
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: DokkoTokens.text2),
                  filled: true,
                  fillColor: DokkoTokens.surface2,
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DokkoTokens.radiusMd),
                      borderSide: const BorderSide(color: DokkoTokens.line)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DokkoTokens.radiusMd),
                      borderSide: const BorderSide(color: DokkoTokens.line)),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
              const SizedBox(height: DokkoTokens.space8),
              Expanded(
                child: ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (ctx, i) {
                    final m = _filtered[i];
                    return ListTile(
                      title: Text(
                          '${m['first_name']} ${m['last_name']}',
                          style: const TextStyle(
                              fontSize: 14, color: DokkoTokens.text)),
                      subtitle: Text(m['email'] ?? '',
                          style: const TextStyle(
                              fontSize: 12, color: DokkoTokens.text2)),
                      onTap: () {
                        widget.onSelected(m);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
