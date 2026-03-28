import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../blocs/auth/auth_bloc.dart';
import '../database/database.dart' as db;
import '../models/models.dart' as domain;
import '../repositories/customer_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/sale_repository.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<_NavItem> _storeNavItems = const [
    _NavItem(
      key: 'dashboard',
      label: 'Dashboard',
      icon: Icons.dashboard_rounded,
    ),
    _NavItem(key: 'pos', label: 'POS', icon: Icons.point_of_sale_rounded),
    _NavItem(
      key: 'products',
      label: 'Products',
      icon: Icons.inventory_2_rounded,
    ),
    _NavItem(key: 'sales', label: 'Sales', icon: Icons.receipt_long_rounded),
    _NavItem(key: 'customers', label: 'Customers', icon: Icons.groups_rounded),
    _NavItem(
      key: 'inventory',
      label: 'Inventory',
      icon: Icons.warehouse_rounded,
    ),
    _NavItem(key: 'employees', label: 'Employees', icon: Icons.badge_rounded),
    _NavItem(key: 'users', label: 'Users', icon: Icons.manage_accounts_rounded),
    _NavItem(key: 'reports', label: 'Reports', icon: Icons.bar_chart_rounded),
    _NavItem(key: 'settings', label: 'Settings', icon: Icons.settings_rounded),
    _NavItem(
      key: 'marketing',
      label: 'Marketing',
      icon: Icons.campaign_rounded,
    ),
    _NavItem(key: 'services', label: 'Services', icon: Icons.build_rounded),
    _NavItem(
      key: 'suppliers',
      label: 'Suppliers',
      icon: Icons.local_shipping_rounded,
    ),
    _NavItem(
      key: 'invoices',
      label: 'Invoices',
      icon: Icons.request_page_rounded,
    ),
    _NavItem(key: 'sync', label: 'Sync Manager', icon: Icons.sync_rounded),
  ];

  List<Map<String, dynamic>> _storeLogins = [];
  bool _isCreatingStore = false;
  String _selectedNavKey = 'dashboard';

  final List<_ProductItem> _products = [
    _ProductItem(
      id: 'P001',
      name: 'Chicken Burger',
      category: 'Food',
      price: 1200,
      stock: 30,
      minStock: 8,
      barcode: 'P001',
    ),
    _ProductItem(
      id: 'P002',
      name: 'Coke 500ml',
      category: 'Beverage',
      price: 350,
      stock: 55,
      minStock: 12,
      barcode: 'P002',
    ),
    _ProductItem(
      id: 'P003',
      name: 'French Fries',
      category: 'Food',
      price: 700,
      stock: 18,
      minStock: 10,
      barcode: 'P003',
    ),
  ];
  List<String> _productCategories = ['Food', 'Beverage', 'General'];
  final List<_CustomerItem> _customers = [
    _CustomerItem(
      id: 'C001',
      name: 'Walk-in Customer',
      phone: 'N/A',
      email: '',
    ),
  ];
  final List<_EmployeeItem> _employees = [
    _EmployeeItem(id: 'E001', name: 'Admin Owner', role: 'OWNER', active: true),
  ];
  final List<_UserItem> _users = [
    _UserItem(
      id: 'U001',
      name: 'Owner User',
      email: 'owner@store.local',
      role: 'OWNER',
      active: true,
    ),
  ];
  final List<_SupplierItem> _suppliers = [];
  final List<_CouponItem> _coupons = [];
  final List<_ServiceJobItem> _serviceJobs = [];
  final List<_SaleRecord> _sales = [];
  final List<_HeldCart> _heldCarts = [];
  final List<_InvoiceItem> _invoices = [];
  final List<_PurchaseOrderItem> _purchaseOrders = [];
  final List<_SyncItem> _syncQueue = [];
  final Map<String, List<_CreditPaymentItem>> _customerCreditPayments = {};

  final Map<String, int> _cart = {};
  String? _selectedCustomerId;

  String _companyName = 'Store Buddy Restaurant';
  String _taxRate = '8';
  String _currency = 'LKR';
  String _storeLocation = 'Main Branch';
  String _receiptHeader = 'Store Buddy POS';
  String _receiptFooter = 'Thank you, come again!';
  bool _receiptShowTax = true;
  bool _receiptShowLogo = false;
  String _receiptNote = 'No refunds without invoice';
  String _openFrom = '08:00';
  String _openTo = '22:00';
  bool _acceptCash = true;
  bool _acceptCard = true;
  bool _acceptCheque = false;
  bool _acceptInstallment = false;
  String _integrationMode = 'Cloud Sync';
  String _integrationWebhook = '';
  bool _notifyLowStock = true;
  bool _notifyDailySummary = true;
  bool _notifyReturns = true;
  bool _cashDrawerEnabled = true;
  bool _cashDrawerRequirePin = false;
  String _cashDrawerPin = '';
  String _receiptPaper = '80mm';
  String _receiptMargin = '8';
  String _receiptFontScale = '1.0';
  String _selectedReportType = 'sales';
  String _settingsTab = 'general';
  String _salesFilterStatus = 'ALL';
  String _salesFilterPayment = 'ALL';
  DateTime? _lastSyncAt;
  String? _lastSyncError;

  SyncService? _syncService;
  db.AppDatabase? _appDatabase;
  ProductRepository? _productRepository;
  CustomerRepository? _customerRepository;
  SaleRepository? _saleRepository;
  String? _activeTenantId;
  String _currentUserRole = 'manager';
  bool _coreDataLoaded = false;
  bool _syncInProgress = false;
  bool _syncQueueLoaded = false;

  final TextEditingController _salesSearchController = TextEditingController();
  final TextEditingController _customerSearchController =
      TextEditingController();
  final TextEditingController _productSearchController =
      TextEditingController();
  final TextEditingController _paymentMethodController =
      TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _tenantIdController = TextEditingController();
  final TextEditingController _storeEmailController = TextEditingController();
  final TextEditingController _storePasswordController =
      TextEditingController();

  static const String _workspaceStateKey = 'workspace_state';

  @override
  void initState() {
    super.initState();
    _loadPersistedWorkspaceData();
    _loadStoreLogins();
  }

  @override
  void dispose() {
    _salesSearchController.dispose();
    _customerSearchController.dispose();
    _productSearchController.dispose();
    _paymentMethodController.dispose();
    _storeNameController.dispose();
    _tenantIdController.dispose();
    _storeEmailController.dispose();
    _storePasswordController.dispose();
    super.dispose();
  }

  Future<void> _enqueueSync(
    String action,
    String module,
    String reference,
  ) async {
    await _addToSyncQueue(action: action, module: module, reference: reference);
  }

  Future<void> _addToSyncQueue({
    required String action,
    required String module,
    required String reference,
  }) async {
    _syncQueue.add(
      _SyncItem(
        timestamp: DateTime.now(),
        action: action,
        module: module,
        reference: reference,
      ),
    );

    await _refreshPendingSyncQueue();
    await _persistWorkspaceData();

    await _triggerRealtimeSync(
      action: action,
      module: module,
      reference: reference,
    );
  }

  Future<void> _refreshPendingSyncQueue() async {
    if (_syncService == null) return;

    final pending = await _syncService!.getPendingQueue();
    if (!mounted) return;

    setState(() {
      _syncQueue
        ..clear()
        ..addAll(
          pending
              .map(
                (item) => _SyncItem(
                  timestamp: item.createdAt,
                  action: item.operation,
                  module: item.entityTable,
                  reference: item.recordId,
                ),
              )
              .toList(),
        );
    });
  }

  void _ensureSyncService(String tenantId) {
    if (_syncService != null) return;
    final apiClient = context.read<ApiClient>();
    _syncService = SyncService(apiClient, tenantId);
  }

  void _ensureRepositories(String tenantId) {
    _appDatabase ??= db.AppDatabase(tenantId);
    _activeTenantId = tenantId;
    _productRepository ??= ProductRepository(_appDatabase!, _syncService);
    _customerRepository ??= CustomerRepository(_appDatabase!, _syncService);
    _saleRepository ??= SaleRepository(_appDatabase!, _syncService);

    if (!_coreDataLoaded) {
      _coreDataLoaded = true;
      _loadCoreDataFromRepositories();
    }
  }

  Future<void> _loadCoreDataFromRepositories() async {
    if (_productRepository == null ||
        _customerRepository == null ||
        _saleRepository == null) {
      return;
    }

    final repoProducts = await _productRepository!.getAllProducts();
    final repoCustomers = await _customerRepository!.getAllCustomers();
    final repoSales = await _saleRepository!.getAllSales();

    if (!mounted) return;
    setState(() {
      if (repoProducts.isNotEmpty) {
        _products
          ..clear()
          ..addAll(repoProducts.map(_fromDomainProduct));
      }

      if (repoCustomers.isNotEmpty) {
        _customers
          ..clear()
          ..addAll(repoCustomers.map(_fromDomainCustomer));
        _selectedCustomerId = _customers.first.id;
      }

      if (repoSales.isNotEmpty) {
        _sales
          ..clear()
          ..addAll(repoSales.map(_fromDomainSale));
      }
    });
  }

  domain.Product _toDomainProduct(_ProductItem item) {
    final tenantId = _activeTenantId ?? 'local';
    return domain.Product(
      id: item.id,
      tenantId: tenantId,
      name: item.name,
      sku: null,
      barcode: item.barcode.isEmpty ? null : item.barcode,
      price: item.price,
      costPrice: null,
      category: item.category,
      type: 'PRODUCT',
      unitOfMeasure: 'PIECE',
      stock: item.stock.toDouble(),
      minStock: item.minStock.toDouble(),
      locationId: null,
      synced: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  _ProductItem _fromDomainProduct(domain.Product p) {
    return _ProductItem(
      id: p.id,
      name: p.name,
      category: p.category,
      price: p.price,
      stock: p.stock.toInt(),
      minStock: p.minStock.toInt(),
      barcode: p.barcode ?? p.id,
    );
  }

  domain.Customer _toDomainCustomer(_CustomerItem item) {
    final tenantId = _activeTenantId ?? 'local';
    return domain.Customer(
      id: item.id,
      tenantId: tenantId,
      name: item.name,
      phone: item.phone,
      email: item.email.isEmpty ? null : item.email,
      address: null,
      creditLimit: item.creditLimit,
      currentBalance: item.currentBalance,
      synced: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  _CustomerItem _fromDomainCustomer(domain.Customer c) {
    return _CustomerItem(
      id: c.id,
      name: c.name,
      phone: c.phone,
      email: c.email ?? '',
      creditLimit: c.creditLimit,
      currentBalance: c.currentBalance,
      loyaltyPoints: 0,
    );
  }

  domain.Sale _toDomainSale(_SaleRecord sale, List<_CartLine> lines) {
    final tenantId = _activeTenantId ?? 'local';
    final items = lines
        .map(
          (line) => domain.SaleItem(
            id: '${sale.id}-${line.product.id}',
            saleId: sale.id,
            productId: line.product.id,
            productName: line.product.name,
            quantity: line.qty.toDouble(),
            unitPrice: line.product.price,
            total: line.product.price * line.qty,
            tenantId: tenantId,
          ),
        )
        .toList();

    return domain.Sale(
      id: sale.id,
      tenantId: tenantId,
      customerId: _selectedCustomerId,
      employeeId: 'EMP-LOCAL',
      total: sale.total,
      tax: sale.tax,
      discount: 0,
      paymentMethod: sale.paymentMethod,
      status: sale.status,
      locationId: _storeLocation,
      synced: false,
      createdAt: sale.createdAt,
      updatedAt: DateTime.now(),
      items: items,
    );
  }

  _SaleRecord _fromDomainSale(domain.Sale s) {
    return _SaleRecord(
      id: s.id,
      customerName: s.customer?.name ?? 'Walk-in Customer',
      paymentMethod: s.paymentMethod,
      subtotal: s.total - s.tax,
      tax: s.tax,
      total: s.total,
      status: s.status,
      createdAt: s.createdAt ?? DateTime.now(),
    );
  }

  Future<void> _triggerRealtimeSync({
    required String action,
    required String module,
    required String reference,
  }) async {
    if (_syncService == null || _syncInProgress) return;
    _syncInProgress = true;

    try {
      final synced = await _syncService!.syncAllData();
      if (!synced) {
        if (!mounted) return;
        setState(() {
          _lastSyncError = 'Realtime sync failed. Will retry later.';
        });
        await _refreshPendingSyncQueue();
        await _persistWorkspaceData();
        return;
      }

      await _refreshPendingSyncQueue();
      if (!mounted) return;
      setState(() {
        _lastSyncAt = DateTime.now();
        _lastSyncError = null;
      });
      await _persistWorkspaceData();
    } catch (_) {
      // keep pending items in local queue if sync failed
      if (!mounted) return;
      setState(() {
        _lastSyncError = 'Sync error occurred. Pending items kept locally.';
      });
      await _refreshPendingSyncQueue();
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> _runManualSync() async {
    if (_syncService == null || _syncInProgress) return;

    setState(() => _syncInProgress = true);
    try {
      final synced = await _syncService!.syncAllData();
      if (!mounted) return;

      if (synced) {
        await _refreshPendingSyncQueue();
        setState(() {
          _lastSyncAt = DateTime.now();
          _lastSyncError = null;
        });
        await _persistWorkspaceData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manual sync completed successfully')),
        );
      } else {
        setState(() {
          _lastSyncError =
              'Manual sync could not complete. Check connectivity.';
        });
        await _refreshPendingSyncQueue();
        await _persistWorkspaceData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Manual sync failed (offline/server issue)'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lastSyncError = 'Unexpected sync error during manual sync.';
      });
      await _refreshPendingSyncQueue();
      await _persistWorkspaceData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manual sync failed unexpectedly')),
      );
    } finally {
      if (mounted) {
        setState(() => _syncInProgress = false);
      }
    }
  }

  String _syncStatusLabel() {
    if (_syncInProgress) return 'Syncing...';
    if (_lastSyncError != null) return 'Sync failed';
    if (_lastSyncAt != null) return 'Synced';
    return 'Not synced';
  }

  Color _syncStatusColor() {
    if (_syncInProgress) return const Color(0xFF1463FF);
    if (_lastSyncError != null) return const Color(0xFFE35D5D);
    if (_lastSyncAt != null) return const Color(0xFF0B9F69);
    return const Color(0xFF8A90A2);
  }

  bool get _isOwner => _currentUserRole.toLowerCase() == 'owner';
  bool get _isManager => _currentUserRole.toLowerCase() == 'manager';
  bool get _isCashier => _currentUserRole.toLowerCase() == 'cashier';
  bool get _canManageCatalog => _isOwner || _isManager;
  bool get _canManageEmployees => _isOwner || _isManager;
  bool get _canManageSettings => _isOwner || _isManager;
  bool get _canChangeSalesStatus => _isOwner || _isManager;
  bool get _canRunSync => !_isCashier;

  List<_NavItem> _visibleNavItems() {
    if (_isOwner) return _storeNavItems;

    if (_isManager) {
      return _storeNavItems;
    }

    const cashierAllowed = {
      'dashboard',
      'pos',
      'sales',
      'customers',
      'reports',
      'settings',
    };
    return _storeNavItems
        .where((item) => cashierAllowed.contains(item.key))
        .toList();
  }

  String _money(double amount) => '$_currency ${amount.toStringAsFixed(2)}';

  int _loyaltyPointsForAmount(double amount) => (amount ~/ 100).toInt();

  final List<_SettingsTabItem> _settingsTabs = const [
    _SettingsTabItem(key: 'general', label: 'General', icon: Icons.settings),
    _SettingsTabItem(
      key: 'hours',
      label: 'Opening Hours',
      icon: Icons.schedule,
    ),
    _SettingsTabItem(key: 'payments', label: 'Payments', icon: Icons.payments),
    _SettingsTabItem(key: 'tax', label: 'Taxes & Charges', icon: Icons.percent),
    _SettingsTabItem(
      key: 'receipt',
      label: 'Receipt',
      icon: Icons.receipt_long,
    ),
    _SettingsTabItem(
      key: 'integrations',
      label: 'Integrations',
      icon: Icons.link,
    ),
    _SettingsTabItem(
      key: 'notifications',
      label: 'Notifications',
      icon: Icons.notifications,
    ),
    _SettingsTabItem(
      key: 'cash',
      label: 'Cash Drawer',
      icon: Icons.point_of_sale,
    ),
  ];

  Future<void> _exportReportsCsv() async {
    final buffer = StringBuffer();
    buffer.writeln('metric,value');
    final totalRevenue = _sales.fold<double>(0, (sum, s) => sum + s.total);
    final completed = _sales.where((s) => s.status == 'COMPLETED').length;
    final cancelled = _sales.where((s) => s.status == 'CANCELLED').length;
    final returned = _sales.where((s) => s.status == 'RETURNED').length;
    final lowStock = _products.where((p) => p.stock <= p.minStock).length;
    buffer.writeln('total_revenue,${totalRevenue.toStringAsFixed(2)}');
    buffer.writeln('completed_sales,$completed');
    buffer.writeln('cancelled_sales,$cancelled');
    buffer.writeln('returned_sales,$returned');
    buffer.writeln('customers,${_customers.length}');
    buffer.writeln('low_stock_products,$lowStock');

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report CSV copied to clipboard')),
    );
  }

  Future<void> _exportSalesCsv(List<_SaleRecord> sales) async {
    final buffer = StringBuffer();
    buffer.writeln(
      'sale_id,customer,payment,status,subtotal,tax,total,created_at,return_reason',
    );
    for (final sale in sales) {
      buffer.writeln(
        '${sale.id},${sale.customerName},${sale.paymentMethod},${sale.status},'
        '${sale.subtotal.toStringAsFixed(2)},${sale.tax.toStringAsFixed(2)},${sale.total.toStringAsFixed(2)},'
        '${sale.createdAt.toIso8601String()},${sale.returnReason ?? ''}',
      );
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sales CSV copied (${sales.length} rows)')),
    );
  }

  String _generateBarcodeValue() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'SB${now.toString().substring(now.toString().length - 10)}';
  }

  Future<void> _printProductBarcode(_ProductItem product) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(220, 120),
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  product.name,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text('Barcode: ${product.barcode}'),
                pw.SizedBox(height: 6),
                pw.Text('SKU: ${product.id}'),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  Future<void> _recordCustomerCreditPayment(_CustomerItem customer) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Record Credit Payment • ${customer.name}'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Outstanding Balance: ${_money(customer.currentBalance)}'),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Payment Amount',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text.trim());
              if (amount == null || amount <= 0) return;
              Navigator.pop(context, amount);
            },
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );

    if (result == null || result <= 0) return;
    final paymentAmount = result > customer.currentBalance
        ? customer.currentBalance
        : result;
    if (paymentAmount <= 0) return;

    final payment = _CreditPaymentItem(
      id: 'CP${DateTime.now().millisecondsSinceEpoch}',
      amount: paymentAmount,
      note: noteController.text.trim(),
      createdAt: DateTime.now(),
    );

    setState(() {
      customer.currentBalance = (customer.currentBalance - paymentAmount)
          .clamp(0, double.infinity)
          .toDouble();
      _customerCreditPayments
          .putIfAbsent(customer.id, () => [])
          .insert(0, payment);
    });
    await _persistWorkspaceData();

    if (_customerRepository != null) {
      await _customerRepository!.updateCustomer(_toDomainCustomer(customer));
      await _refreshPendingSyncQueue();
      await _triggerRealtimeSync(
        action: 'UPDATE',
        module: 'customers',
        reference: customer.id,
      );
    } else {
      await _enqueueSync('UPDATE', 'customers', customer.id);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment recorded: ${_money(paymentAmount)}')),
    );
  }

  Future<void> _showCustomerCreditHistory(_CustomerItem customer) async {
    final items = _customerCreditPayments[customer.id] ?? const [];
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Credit Payments • ${customer.name}'),
        content: SizedBox(
          width: 460,
          height: 300,
          child: items.isEmpty
              ? const Center(child: Text('No credit payments recorded yet.'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(_money(item.amount)),
                      subtitle: Text(
                        '${item.createdAt.toLocal()}${item.note.isEmpty ? '' : ' • ${item.note}'}',
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _holdCurrentCart() async {
    if (_cart.isEmpty) return;

    final held = _HeldCart(
      id: 'HC${DateTime.now().millisecondsSinceEpoch}',
      customerId: _selectedCustomerId,
      paymentMethod: _paymentMethodController.text,
      items: Map<String, int>.from(_cart),
      createdAt: DateTime.now(),
    );

    setState(() {
      _heldCarts.insert(0, held);
      _cart.clear();
    });
    await _persistWorkspaceData();
  }

  Future<void> _resumeHeldCart() async {
    if (_heldCarts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No held carts available')));
      return;
    }

    final selected = await showDialog<_HeldCart>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resume Held Cart'),
        content: SizedBox(
          width: 420,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _heldCarts.length,
            itemBuilder: (context, index) {
              final held = _heldCarts[index];
              final itemsCount = held.items.values.fold<int>(
                0,
                (s, q) => s + q,
              );
              return ListTile(
                title: Text('Cart ${held.id}'),
                subtitle: Text(
                  'Items: $itemsCount • ${held.createdAt.toLocal()}',
                ),
                onTap: () => Navigator.pop(context, held),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected == null) return;

    setState(() {
      _cart
        ..clear()
        ..addAll(selected.items);
      _selectedCustomerId = selected.customerId;
      if (selected.paymentMethod != null &&
          selected.paymentMethod!.isNotEmpty) {
        _paymentMethodController.text = selected.paymentMethod!;
      }
      _heldCarts.removeWhere((x) => x.id == selected.id);
    });
    await _persistWorkspaceData();
  }

  Future<String?> _showReturnReasonDialog() async {
    final reasonController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return Reason'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, reasonController.text.trim()),
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );
  }

  Future<void> _manageCategories() async {
    final updated = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        final items = List<String>.from(_productCategories);
        final inputController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const Text('Product Categories'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: inputController,
                          decoration: const InputDecoration(
                            labelText: 'New Category',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final value = inputController.text.trim();
                          if (value.isEmpty) return;
                          if (items.any(
                            (x) => x.toLowerCase() == value.toLowerCase(),
                          ))
                            return;
                          setLocal(() => items.add(value));
                          inputController.clear();
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 240,
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final category = items[index];
                        return ListTile(
                          title: Text(category),
                          trailing: IconButton(
                            onPressed: () {
                              final inUse = _products.any(
                                (p) =>
                                    p.category.toLowerCase() ==
                                    category.toLowerCase(),
                              );
                              if (inUse) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Category is used by products and cannot be removed',
                                    ),
                                  ),
                                );
                                return;
                              }
                              setLocal(() => items.removeAt(index));
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, items),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (updated == null) return;
    setState(() {
      _productCategories = updated.toSet().toList();
      if (_productCategories.isEmpty) {
        _productCategories = ['General'];
      }
    });
    await _persistWorkspaceData();
  }

  Future<int?> _showAdjustStockDialog(_ProductItem product) async {
    final controller = TextEditingController(text: product.stock.toString());
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adjust Stock • ${product.name}'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'New Stock Quantity',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 0) return;
              Navigator.pop(context, value);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSaleDetails(_SaleRecord sale) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sale Details • ${sale.id}'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${sale.customerName}'),
              Text('Date: ${sale.createdAt.toLocal()}'),
              Text('Payment: ${sale.paymentMethod}'),
              Text('Status: ${sale.status}'),
              const SizedBox(height: 10),
              Text('Subtotal: ${_money(sale.subtotal)}'),
              Text('Tax: ${_money(sale.tax)}'),
              Text(
                'Total: ${_money(sale.total)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (sale.returnReason != null &&
                  sale.returnReason!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Return Reason: ${sale.returnReason}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _persistWorkspaceData() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'products': _products.map((e) => e.toJson()).toList(),
      'productCategories': _productCategories,
      'customers': _customers.map((e) => e.toJson()).toList(),
      'employees': _employees.map((e) => e.toJson()).toList(),
      'users': _users.map((e) => e.toJson()).toList(),
      'suppliers': _suppliers.map((e) => e.toJson()).toList(),
      'coupons': _coupons.map((e) => e.toJson()).toList(),
      'serviceJobs': _serviceJobs.map((e) => e.toJson()).toList(),
      'sales': _sales.map((e) => e.toJson()).toList(),
      'heldCarts': _heldCarts.map((e) => e.toJson()).toList(),
      'invoices': _invoices.map((e) => e.toJson()).toList(),
      'purchaseOrders': _purchaseOrders.map((e) => e.toJson()).toList(),
      'syncQueue': _syncQueue.map((e) => e.toJson()).toList(),
      'customerCreditPayments': _customerCreditPayments.map(
        (key, value) =>
            MapEntry(key, value.map((item) => item.toJson()).toList()),
      ),
      'settings': {
        'companyName': _companyName,
        'taxRate': _taxRate,
        'currency': _currency,
        'storeLocation': _storeLocation,
        'receiptHeader': _receiptHeader,
        'receiptFooter': _receiptFooter,
        'receiptShowTax': _receiptShowTax,
        'receiptShowLogo': _receiptShowLogo,
        'receiptNote': _receiptNote,
        'openFrom': _openFrom,
        'openTo': _openTo,
        'acceptCash': _acceptCash,
        'acceptCard': _acceptCard,
        'acceptCheque': _acceptCheque,
        'acceptInstallment': _acceptInstallment,
        'integrationMode': _integrationMode,
        'integrationWebhook': _integrationWebhook,
        'notifyLowStock': _notifyLowStock,
        'notifyDailySummary': _notifyDailySummary,
        'notifyReturns': _notifyReturns,
        'cashDrawerEnabled': _cashDrawerEnabled,
        'cashDrawerRequirePin': _cashDrawerRequirePin,
        'cashDrawerPin': _cashDrawerPin,
        'receiptPaper': _receiptPaper,
        'receiptMargin': _receiptMargin,
        'receiptFontScale': _receiptFontScale,
        'lastSyncAt': _lastSyncAt?.toIso8601String(),
      },
    };

    await prefs.setString(_workspaceStateKey, jsonEncode(payload));
  }

  Future<void> _loadPersistedWorkspaceData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_workspaceStateKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      final productList = (decoded['products'] as List<dynamic>? ?? [])
          .map((e) => _ProductItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final categoryList =
          (decoded['productCategories'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList();
      final customerList = (decoded['customers'] as List<dynamic>? ?? [])
          .map((e) => _CustomerItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final employeeList = (decoded['employees'] as List<dynamic>? ?? [])
          .map((e) => _EmployeeItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final userList = (decoded['users'] as List<dynamic>? ?? [])
          .map((e) => _UserItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final supplierList = (decoded['suppliers'] as List<dynamic>? ?? [])
          .map((e) => _SupplierItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final couponList = (decoded['coupons'] as List<dynamic>? ?? [])
          .map((e) => _CouponItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final serviceList = (decoded['serviceJobs'] as List<dynamic>? ?? [])
          .map((e) => _ServiceJobItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final salesList = (decoded['sales'] as List<dynamic>? ?? [])
          .map((e) => _SaleRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final heldCartList = (decoded['heldCarts'] as List<dynamic>? ?? [])
          .map((e) => _HeldCart.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final invoiceList = (decoded['invoices'] as List<dynamic>? ?? [])
          .map((e) => _InvoiceItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final poList = (decoded['purchaseOrders'] as List<dynamic>? ?? [])
          .map((e) => _PurchaseOrderItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final syncList = (decoded['syncQueue'] as List<dynamic>? ?? [])
          .map((e) => _SyncItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final creditPaymentsMap =
          (decoded['customerCreditPayments'] as Map<String, dynamic>? ?? {})
              .map(
                (key, value) => MapEntry(
                  key,
                  (value as List<dynamic>)
                      .map(
                        (e) => _CreditPaymentItem.fromJson(
                          Map<String, dynamic>.from(e),
                        ),
                      )
                      .toList(),
                ),
              );

      final settings = Map<String, dynamic>.from(decoded['settings'] ?? {});

      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addAll(productList);
        _productCategories = categoryList.isEmpty
            ? (_products.map((p) => p.category).toSet().toList()
                ..add('General'))
            : categoryList.toSet().toList();
        _customers
          ..clear()
          ..addAll(
            customerList.isEmpty
                ? [
                    _CustomerItem(
                      id: 'C001',
                      name: 'Walk-in Customer',
                      phone: 'N/A',
                      email: '',
                    ),
                  ]
                : customerList,
          );
        _employees
          ..clear()
          ..addAll(
            employeeList.isEmpty
                ? [
                    _EmployeeItem(
                      id: 'E001',
                      name: 'Admin Owner',
                      role: 'OWNER',
                      active: true,
                    ),
                  ]
                : employeeList,
          );
        _users
          ..clear()
          ..addAll(
            userList.isEmpty
                ? [
                    _UserItem(
                      id: 'U001',
                      name: 'Owner User',
                      email: 'owner@store.local',
                      role: 'OWNER',
                      active: true,
                    ),
                  ]
                : userList,
          );
        _suppliers
          ..clear()
          ..addAll(supplierList);
        _coupons
          ..clear()
          ..addAll(couponList);
        _serviceJobs
          ..clear()
          ..addAll(serviceList);
        _sales
          ..clear()
          ..addAll(salesList);
        _heldCarts
          ..clear()
          ..addAll(heldCartList);
        _invoices
          ..clear()
          ..addAll(invoiceList);
        _purchaseOrders
          ..clear()
          ..addAll(poList);
        _syncQueue
          ..clear()
          ..addAll(syncList);
        _customerCreditPayments
          ..clear()
          ..addAll(creditPaymentsMap);

        _companyName = settings['companyName'] ?? _companyName;
        _taxRate = settings['taxRate'] ?? _taxRate;
        _currency = settings['currency'] ?? _currency;
        _storeLocation = settings['storeLocation'] ?? _storeLocation;
        _receiptHeader = settings['receiptHeader'] ?? _receiptHeader;
        _receiptFooter = settings['receiptFooter'] ?? _receiptFooter;
        _receiptShowTax = settings['receiptShowTax'] ?? _receiptShowTax;
        _receiptShowLogo = settings['receiptShowLogo'] ?? _receiptShowLogo;
        _receiptNote = settings['receiptNote'] ?? _receiptNote;
        _openFrom = settings['openFrom'] ?? _openFrom;
        _openTo = settings['openTo'] ?? _openTo;
        _acceptCash = settings['acceptCash'] ?? _acceptCash;
        _acceptCard = settings['acceptCard'] ?? _acceptCard;
        _acceptCheque = settings['acceptCheque'] ?? _acceptCheque;
        _acceptInstallment =
            settings['acceptInstallment'] ?? _acceptInstallment;
        _integrationMode = settings['integrationMode'] ?? _integrationMode;
        _integrationWebhook =
            settings['integrationWebhook'] ?? _integrationWebhook;
        _notifyLowStock = settings['notifyLowStock'] ?? _notifyLowStock;
        _notifyDailySummary =
            settings['notifyDailySummary'] ?? _notifyDailySummary;
        _notifyReturns = settings['notifyReturns'] ?? _notifyReturns;
        _cashDrawerEnabled =
            settings['cashDrawerEnabled'] ?? _cashDrawerEnabled;
        _cashDrawerRequirePin =
            settings['cashDrawerRequirePin'] ?? _cashDrawerRequirePin;
        _cashDrawerPin = settings['cashDrawerPin'] ?? _cashDrawerPin;
        _receiptPaper = settings['receiptPaper'] ?? _receiptPaper;
        _receiptMargin = settings['receiptMargin'] ?? _receiptMargin;
        _receiptFontScale = settings['receiptFontScale'] ?? _receiptFontScale;
        _lastSyncAt = settings['lastSyncAt'] != null
            ? DateTime.tryParse(settings['lastSyncAt'])
            : null;
        if (!_settingsTabs.any((tab) => tab.key == _settingsTab)) {
          _settingsTab = 'general';
        }
        _selectedCustomerId = _customers.first.id;
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _printReceipt({
    required _SaleRecord sale,
    required List<_CartLine> lines,
  }) async {
    final marginValue = (double.tryParse(_receiptMargin) ?? 8)
        .clamp(2, 30)
        .toDouble();
    final fontScale = (double.tryParse(_receiptFontScale) ?? 1.0)
        .clamp(0.7, 1.8)
        .toDouble();
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: _receiptPageFormat(),
        margin: pw.EdgeInsets.all(marginValue),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _receiptHeader,
                style: pw.TextStyle(
                  fontSize: 18 * fontScale,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Invoice: ${sale.id}',
                style: pw.TextStyle(fontSize: 11 * fontScale),
              ),
              pw.Text(
                'Date: ${sale.createdAt.toLocal()}',
                style: pw.TextStyle(fontSize: 11 * fontScale),
              ),
              pw.Text(
                'Customer: ${sale.customerName}',
                style: pw.TextStyle(fontSize: 11 * fontScale),
              ),
              pw.SizedBox(height: 12),
              ...lines.map(
                (line) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '${line.product.name} x${line.qty}',
                        style: pw.TextStyle(fontSize: 11 * fontScale),
                      ),
                    ),
                    pw.Text(
                      '$_currency ${(line.product.price * line.qty).toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 11 * fontScale),
                    ),
                  ],
                ),
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Subtotal',
                    style: pw.TextStyle(fontSize: 11 * fontScale),
                  ),
                  pw.Text(
                    '$_currency ${sale.subtotal.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 11 * fontScale),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Tax', style: pw.TextStyle(fontSize: 11 * fontScale)),
                  pw.Text(
                    '$_currency ${sale.tax.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 11 * fontScale),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12 * fontScale,
                    ),
                  ),
                  pw.Text(
                    '$_currency ${sale.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12 * fontScale,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                _receiptNote,
                style: pw.TextStyle(fontSize: 11 * fontScale),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                _receiptFooter,
                style: pw.TextStyle(fontSize: 11 * fontScale),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  PdfPageFormat _receiptPageFormat() {
    switch (_receiptPaper) {
      case '58mm':
        return PdfPageFormat(58 * PdfPageFormat.mm, 240 * PdfPageFormat.mm);
      case 'A4':
        return PdfPageFormat.a4;
      case '80mm':
      default:
        return PdfPageFormat(80 * PdfPageFormat.mm, 300 * PdfPageFormat.mm);
    }
  }

  Future<void> _printDemoReceipt() async {
    final demoSale = _SaleRecord(
      id: 'DEMO-RECEIPT',
      customerName: 'Walk-in Customer',
      paymentMethod: 'CASH',
      subtotal: 2000,
      tax: _receiptShowTax
          ? 2000 * ((double.tryParse(_taxRate) ?? 0) / 100)
          : 0,
      total: _receiptShowTax ? 2200 : 2000,
      status: 'COMPLETED',
      createdAt: DateTime.now(),
    );

    final demoLines = [
      _CartLine(
        product: _ProductItem(
          id: 'D1',
          name: 'Demo Item A',
          category: 'Demo',
          price: 1200,
          stock: 0,
          minStock: 0,
        ),
        qty: 1,
      ),
      _CartLine(
        product: _ProductItem(
          id: 'D2',
          name: 'Demo Item B',
          category: 'Demo',
          price: 800,
          stock: 0,
          minStock: 0,
        ),
        qty: 1,
      ),
    ];

    await _printReceipt(sale: demoSale, lines: demoLines);
  }

  Future<void> _loadStoreLogins() async {
    final authService = context.read<AuthService>();
    final logins = await authService.getStoreLogins();
    if (!mounted) return;
    setState(() => _storeLogins = logins);
  }

  Future<void> _createStoreLogin() async {
    final storeName = _storeNameController.text.trim();
    final tenantId = _tenantIdController.text.trim();
    final email = _storeEmailController.text.trim();
    final password = _storePasswordController.text.trim();

    if (storeName.isEmpty ||
        tenantId.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all store login fields')),
      );
      return;
    }

    setState(() => _isCreatingStore = true);
    final authService = context.read<AuthService>();
    final created = await authService.createStoreLogin(
      storeName: storeName,
      tenantId: tenantId,
      email: email,
      password: password,
    );
    if (!mounted) return;

    setState(() => _isCreatingStore = false);

    if (!created) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email already exists for another store login'),
        ),
      );
      return;
    }

    _storeNameController.clear();
    _tenantIdController.clear();
    _storeEmailController.clear();
    _storePasswordController.clear();
    await _loadStoreLogins();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Store login created successfully')),
    );
  }

  Widget _buildPlatformAdminPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform Admin',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('Create and manage store owner logins from this panel.'),
            const SizedBox(height: 24),
            TextField(
              controller: _storeNameController,
              decoration: const InputDecoration(
                labelText: 'Store Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tenantIdController,
              decoration: const InputDecoration(
                labelText: 'Tenant ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _storeEmailController,
              decoration: const InputDecoration(
                labelText: 'Store Login Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _storePasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Store Login Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 240,
              child: ElevatedButton(
                onPressed: _isCreatingStore ? null : _createStoreLogin,
                child: _isCreatingStore
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Store Login'),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Created Store Logins',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_storeLogins.isEmpty)
              const Text('No store logins created yet.')
            else
              ..._storeLogins.map((entry) {
                final storeName = entry['storeName'] ?? '';
                final tenantId = entry['tenantId'] ?? '';
                final email = entry['email'] ?? '';
                final trialEndsAt = entry['trialEndsAt'] ?? '-';
                return Card(
                  child: ListTile(
                    title: Text(storeName),
                    subtitle: Text(
                      'Tenant: $tenantId | Email: $email | Trial ends: $trialEndsAt',
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreShell(AuthAuthenticated state) {
    _currentUserRole = state.user.role;
    final visibleNavItems = _visibleNavItems();
    if (!visibleNavItems.any((item) => item.key == _selectedNavKey)) {
      _selectedNavKey = visibleNavItems.first.key;
    }
    _ensureSyncService(state.user.tenantId);
    _ensureRepositories(state.user.tenantId);
    if (!_syncQueueLoaded) {
      _syncQueueLoaded = true;
      _refreshPendingSyncQueue();
    }
    return Row(
      children: [
        _buildSidebar(state),
        Expanded(
          child: Column(
            children: [
              _buildTopBar(state),
              Expanded(
                child: Container(
                  color: const Color(0xFFF4F5FA),
                  child: _buildStorePageContent(state),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(AuthAuthenticated state) {
    final visibleNavItems = _visibleNavItems();
    return Container(
      width: 240,
      color: const Color(0xFF1F1B54),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B35D5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        state.user.tenantId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFBFC3E8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.builder(
              itemCount: visibleNavItems.length,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (context, index) {
                final item = visibleNavItems[index];
                final selected = item.key == _selectedNavKey;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: selected
                        ? const Color(0xFF5B35D5)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _selectedNavKey = item.key),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              size: 20,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFFBFC3E8),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFFBFC3E8),
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2E2A66)),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () =>
                    context.read<AuthBloc>().add(AuthLogoutRequested()),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 20,
                        color: Color(0xFFFF7C7C),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Logout',
                        style: TextStyle(
                          color: Color(0xFFFF7C7C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(AuthAuthenticated state) {
    return Container(
      height: 72,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            _selectedPageTitle(),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _syncStatusColor().withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sync, size: 14, color: _syncStatusColor()),
                const SizedBox(width: 6),
                Text(
                  _syncStatusLabel(),
                  style: TextStyle(
                    color: _syncStatusColor(),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF5B35D5),
            child: Text(
              state.user.name.isNotEmpty
                  ? state.user.name[0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.user.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                state.user.role.toUpperCase(),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _selectedPageTitle() {
    final fallback = _storeNavItems.first;
    return _storeNavItems
        .firstWhere(
          (item) => item.key == _selectedNavKey,
          orElse: () => fallback,
        )
        .label;
  }

  Widget _buildStorePageContent(AuthAuthenticated state) {
    switch (_selectedNavKey) {
      case 'dashboard':
        return _dashboardPage();
      case 'pos':
        return _buildPosPage();
      case 'products':
        return _buildProductsPage();
      case 'sales':
        return _buildSalesPage();
      case 'customers':
        return _buildCustomersPage();
      case 'inventory':
        return _buildInventoryPage();
      case 'employees':
        return _buildEmployeesPage();
      case 'users':
        return _buildUsersPage();
      case 'reports':
        return _buildReportsPage();
      case 'settings':
        return _buildSettingsPage();
      case 'marketing':
        return _buildMarketingPage();
      case 'services':
        return _buildServicesPage();
      case 'suppliers':
        return _buildSuppliersPage();
      case 'invoices':
        return _buildInvoicesPage();
      case 'sync':
        return _buildSyncPage();
      default:
        return const Center(child: Text('Unknown module'));
    }
  }

  Widget _dashboardPage() {
    final totalRevenue = _sales.fold<double>(0, (sum, s) => sum + s.total);
    final avgOrder = _sales.isEmpty ? 0.0 : totalRevenue / _sales.length;
    final lowStock = _products.where((p) => p.stock <= p.minStock).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your restaurant performance at a glance',
            style: TextStyle(color: Color(0xFF6D7383), fontSize: 16),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _MetricCard(
                title: 'Total Revenue',
                value: _money(totalRevenue),
                icon: Icons.payments_rounded,
              ),
              _MetricCard(
                title: 'Total Orders',
                value: '${_sales.length}',
                icon: Icons.shopping_cart_rounded,
              ),
              _MetricCard(
                title: 'Customers',
                value: '${_customers.length}',
                icon: Icons.group_rounded,
              ),
              _MetricCard(
                title: 'Average Order',
                value: _money(avgOrder),
                icon: Icons.trending_up_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Card(
                  child: SizedBox(
                    height: 320,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sales Overview',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Total transactions: ${_sales.length}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: _sales.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No revenue data for this period',
                                      style: TextStyle(
                                        color: Color(0xFF8A90A2),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _sales.length,
                                    itemBuilder: (context, index) {
                                      final sale = _sales[index];
                                      return ListTile(
                                        dense: true,
                                        title: Text(sale.id),
                                        subtitle: Text(
                                          '${sale.paymentMethod} • ${sale.createdAt.toLocal()}',
                                        ),
                                        trailing: Text(_money(sale.total)),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Card(
                  child: SizedBox(
                    height: 320,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Operational Highlights',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ListTile(
                            title: const Text('Low Stock Items'),
                            trailing: Text('$lowStock'),
                          ),
                          ListTile(
                            title: const Text('Active Employees'),
                            trailing: Text(
                              '${_employees.where((e) => e.active).length}',
                            ),
                          ),
                          ListTile(
                            title: const Text('Pending Sync Items'),
                            trailing: Text('${_syncQueue.length}'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPosPage() {
    final filteredProducts = _products.where((p) {
      final q = _productSearchController.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q);
    }).toList();

    final cartItems = _cart.entries
        .map(
          (e) => _CartLine(
            product: _products.firstWhere((p) => p.id == e.key),
            qty: e.value,
          ),
        )
        .toList();
    final subtotal = cartItems.fold<double>(
      0,
      (s, c) => s + (c.product.price * c.qty),
    );
    final taxRate = double.tryParse(_taxRate) ?? 0;
    final taxAmount = _receiptShowTax ? subtotal * (taxRate / 100) : 0.0;
    final grandTotal = subtotal + taxAmount;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Products',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _productSearchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search product by name/category/id',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.6,
                            ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final p = filteredProducts[index];
                          return InkWell(
                            onTap: p.stock <= 0
                                ? null
                                : () {
                                    setState(() {
                                      _cart[p.id] = (_cart[p.id] ?? 0) + 1;
                                    });
                                  },
                            child: Card(
                              color: p.stock <= 0
                                  ? Colors.grey.shade200
                                  : Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(p.category),
                                    const Spacer(),
                                    Text(_money(p.price)),
                                    Text(
                                      'Stock ${p.stock}',
                                      style: TextStyle(
                                        color: p.stock <= p.minStock
                                            ? Colors.red
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cart',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String?>(_selectedCustomerId),
                      initialValue: _selectedCustomerId,
                      items: _customers
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCustomerId = v),
                      decoration: const InputDecoration(
                        labelText: 'Customer',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethodController.text.isEmpty
                          ? null
                          : _paymentMethodController.text,
                      items: const [
                        DropdownMenuItem(value: 'CASH', child: Text('CASH')),
                        DropdownMenuItem(value: 'CARD', child: Text('CARD')),
                        DropdownMenuItem(
                          value: 'CHEQUE',
                          child: Text('CHEQUE'),
                        ),
                        DropdownMenuItem(
                          value: 'INSTALLMENT',
                          child: Text('INSTALLMENT'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) _paymentMethodController.text = v;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: cartItems.isEmpty
                          ? const Center(child: Text('Cart is empty'))
                          : ListView.builder(
                              itemCount: cartItems.length,
                              itemBuilder: (context, index) {
                                final line = cartItems[index];
                                return ListTile(
                                  title: Text(line.product.name),
                                  subtitle: Text(_money(line.product.price)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          setState(() {
                                            final next = (line.qty - 1);
                                            if (next <= 0) {
                                              _cart.remove(line.product.id);
                                            } else {
                                              _cart[line.product.id] = next;
                                            }
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                      ),
                                      Text('${line.qty}'),
                                      IconButton(
                                        onPressed: () {
                                          setState(() {
                                            if (line.qty < line.product.stock) {
                                              _cart[line.product.id] =
                                                  line.qty + 1;
                                            }
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const Divider(),
                    Text(
                      'Subtotal: ${_money(subtotal)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: cartItems.isEmpty
                                ? null
                                : _holdCurrentCart,
                            icon: const Icon(Icons.pause_circle_outline),
                            label: const Text('Hold Cart'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _heldCarts.isEmpty
                                ? null
                                : _resumeHeldCart,
                            icon: const Icon(Icons.play_circle_outline),
                            label: Text('Resume (${_heldCarts.length})'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: cartItems.isEmpty
                            ? null
                            : () async {
                                final sale = _SaleRecord(
                                  id: 'S${DateTime.now().millisecondsSinceEpoch}',
                                  customerName: _customers
                                      .firstWhere(
                                        (c) => c.id == _selectedCustomerId,
                                        orElse: () => _customers.first,
                                      )
                                      .name,
                                  paymentMethod: _paymentMethodController.text,
                                  subtotal: subtotal,
                                  tax: taxAmount,
                                  total: grandTotal,
                                  status: 'COMPLETED',
                                  createdAt: DateTime.now(),
                                );
                                setState(() {
                                  final selectedCustomer = _customers
                                      .firstWhere(
                                        (c) => c.id == _selectedCustomerId,
                                        orElse: () => _customers.first,
                                      );
                                  selectedCustomer.loyaltyPoints +=
                                      _loyaltyPointsForAmount(grandTotal);
                                  if (_paymentMethodController.text ==
                                      'INSTALLMENT') {
                                    selectedCustomer.currentBalance +=
                                        grandTotal;
                                  }

                                  _sales.insert(0, sale);
                                  for (final line in cartItems) {
                                    line.product.stock -= line.qty;
                                  }
                                  _cart.clear();
                                });
                                await _persistWorkspaceData();

                                if (_saleRepository != null) {
                                  await _saleRepository!.insertSale(
                                    _toDomainSale(sale, cartItems),
                                  );
                                  await _refreshPendingSyncQueue();
                                  await _triggerRealtimeSync(
                                    action: 'INSERT',
                                    module: 'sales',
                                    reference: sale.id,
                                  );
                                } else {
                                  await _enqueueSync(
                                    'INSERT',
                                    'sales',
                                    sale.id,
                                  );
                                }

                                _printReceipt(sale: sale, lines: cartItems);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Sale completed: ${sale.id}'),
                                  ),
                                );
                              },
                        child: const Text('Checkout'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsPage() {
    final q = _productSearchController.text.trim().toLowerCase();
    final filtered = _products.where((p) {
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q) ||
          p.barcode.toLowerCase().contains(q);
    }).toList();

    return _moduleCard(
      title: 'Product Management',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: _canManageCatalog ? _manageCategories : null,
            icon: const Icon(Icons.category_outlined),
            label: const Text('Categories'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _canManageCatalog
                ? () async {
                    final item = await _showProductDialog();
                    if (item == null) return;
                    setState(() {
                      _products.add(item);
                      if (!_productCategories.any(
                        (c) => c.toLowerCase() == item.category.toLowerCase(),
                      )) {
                        _productCategories.add(item.category);
                      }
                    });
                    await _persistWorkspaceData();

                    if (_productRepository != null) {
                      await _productRepository!.insertProduct(
                        _toDomainProduct(item),
                      );
                      await _refreshPendingSyncQueue();
                      await _triggerRealtimeSync(
                        action: 'INSERT',
                        module: 'products',
                        reference: item.id,
                      );
                    } else {
                      await _enqueueSync('INSERT', 'products', item.id);
                    }
                  }
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _productSearchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search products',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 460,
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = filtered[index];
                return ListTile(
                  title: Text('${p.name} (${p.id})'),
                  subtitle: Text(
                    '${p.category} • Barcode ${p.barcode} • Stock ${p.stock} • Min ${p.minStock}',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        onPressed: () => _printProductBarcode(p),
                        icon: const Icon(Icons.qr_code_2_outlined),
                        tooltip: 'Print Barcode Label',
                      ),
                      IconButton(
                        onPressed: _canManageCatalog
                            ? () async {
                                final nextStock = await _showAdjustStockDialog(
                                  p,
                                );
                                if (nextStock == null) return;
                                setState(() {
                                  p.stock = nextStock;
                                });
                                await _persistWorkspaceData();

                                if (_productRepository != null) {
                                  await _productRepository!.updateProduct(
                                    _toDomainProduct(p),
                                  );
                                  await _refreshPendingSyncQueue();
                                  await _triggerRealtimeSync(
                                    action: 'UPDATE',
                                    module: 'products',
                                    reference: p.id,
                                  );
                                } else {
                                  await _enqueueSync(
                                    'UPDATE',
                                    'products',
                                    p.id,
                                  );
                                }
                              }
                            : null,
                        icon: const Icon(Icons.inventory_2_outlined),
                      ),
                      IconButton(
                        onPressed: _canManageCatalog
                            ? () async {
                                final edited = await _showProductDialog(
                                  existing: p,
                                );
                                if (edited == null) return;
                                setState(() {
                                  final i = _products.indexWhere(
                                    (x) => x.id == p.id,
                                  );
                                  _products[i] = edited;
                                  if (!_productCategories.any(
                                    (c) =>
                                        c.toLowerCase() ==
                                        edited.category.toLowerCase(),
                                  )) {
                                    _productCategories.add(edited.category);
                                  }
                                });
                                await _persistWorkspaceData();

                                if (_productRepository != null) {
                                  await _productRepository!.updateProduct(
                                    _toDomainProduct(edited),
                                  );
                                  await _refreshPendingSyncQueue();
                                  await _triggerRealtimeSync(
                                    action: 'UPDATE',
                                    module: 'products',
                                    reference: edited.id,
                                  );
                                } else {
                                  await _enqueueSync(
                                    'UPDATE',
                                    'products',
                                    edited.id,
                                  );
                                }
                              }
                            : null,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: _canManageCatalog
                            ? () async {
                                setState(() {
                                  _products.removeWhere((x) => x.id == p.id);
                                });
                                await _persistWorkspaceData();

                                if (_productRepository != null) {
                                  await _productRepository!.deleteProduct(p.id);
                                  await _refreshPendingSyncQueue();
                                  await _triggerRealtimeSync(
                                    action: 'DELETE',
                                    module: 'products',
                                    reference: p.id,
                                  );
                                } else {
                                  await _enqueueSync(
                                    'DELETE',
                                    'products',
                                    p.id,
                                  );
                                }
                              }
                            : null,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesPage() {
    final query = _salesSearchController.text.trim().toLowerCase();
    final filtered = _sales.where((s) {
      if (query.isNotEmpty) {
        if (!s.id.toLowerCase().contains(query) &&
            !s.customerName.toLowerCase().contains(query) &&
            !s.paymentMethod.toLowerCase().contains(query)) {
          return false;
        }
      }
      if (_salesFilterStatus != 'ALL' && s.status != _salesFilterStatus) {
        return false;
      }
      if (_salesFilterPayment != 'ALL' &&
          s.paymentMethod != _salesFilterPayment) {
        return false;
      }
      return true;
    }).toList();

    return _moduleCard(
      title: 'Sales Processing',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: () => _exportSalesCsv(filtered),
            icon: const Icon(Icons.download),
            label: const Text('Export CSV'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _salesSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search sales by ID/customer/payment',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _salesFilterStatus,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Status')),
                  DropdownMenuItem(
                    value: 'COMPLETED',
                    child: Text('Completed'),
                  ),
                  DropdownMenuItem(value: 'RETURNED', child: Text('Returned')),
                  DropdownMenuItem(
                    value: 'CANCELLED',
                    child: Text('Cancelled'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _salesFilterStatus = v ?? 'ALL'),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _salesFilterPayment,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Payments')),
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(value: 'CARD', child: Text('Card')),
                  DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                  DropdownMenuItem(
                    value: 'INSTALLMENT',
                    child: Text('Installment'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _salesFilterPayment = v ?? 'ALL'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 400,
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No sales match the current filters.'),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final sale = filtered[index];
                      return Card(
                        child: ListTile(
                          onTap: () => _showSaleDetails(sale),
                          title: Text('${sale.id} • ${_money(sale.total)}'),
                          subtitle: Text(
                            '${sale.customerName} • ${sale.paymentMethod} • ${sale.createdAt.toLocal()}${sale.returnReason != null ? ' • Reason: ${sale.returnReason}' : ''}',
                          ),
                          trailing: DropdownButton<String>(
                            value: sale.status,
                            items: const [
                              DropdownMenuItem(
                                value: 'COMPLETED',
                                child: Text('COMPLETED'),
                              ),
                              DropdownMenuItem(
                                value: 'RETURNED',
                                child: Text('RETURNED'),
                              ),
                              DropdownMenuItem(
                                value: 'CANCELLED',
                                child: Text('CANCELLED'),
                              ),
                            ],
                            onChanged: _canChangeSalesStatus
                                ? (v) async {
                                    if (v == null) return;
                                    if (sale.status == v) return;

                                    String? reason;
                                    if (v == 'RETURNED') {
                                      reason = await _showReturnReasonDialog();
                                      if (reason == null || reason.isEmpty)
                                        return;
                                    }

                                    setState(() {
                                      sale.status = v;
                                      sale.returnReason = v == 'RETURNED'
                                          ? reason
                                          : null;
                                    });
                                    await _persistWorkspaceData();

                                    if (_saleRepository != null) {
                                      await _saleRepository!.updateSaleStatus(
                                        saleId: sale.id,
                                        status: sale.status,
                                      );
                                      await _refreshPendingSyncQueue();
                                      await _triggerRealtimeSync(
                                        action: 'UPDATE',
                                        module: 'sales',
                                        reference: sale.id,
                                      );
                                    } else {
                                      await _enqueueSync(
                                        'UPDATE',
                                        'sales',
                                        sale.id,
                                      );
                                    }
                                  }
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersPage() {
    final query = _customerSearchController.text.trim().toLowerCase();
    final filtered = _customers.where((c) {
      if (query.isEmpty) return true;
      return c.name.toLowerCase().contains(query) ||
          c.phone.toLowerCase().contains(query) ||
          c.email.toLowerCase().contains(query);
    }).toList();

    return _moduleCard(
      title: 'Customer Management',
      action: ElevatedButton.icon(
        onPressed: _canManageCatalog
            ? () async {
                final customer = await _showCustomerDialog();
                if (customer == null) return;
                setState(() {
                  _customers.add(customer);
                });
                await _persistWorkspaceData();

                if (_customerRepository != null) {
                  await _customerRepository!.insertCustomer(
                    _toDomainCustomer(customer),
                  );
                  await _refreshPendingSyncQueue();
                  await _triggerRealtimeSync(
                    action: 'INSERT',
                    module: 'customers',
                    reference: customer.id,
                  );
                } else {
                  await _enqueueSync('INSERT', 'customers', customer.id);
                }
              }
            : null,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Customer'),
      ),
      child: Column(
        children: [
          TextField(
            controller: _customerSearchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search customer by name/phone/email',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 460,
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final c = filtered[index];
                return Card(
                  child: ListTile(
                    title: Text(c.name),
                    subtitle: Text(
                      '${c.phone} • ${c.email.isEmpty ? 'No email' : c.email}\n'
                      'Credit: ${_money(c.currentBalance)} / ${_money(c.creditLimit)} • '
                      'Points: ${c.loyaltyPoints}',
                    ),
                    isThreeLine: true,
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          onPressed: _canManageCatalog
                              ? () async {
                                  final edited = await _showCustomerDialog(
                                    existing: c,
                                  );
                                  if (edited == null) return;
                                  setState(() {
                                    final i = _customers.indexWhere(
                                      (x) => x.id == c.id,
                                    );
                                    _customers[i] = edited;
                                    if (edited.id != c.id) {
                                      final history = _customerCreditPayments
                                          .remove(c.id);
                                      if (history != null) {
                                        _customerCreditPayments[edited.id] =
                                            history;
                                      }
                                    }
                                  });
                                  await _persistWorkspaceData();

                                  if (_customerRepository != null) {
                                    await _customerRepository!.updateCustomer(
                                      _toDomainCustomer(edited),
                                    );
                                    await _refreshPendingSyncQueue();
                                    await _triggerRealtimeSync(
                                      action: 'UPDATE',
                                      module: 'customers',
                                      reference: edited.id,
                                    );
                                  } else {
                                    await _enqueueSync(
                                      'UPDATE',
                                      'customers',
                                      edited.id,
                                    );
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: _canManageCatalog
                              ? () async {
                                  setState(() {
                                    _customers.removeWhere((x) => x.id == c.id);
                                    _customerCreditPayments.remove(c.id);
                                  });
                                  await _persistWorkspaceData();

                                  if (_customerRepository != null) {
                                    await _customerRepository!.deleteCustomer(
                                      c.id,
                                    );
                                    await _refreshPendingSyncQueue();
                                    await _triggerRealtimeSync(
                                      action: 'DELETE',
                                      module: 'customers',
                                      reference: c.id,
                                    );
                                  } else {
                                    await _enqueueSync(
                                      'DELETE',
                                      'customers',
                                      c.id,
                                    );
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.delete_outline),
                        ),
                        IconButton(
                          onPressed: () => _recordCustomerCreditPayment(c),
                          icon: const Icon(Icons.payments_outlined),
                          tooltip: 'Record Credit Payment',
                        ),
                        IconButton(
                          onPressed: () => _showCustomerCreditHistory(c),
                          icon: const Icon(Icons.history),
                          tooltip: 'Credit History',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryPage() {
    return _moduleCard(
      title: 'Inventory Management',
      action: ElevatedButton.icon(
        onPressed: _canManageCatalog
            ? () async {
                final po = await _showPurchaseOrderDialog();
                if (po == null) return;
                setState(() {
                  _purchaseOrders.insert(0, po);
                  _enqueueSync('INSERT', 'purchase_orders', po.id);
                });
              }
            : null,
        icon: const Icon(Icons.add_business),
        label: const Text('New Purchase Order'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stock Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 300,
            child: ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final p = _products[index];
                return Card(
                  child: ListTile(
                    title: Text(p.name),
                    subtitle: Text(
                      'Current stock ${p.stock} • Minimum ${p.minStock}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _canManageCatalog
                              ? () {
                                  setState(() {
                                    p.stock = (p.stock - 1)
                                        .clamp(0, 1000000)
                                        .toInt();
                                    _enqueueSync('UPDATE', 'inventory', p.id);
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        IconButton(
                          onPressed: _canManageCatalog
                              ? () {
                                  setState(() {
                                    p.stock += 1;
                                    _enqueueSync('UPDATE', 'inventory', p.id);
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Recent Purchase Orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: _purchaseOrders.isEmpty
                ? const Center(child: Text('No purchase orders yet.'))
                : ListView.builder(
                    itemCount: _purchaseOrders.length,
                    itemBuilder: (context, index) {
                      final po = _purchaseOrders[index];
                      return ListTile(
                        title: Text('${po.id} • ${po.supplier}'),
                        subtitle: Text(
                          'Items ${po.itemsCount} • ${_money(po.amount)}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeesPage() {
    return _moduleCard(
      title: 'Employee Management',
      action: ElevatedButton.icon(
        onPressed: _canManageEmployees
            ? () async {
                final employee = await _showEmployeeDialog();
                if (employee == null) return;
                setState(() {
                  _employees.add(employee);
                  _enqueueSync('INSERT', 'employees', employee.id);
                });
              }
            : null,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Employee'),
      ),
      child: SizedBox(
        height: 520,
        child: ListView.builder(
          itemCount: _employees.length,
          itemBuilder: (context, index) {
            final e = _employees[index];
            return Card(
              child: ListTile(
                title: Text('${e.name} (${e.id})'),
                subtitle: Text('Role ${e.role}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: e.active,
                      onChanged: _canManageEmployees
                          ? (v) {
                              setState(() {
                                e.active = v;
                                _enqueueSync('UPDATE', 'employees', e.id);
                              });
                            }
                          : null,
                    ),
                    IconButton(
                      onPressed: _canManageEmployees
                          ? () async {
                              final edited = await _showEmployeeDialog(
                                existing: e,
                              );
                              if (edited == null) return;
                              setState(() {
                                final i = _employees.indexWhere(
                                  (x) => x.id == e.id,
                                );
                                _employees[i] = edited;
                                _enqueueSync('UPDATE', 'employees', edited.id);
                              });
                            }
                          : null,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: _canManageEmployees
                          ? () {
                              setState(() {
                                _employees.removeWhere((x) => x.id == e.id);
                                _enqueueSync('DELETE', 'employees', e.id);
                              });
                            }
                          : null,
                      icon: const Icon(Icons.delete_outline),
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

  Widget _buildUsersPage() {
    final locationOptions = {
      _storeLocation.trim(),
      'Main Branch',
      'Warehouse',
      'Online',
    }.where((v) => v.isNotEmpty).toList();

    return _moduleCard(
      title: 'User Management',
      action: ElevatedButton.icon(
        onPressed: _canManageEmployees
            ? () async {
                final created = await _showUserDialog();
                if (created == null) return;
                final authService = context.read<AuthService>();
                final createdLogin = await authService.createStoreLogin(
                  storeName: _companyName,
                  tenantId: _activeTenantId ?? 'local',
                  email: created.user.email,
                  password: created.password,
                  role: created.user.role.toLowerCase(),
                  userName: created.user.name,
                );
                if (!createdLogin) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not create login (email already exists)',
                      ),
                    ),
                  );
                  return;
                }

                setState(() => _users.add(created.user));
                await _enqueueSync('INSERT', 'users', created.user.id);
              }
            : null,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add User'),
      ),
      child: SizedBox(
        height: 520,
        child: ListView.builder(
          itemCount: _users.length,
          itemBuilder: (context, index) {
            final user = _users[index];
            return Card(
              child: ListTile(
                title: Text('${user.name} (${user.role})'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(user.email),
                    const SizedBox(height: 2),
                    Text(
                      'Permissions: ${user.permissions.join(', ')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Locations: ${user.locations.join(', ')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: user.active,
                      onChanged: _canManageEmployees
                          ? (v) async {
                              setState(() => user.active = v);
                              await _enqueueSync('UPDATE', 'users', user.id);
                            }
                          : null,
                    ),
                    IconButton(
                      onPressed: _canManageEmployees
                          ? () async {
                              final edited = await _showUserDialog(
                                existing: user,
                              );
                              if (edited == null) return;
                              setState(() {
                                final i = _users.indexWhere(
                                  (x) => x.id == user.id,
                                );
                                _users[i] = edited.user;
                              });

                              if (edited.password.isNotEmpty) {
                                final authService = context.read<AuthService>();
                                await authService.createStoreLogin(
                                  storeName: _companyName,
                                  tenantId: _activeTenantId ?? 'local',
                                  email: edited.user.email,
                                  password: edited.password,
                                  role: edited.user.role.toLowerCase(),
                                  userName: edited.user.name,
                                );
                              }

                              await _enqueueSync(
                                'UPDATE',
                                'users',
                                edited.user.id,
                              );
                            }
                          : null,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: _canManageEmployees
                          ? () async {
                              setState(
                                () =>
                                    _users.removeWhere((x) => x.id == user.id),
                              );
                              await _enqueueSync('DELETE', 'users', user.id);
                            }
                          : null,
                      icon: const Icon(Icons.delete_outline),
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

  Widget _buildSettingsTabContent() {
    switch (_settingsTab) {
      case 'general':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: _companyName,
              decoration: const InputDecoration(
                labelText: 'Company Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _companyName = v,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _storeLocation,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _storeLocation = v,
            ),
          ],
        );
      case 'hours':
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _openFrom,
                decoration: const InputDecoration(
                  labelText: 'Open From',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _openFrom = v,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: _openTo,
                decoration: const InputDecoration(
                  labelText: 'Open To',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _openTo = v,
              ),
            ),
          ],
        );
      case 'payments':
        return Column(
          children: [
            CheckboxListTile(
              title: const Text('Accept Cash'),
              value: _acceptCash,
              onChanged: (v) => setState(() => _acceptCash = v ?? true),
            ),
            CheckboxListTile(
              title: const Text('Accept Card'),
              value: _acceptCard,
              onChanged: (v) => setState(() => _acceptCard = v ?? true),
            ),
            CheckboxListTile(
              title: const Text('Accept Cheque'),
              value: _acceptCheque,
              onChanged: (v) => setState(() => _acceptCheque = v ?? false),
            ),
            CheckboxListTile(
              title: const Text('Accept Installment'),
              value: _acceptInstallment,
              onChanged: (v) => setState(() => _acceptInstallment = v ?? false),
            ),
          ],
        );
      case 'tax':
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _taxRate,
                decoration: const InputDecoration(
                  labelText: 'Tax Rate (%)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _taxRate = v,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _currency,
                items: const [
                  DropdownMenuItem(value: 'LKR', child: Text('LKR')),
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                  DropdownMenuItem(value: 'INR', child: Text('INR')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _currency = v);
                },
                decoration: const InputDecoration(
                  labelText: 'Currency',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        );
      case 'receipt':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: _receiptHeader,
              decoration: const InputDecoration(
                labelText: 'Receipt Header',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _receiptHeader = v,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: _receiptFooter,
              decoration: const InputDecoration(
                labelText: 'Receipt Footer',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _receiptFooter = v,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: _receiptNote,
              decoration: const InputDecoration(
                labelText: 'Receipt Note',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _receiptNote = v,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Tax in Receipt'),
              value: _receiptShowTax,
              onChanged: (v) => setState(() => _receiptShowTax = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Logo Placeholder in Receipt'),
              value: _receiptShowLogo,
              onChanged: (v) => setState(() => _receiptShowLogo = v),
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _receiptPaper,
                    decoration: const InputDecoration(
                      labelText: 'Paper Size',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: '58mm',
                        child: Text('58mm Thermal'),
                      ),
                      DropdownMenuItem(
                        value: '80mm',
                        child: Text('80mm Thermal'),
                      ),
                      DropdownMenuItem(value: 'A4', child: Text('A4')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _receiptPaper = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: _receiptMargin,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Margin',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _receiptMargin = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: _receiptFontScale,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Font Scale (e.g. 1.0)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _receiptFontScale = v,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _printDemoReceipt,
              icon: const Icon(Icons.print),
              label: const Text('Print Demo Bill'),
            ),
          ],
        );
      case 'integrations':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _integrationMode,
              items: const [
                DropdownMenuItem(
                  value: 'Cloud Sync',
                  child: Text('Cloud Sync'),
                ),
                DropdownMenuItem(
                  value: 'Local Only',
                  child: Text('Local Only'),
                ),
                DropdownMenuItem(value: 'Hybrid', child: Text('Hybrid')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _integrationMode = v);
              },
              decoration: const InputDecoration(
                labelText: 'Mode',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _integrationWebhook,
              decoration: const InputDecoration(
                labelText: 'Webhook URL (optional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _integrationWebhook = v,
            ),
          ],
        );
      case 'notifications':
        return Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Low Stock Alerts'),
              value: _notifyLowStock,
              onChanged: (v) => setState(() => _notifyLowStock = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Daily Sales Summary'),
              value: _notifyDailySummary,
              onChanged: (v) => setState(() => _notifyDailySummary = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Return Notifications'),
              value: _notifyReturns,
              onChanged: (v) => setState(() => _notifyReturns = v),
            ),
          ],
        );
      case 'cash':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Cash Drawer Integration'),
              value: _cashDrawerEnabled,
              onChanged: (v) => setState(() => _cashDrawerEnabled = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Require PIN for Open Drawer'),
              value: _cashDrawerRequirePin,
              onChanged: (v) => setState(() => _cashDrawerRequirePin = v),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _cashDrawerPin,
              decoration: const InputDecoration(
                labelText: 'Drawer PIN',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              onChanged: (v) => _cashDrawerPin = v,
            ),
          ],
        );
      default:
        return const Text(
          'This settings section is ready for integration configuration.',
        );
    }
  }

  Widget _buildReportsPage() {
    final totalRevenue = _sales.fold<double>(0, (sum, s) => sum + s.total);
    final completed = _sales.where((s) => s.status == 'COMPLETED').length;
    final cancelled = _sales.where((s) => s.status == 'CANCELLED').length;
    final returned = _sales.where((s) => s.status == 'RETURNED').length;
    final lowStock = _products.where((p) => p.stock <= p.minStock).length;
    final inventoryValue = _products.fold<double>(
      0,
      (sum, p) => sum + (p.price * p.stock),
    );

    return _moduleCard(
      title: 'Reports & Analytics',
      action: OutlinedButton.icon(
        onPressed: _exportReportsCsv,
        icon: const Icon(Icons.download),
        label: const Text('Export'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'sales', label: Text('Sales Reports')),
              ButtonSegment(
                value: 'inventory',
                label: Text('Inventory Reports'),
              ),
              ButtonSegment(
                value: 'customers',
                label: Text('Customer Reports'),
              ),
            ],
            selected: {_selectedReportType},
            onSelectionChanged: (set) =>
                setState(() => _selectedReportType = set.first),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _statBox('Total Revenue', _money(totalRevenue)),
              _statBox('Completed Sales', '$completed'),
              _statBox('Cancelled Sales', '$cancelled'),
              _statBox('Returned Sales', '$returned'),
              _statBox('Customers', '${_customers.length}'),
              _statBox('Low Stock Products', '$lowStock'),
              _statBox('Inventory Value', _money(inventoryValue)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 320,
            child: _selectedReportType == 'sales'
                ? ListView.builder(
                    itemCount: _sales.length,
                    itemBuilder: (context, index) {
                      final sale = _sales[index];
                      return ListTile(
                        title: Text('${sale.id} • ${_money(sale.total)}'),
                        subtitle: Text(
                          '${sale.status} • ${sale.paymentMethod} • ${sale.createdAt.toLocal()}',
                        ),
                      );
                    },
                  )
                : _selectedReportType == 'inventory'
                ? ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final p = _products[index];
                      return ListTile(
                        title: Text('${p.name} (${p.id})'),
                        subtitle: Text(
                          'Stock ${p.stock} • Min ${p.minStock} • Value ${_money(p.price * p.stock)}',
                        ),
                        trailing: p.stock <= p.minStock
                            ? const Chip(
                                label: Text('LOW'),
                                backgroundColor: Color(0xFFFFE5E5),
                              )
                            : null,
                      );
                    },
                  )
                : ListView.builder(
                    itemCount: _customers.length,
                    itemBuilder: (context, index) {
                      final c = _customers[index];
                      final customerSales = _sales
                          .where((s) => s.customerName == c.name)
                          .toList();
                      final spend = customerSales.fold<double>(
                        0,
                        (sum, s) => sum + s.total,
                      );
                      return ListTile(
                        title: Text(c.name),
                        subtitle: Text(
                          '${c.phone} • Orders: ${customerSales.length} • '
                          'Points: ${c.loyaltyPoints} • Credit: ${_money(c.currentBalance)}',
                        ),
                        trailing: Text(_money(spend)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPage() {
    return _moduleCard(
      title: 'Settings',
      action: ElevatedButton.icon(
        onPressed: _canManageSettings
            ? () async {
                _enqueueSync('UPDATE', 'settings', 'company_settings');
                await _persistWorkspaceData();
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Settings saved')));
              }
            : null,
        icon: const Icon(Icons.save),
        label: const Text('Save Settings'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manage your configuration, hours, payments and receipt.',
            style: TextStyle(color: Color(0xFF6D7383)),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _settingsTabs
                  .map(
                    (tab) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tab.icon, size: 16),
                            const SizedBox(width: 6),
                            Text(tab.label),
                          ],
                        ),
                        selected: _settingsTab == tab.key,
                        onSelected: (_) =>
                            setState(() => _settingsTab = tab.key),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDE0EA)),
              color: Colors.white,
            ),
            child: _buildSettingsTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketingPage() {
    return _moduleCard(
      title: 'Marketing & Loyalty',
      action: ElevatedButton.icon(
        onPressed: () async {
          final coupon = await _showCouponDialog();
          if (coupon == null) return;
          setState(() {
            _coupons.add(coupon);
            _enqueueSync('INSERT', 'coupons', coupon.code);
          });
        },
        icon: const Icon(Icons.local_offer_outlined),
        label: const Text('Create Coupon'),
      ),
      child: SizedBox(
        height: 520,
        child: _coupons.isEmpty
            ? const Center(child: Text('No campaigns yet.'))
            : ListView.builder(
                itemCount: _coupons.length,
                itemBuilder: (context, index) {
                  final c = _coupons[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        '${c.code} • ${c.discountPercent.toStringAsFixed(1)}%',
                      ),
                      subtitle: Text(c.description),
                      trailing: Switch(
                        value: c.active,
                        onChanged: (v) {
                          setState(() {
                            c.active = v;
                            _enqueueSync('UPDATE', 'coupons', c.code);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildServicesPage() {
    return _moduleCard(
      title: 'Services & Warranties',
      action: ElevatedButton.icon(
        onPressed: () async {
          final job = await _showServiceDialog();
          if (job == null) return;
          setState(() {
            _serviceJobs.add(job);
            _enqueueSync('INSERT', 'services', job.id);
          });
        },
        icon: const Icon(Icons.build_circle_outlined),
        label: const Text('Add Service Job'),
      ),
      child: SizedBox(
        height: 520,
        child: _serviceJobs.isEmpty
            ? const Center(child: Text('No service jobs yet.'))
            : ListView.builder(
                itemCount: _serviceJobs.length,
                itemBuilder: (context, index) {
                  final job = _serviceJobs[index];
                  return Card(
                    child: ListTile(
                      title: Text('${job.id} • ${job.title}'),
                      subtitle: Text(
                        'Technician: ${job.technician} • Warranty: ${job.warranty ? 'Yes' : 'No'}',
                      ),
                      trailing: DropdownButton<String>(
                        value: job.status,
                        items: const [
                          DropdownMenuItem(
                            value: 'PENDING',
                            child: Text('PENDING'),
                          ),
                          DropdownMenuItem(
                            value: 'IN_PROGRESS',
                            child: Text('IN_PROGRESS'),
                          ),
                          DropdownMenuItem(value: 'DONE', child: Text('DONE')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            job.status = v;
                            _enqueueSync('UPDATE', 'services', job.id);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildSuppliersPage() {
    return _moduleCard(
      title: 'Suppliers',
      action: ElevatedButton.icon(
        onPressed: () async {
          final supplier = await _showSupplierDialog();
          if (supplier == null) return;
          setState(() {
            _suppliers.add(supplier);
            _enqueueSync('INSERT', 'suppliers', supplier.id);
          });
        },
        icon: const Icon(Icons.local_shipping_outlined),
        label: const Text('Add Supplier'),
      ),
      child: SizedBox(
        height: 520,
        child: _suppliers.isEmpty
            ? const Center(child: Text('No suppliers yet.'))
            : ListView.builder(
                itemCount: _suppliers.length,
                itemBuilder: (context, index) {
                  final s = _suppliers[index];
                  return Card(
                    child: ListTile(
                      title: Text(s.name),
                      subtitle: Text('${s.contact} • ${s.email}'),
                      trailing: IconButton(
                        onPressed: () {
                          setState(() {
                            _suppliers.removeWhere((x) => x.id == s.id);
                            _enqueueSync('DELETE', 'suppliers', s.id);
                          });
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildInvoicesPage() {
    return _moduleCard(
      title: 'Invoices',
      action: ElevatedButton.icon(
        onPressed: _sales.isEmpty
            ? null
            : () {
                final sale = _sales.first;
                final invoice = _InvoiceItem(
                  id: 'INV${DateTime.now().millisecondsSinceEpoch}',
                  saleId: sale.id,
                  amount: sale.total,
                  status: 'UNPAID',
                );
                setState(() {
                  _invoices.insert(0, invoice);
                  _enqueueSync('INSERT', 'invoices', invoice.id);
                });
              },
        icon: const Icon(Icons.request_page),
        label: const Text('Generate From Latest Sale'),
      ),
      child: SizedBox(
        height: 520,
        child: _invoices.isEmpty
            ? const Center(
                child: Text(
                  'No invoices yet. Complete sales and generate invoices.',
                ),
              )
            : ListView.builder(
                itemCount: _invoices.length,
                itemBuilder: (context, index) {
                  final inv = _invoices[index];
                  return Card(
                    child: ListTile(
                      title: Text('${inv.id} • ${_money(inv.amount)}'),
                      subtitle: Text('Sale ${inv.saleId}'),
                      trailing: DropdownButton<String>(
                        value: inv.status,
                        items: const [
                          DropdownMenuItem(
                            value: 'UNPAID',
                            child: Text('UNPAID'),
                          ),
                          DropdownMenuItem(value: 'PAID', child: Text('PAID')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            inv.status = v;
                            _enqueueSync('UPDATE', 'invoices', inv.id);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildSyncPage() {
    return _moduleCard(
      title: 'Sync Manager',
      action: ElevatedButton.icon(
        onPressed: _canRunSync && !_syncInProgress ? _runManualSync : null,
        icon: const Icon(Icons.sync),
        label: Text(_syncInProgress ? 'Syncing...' : 'Run Manual Sync'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last sync: ${_lastSyncAt?.toLocal().toString() ?? 'Never'}'),
          if (_lastSyncError != null) ...[
            const SizedBox(height: 8),
            Text(
              _lastSyncError!,
              style: const TextStyle(
                color: Color(0xFFE35D5D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text('Pending operations: ${_syncQueue.length}'),
          const SizedBox(height: 10),
          SizedBox(
            height: 460,
            child: _syncQueue.isEmpty
                ? const Center(child: Text('No pending operations'))
                : ListView.builder(
                    itemCount: _syncQueue.length,
                    itemBuilder: (context, index) {
                      final s = _syncQueue[index];
                      return ListTile(
                        leading: const Icon(Icons.sync_problem),
                        title: Text('${s.action} ${s.module}'),
                        subtitle: Text(
                          '${s.reference} • ${s.timestamp.toLocal()}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _moduleCard({
    required String title,
    required Widget child,
    Widget? action,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  action ?? const SizedBox.shrink(),
                ],
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDDE0EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6D7383))),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 24),
          ),
        ],
      ),
    );
  }

  Future<_ProductItem?> _showProductDialog({_ProductItem? existing}) async {
    final idController = TextEditingController(
      text:
          existing?.id ?? 'P${DateTime.now().millisecondsSinceEpoch % 100000}',
    );
    final nameController = TextEditingController(text: existing?.name ?? '');
    final barcodeController = TextEditingController(
      text: existing?.barcode ?? _generateBarcodeValue(),
    );
    final priceController = TextEditingController(
      text: existing?.price.toString() ?? '0',
    );
    final stockController = TextEditingController(
      text: existing?.stock.toString() ?? '0',
    );
    final minStockController = TextEditingController(
      text: existing?.minStock.toString() ?? '0',
    );

    return showDialog<_ProductItem>(
      context: context,
      builder: (context) {
        final categories = _productCategories.isEmpty
            ? ['General']
            : List<String>.from(_productCategories);
        String selectedCategory = existing?.category.isNotEmpty == true
            ? existing!.category
            : categories.first;
        final newCategoryController = TextEditingController();

        if (!categories.any(
          (c) => c.toLowerCase() == selectedCategory.toLowerCase(),
        )) {
          categories.add(selectedCategory);
        }

        return StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: Text(existing == null ? 'Add Product' : 'Edit Product'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(labelText: 'ID'),
                  ),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: barcodeController,
                          decoration: const InputDecoration(
                            labelText: 'Barcode',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          barcodeController.text = _generateBarcodeValue();
                        },
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text('Generate'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(selectedCategory),
                          initialValue: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: categories
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setLocal(() => selectedCategory = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newCategoryController,
                          decoration: const InputDecoration(
                            labelText: 'Add New Category',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final value = newCategoryController.text.trim();
                          if (value.isEmpty) return;
                          if (categories.any(
                            (c) => c.toLowerCase() == value.toLowerCase(),
                          ))
                            return;
                          setLocal(() {
                            categories.add(value);
                            selectedCategory = value;
                          });
                          newCategoryController.clear();
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Price'),
                  ),
                  TextField(
                    controller: stockController,
                    decoration: const InputDecoration(labelText: 'Stock'),
                  ),
                  TextField(
                    controller: minStockController,
                    decoration: const InputDecoration(labelText: 'Min Stock'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final item = _ProductItem(
                    id: idController.text.trim(),
                    name: nameController.text.trim(),
                    category: selectedCategory,
                    barcode: barcodeController.text.trim(),
                    price: double.tryParse(priceController.text.trim()) ?? 0,
                    stock: int.tryParse(stockController.text.trim()) ?? 0,
                    minStock: int.tryParse(minStockController.text.trim()) ?? 0,
                  );
                  if (!_productCategories.any(
                    (c) => c.toLowerCase() == selectedCategory.toLowerCase(),
                  )) {
                    _productCategories.add(selectedCategory);
                  }
                  Navigator.pop(context, item);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_CustomerItem?> _showCustomerDialog({_CustomerItem? existing}) async {
    final idController = TextEditingController(
      text:
          existing?.id ?? 'C${DateTime.now().millisecondsSinceEpoch % 100000}',
    );
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final creditLimitController = TextEditingController(
      text: (existing?.creditLimit ?? 0).toString(),
    );
    final currentBalanceController = TextEditingController(
      text: (existing?.currentBalance ?? 0).toString(),
    );
    final loyaltyPointsController = TextEditingController(
      text: (existing?.loyaltyPoints ?? 0).toString(),
    );

    return showDialog<_CustomerItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Customer' : 'Edit Customer'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: const InputDecoration(labelText: 'ID'),
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: creditLimitController,
                decoration: const InputDecoration(labelText: 'Credit Limit'),
              ),
              TextField(
                controller: currentBalanceController,
                decoration: const InputDecoration(labelText: 'Current Balance'),
              ),
              TextField(
                controller: loyaltyPointsController,
                decoration: const InputDecoration(labelText: 'Loyalty Points'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                _CustomerItem(
                  id: idController.text.trim(),
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                  email: emailController.text.trim(),
                  creditLimit:
                      double.tryParse(creditLimitController.text.trim()) ?? 0,
                  currentBalance:
                      double.tryParse(currentBalanceController.text.trim()) ??
                      0,
                  loyaltyPoints:
                      int.tryParse(loyaltyPointsController.text.trim()) ?? 0,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<_EmployeeItem?> _showEmployeeDialog({_EmployeeItem? existing}) async {
    final idController = TextEditingController(
      text:
          existing?.id ?? 'E${DateTime.now().millisecondsSinceEpoch % 100000}',
    );
    final nameController = TextEditingController(text: existing?.name ?? '');
    String role = existing?.role ?? 'CASHIER';
    bool active = existing?.active ?? true;

    return showDialog<_EmployeeItem>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add Employee' : 'Edit Employee'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idController,
                  decoration: const InputDecoration(labelText: 'ID'),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>(role),
                  initialValue: role,
                  items: const [
                    DropdownMenuItem(value: 'OWNER', child: Text('OWNER')),
                    DropdownMenuItem(value: 'MANAGER', child: Text('MANAGER')),
                    DropdownMenuItem(value: 'CASHIER', child: Text('CASHIER')),
                    DropdownMenuItem(
                      value: 'TECHNICIAN',
                      child: Text('TECHNICIAN'),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => role = v ?? role),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  _EmployeeItem(
                    id: idController.text.trim(),
                    name: nameController.text.trim(),
                    role: role,
                    active: active,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<_UserDialogResult?> _showUserDialog({_UserItem? existing}) async {
    final idController = TextEditingController(
      text:
          existing?.id ?? 'U${DateTime.now().millisecondsSinceEpoch % 100000}',
    );
    final nameController = TextEditingController(text: existing?.name ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final passwordController = TextEditingController();
    String role = existing?.role ?? 'CASHIER';
    bool active = existing?.active ?? true;
    final permissionOptions = [
      'POS',
      'Products',
      'Sales',
      'Customers',
      'Reports',
      'Settings',
    ];
    final locationOptions = {
      _storeLocation.trim(),
      'Main Branch',
      'Warehouse',
      'Online',
    }.where((v) => v.isNotEmpty).toList();
    final selectedPermissions = <String>{
      ...(existing?.permissions ?? ['POS', 'Sales', 'Customers']),
    };
    final selectedLocations = <String>{
      ...(existing?.locations ?? [locationOptions.first]),
    };

    return showDialog<_UserDialogResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add User' : 'Edit User'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idController,
                  decoration: const InputDecoration(labelText: 'ID'),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: existing == null
                        ? 'Password (for login)'
                        : 'Password (leave empty to keep current login)',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>(role),
                  initialValue: role,
                  items: const [
                    DropdownMenuItem(value: 'OWNER', child: Text('OWNER')),
                    DropdownMenuItem(value: 'MANAGER', child: Text('MANAGER')),
                    DropdownMenuItem(value: 'CASHIER', child: Text('CASHIER')),
                  ],
                  onChanged: (v) => setLocal(() => role = v ?? role),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Permissions',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: permissionOptions
                      .map(
                        (perm) => FilterChip(
                          label: Text(perm),
                          selected: selectedPermissions.contains(perm),
                          onSelected: (selected) {
                            setLocal(() {
                              if (selected) {
                                selectedPermissions.add(perm);
                              } else {
                                selectedPermissions.remove(perm);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Locations',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: locationOptions
                      .map(
                        (loc) => FilterChip(
                          label: Text(loc),
                          selected: selectedLocations.contains(loc),
                          onSelected: (selected) {
                            setLocal(() {
                              if (selected) {
                                selectedLocations.add(loc);
                              } else {
                                selectedLocations.remove(loc);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (existing == null &&
                    passwordController.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(
                  context,
                  _UserDialogResult(
                    user: _UserItem(
                      id: idController.text.trim(),
                      name: nameController.text.trim(),
                      email: emailController.text.trim(),
                      role: role,
                      active: active,
                      permissions: selectedPermissions.toList(),
                      locations: selectedLocations.toList(),
                    ),
                    password: passwordController.text.trim(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<_CouponItem?> _showCouponDialog() async {
    final codeController = TextEditingController();
    final descriptionController = TextEditingController();
    final discountController = TextEditingController(text: '5');

    return showDialog<_CouponItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Coupon'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: discountController,
                decoration: const InputDecoration(labelText: 'Discount %'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                _CouponItem(
                  code: codeController.text.trim(),
                  description: descriptionController.text.trim(),
                  discountPercent:
                      double.tryParse(discountController.text.trim()) ?? 0,
                  active: true,
                ),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<_ServiceJobItem?> _showServiceDialog() async {
    final titleController = TextEditingController();
    final techController = TextEditingController();
    bool warranty = false;

    return showDialog<_ServiceJobItem>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add Service Job'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Job Title'),
                ),
                TextField(
                  controller: techController,
                  decoration: const InputDecoration(labelText: 'Technician'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Warranty'),
                  value: warranty,
                  onChanged: (v) => setLocal(() => warranty = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  _ServiceJobItem(
                    id: 'SRV${DateTime.now().millisecondsSinceEpoch}',
                    title: titleController.text.trim(),
                    technician: techController.text.trim(),
                    warranty: warranty,
                    status: 'PENDING',
                  ),
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<_SupplierItem?> _showSupplierDialog() async {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    final emailController = TextEditingController();

    return showDialog<_SupplierItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Supplier'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Supplier Name'),
              ),
              TextField(
                controller: contactController,
                decoration: const InputDecoration(labelText: 'Contact'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                _SupplierItem(
                  id: 'SUP${DateTime.now().millisecondsSinceEpoch}',
                  name: nameController.text.trim(),
                  contact: contactController.text.trim(),
                  email: emailController.text.trim(),
                ),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<_PurchaseOrderItem?> _showPurchaseOrderDialog() async {
    final supplierController = TextEditingController();
    final itemsController = TextEditingController(text: '1');
    final amountController = TextEditingController(text: '0');

    return showDialog<_PurchaseOrderItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Purchase Order'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: supplierController,
                decoration: const InputDecoration(labelText: 'Supplier'),
              ),
              TextField(
                controller: itemsController,
                decoration: const InputDecoration(labelText: 'Items Count'),
              ),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Total Amount'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                _PurchaseOrderItem(
                  id: 'PO${DateTime.now().millisecondsSinceEpoch}',
                  supplier: supplierController.text.trim(),
                  itemsCount: int.tryParse(itemsController.text.trim()) ?? 0,
                  amount: double.tryParse(amountController.text.trim()) ?? 0,
                ),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthInitial) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      },
      child: Scaffold(
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              if (state.user.role == 'platform_admin') {
                return _buildPlatformAdminPanel();
              }
              return _buildStoreShell(state);
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}

class _NavItem {
  final String key;
  final String label;
  final IconData icon;

  const _NavItem({required this.key, required this.label, required this.icon});
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EBFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF5B35D5)),
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                '+0% vs last period',
                style: TextStyle(color: Color(0xFF0B9F69)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductItem {
  final String id;
  String name;
  String category;
  String barcode;
  double price;
  int stock;
  int minStock;

  _ProductItem({
    required this.id,
    required this.name,
    required this.category,
    this.barcode = '',
    required this.price,
    required this.stock,
    required this.minStock,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'barcode': barcode,
      'price': price,
      'stock': stock,
      'minStock': minStock,
    };
  }

  factory _ProductItem.fromJson(Map<String, dynamic> json) {
    return _ProductItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      barcode: (json['barcode'] ?? json['id'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      minStock: (json['minStock'] as num?)?.toInt() ?? 0,
    );
  }
}

class _CreditPaymentItem {
  final String id;
  final double amount;
  final String note;
  final DateTime createdAt;

  _CreditPaymentItem({
    required this.id,
    required this.amount,
    required this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory _CreditPaymentItem.fromJson(Map<String, dynamic> json) {
    return _CreditPaymentItem(
      id: (json['id'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      note: (json['note'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class _CustomerItem {
  final String id;
  String name;
  String phone;
  String email;
  double creditLimit;
  double currentBalance;
  int loyaltyPoints;

  _CustomerItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.creditLimit = 0,
    this.currentBalance = 0,
    this.loyaltyPoints = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'creditLimit': creditLimit,
      'currentBalance': currentBalance,
      'loyaltyPoints': loyaltyPoints,
    };
  }

  factory _CustomerItem.fromJson(Map<String, dynamic> json) {
    return _CustomerItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      creditLimit: (json['creditLimit'] as num?)?.toDouble() ?? 0,
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0,
      loyaltyPoints: (json['loyaltyPoints'] as num?)?.toInt() ?? 0,
    );
  }
}

class _EmployeeItem {
  final String id;
  String name;
  String role;
  bool active;

  _EmployeeItem({
    required this.id,
    required this.name,
    required this.role,
    required this.active,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'role': role, 'active': active};
  }

  factory _EmployeeItem.fromJson(Map<String, dynamic> json) {
    return _EmployeeItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      role: (json['role'] ?? 'CASHIER').toString(),
      active: json['active'] as bool? ?? true,
    );
  }
}

class _UserItem {
  final String id;
  String name;
  String email;
  String role;
  bool active;
  List<String> permissions;
  List<String> locations;

  _UserItem({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    this.permissions = const [],
    this.locations = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'active': active,
      'permissions': permissions,
      'locations': locations,
    };
  }

  factory _UserItem.fromJson(Map<String, dynamic> json) {
    return _UserItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'CASHIER').toString(),
      active: json['active'] as bool? ?? true,
      permissions: (json['permissions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      locations: (json['locations'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class _UserDialogResult {
  final _UserItem user;
  final String password;

  _UserDialogResult({required this.user, required this.password});
}

class _SettingsTabItem {
  final String key;
  final String label;
  final IconData icon;

  const _SettingsTabItem({
    required this.key,
    required this.label,
    required this.icon,
  });
}

class _SupplierItem {
  final String id;
  String name;
  String contact;
  String email;

  _SupplierItem({
    required this.id,
    required this.name,
    required this.contact,
    required this.email,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'contact': contact, 'email': email};
  }

  factory _SupplierItem.fromJson(Map<String, dynamic> json) {
    return _SupplierItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      contact: (json['contact'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
    );
  }
}

class _CouponItem {
  final String code;
  String description;
  double discountPercent;
  bool active;

  _CouponItem({
    required this.code,
    required this.description,
    required this.discountPercent,
    required this.active,
  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'description': description,
      'discountPercent': discountPercent,
      'active': active,
    };
  }

  factory _CouponItem.fromJson(Map<String, dynamic> json) {
    return _CouponItem(
      code: (json['code'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0,
      active: json['active'] as bool? ?? true,
    );
  }
}

class _ServiceJobItem {
  final String id;
  String title;
  String technician;
  bool warranty;
  String status;

  _ServiceJobItem({
    required this.id,
    required this.title,
    required this.technician,
    required this.warranty,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'technician': technician,
      'warranty': warranty,
      'status': status,
    };
  }

  factory _ServiceJobItem.fromJson(Map<String, dynamic> json) {
    return _ServiceJobItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      technician: (json['technician'] ?? '').toString(),
      warranty: json['warranty'] as bool? ?? false,
      status: (json['status'] ?? 'PENDING').toString(),
    );
  }
}

class _SaleRecord {
  final String id;
  final String customerName;
  final String paymentMethod;
  final double subtotal;
  final double tax;
  final double total;
  String status;
  String? returnReason;
  final DateTime createdAt;

  _SaleRecord({
    required this.id,
    required this.customerName,
    required this.paymentMethod,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.status,
    this.returnReason,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerName': customerName,
      'paymentMethod': paymentMethod,
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'status': status,
      'returnReason': returnReason,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory _SaleRecord.fromJson(Map<String, dynamic> json) {
    return _SaleRecord(
      id: (json['id'] ?? '').toString(),
      customerName: (json['customerName'] ?? '').toString(),
      paymentMethod: (json['paymentMethod'] ?? 'CASH').toString(),
      subtotal:
          (json['subtotal'] as num?)?.toDouble() ??
          (json['total'] as num?)?.toDouble() ??
          0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      status: (json['status'] ?? 'COMPLETED').toString(),
      returnReason: json['returnReason']?.toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class _HeldCart {
  final String id;
  final String? customerId;
  final String? paymentMethod;
  final Map<String, int> items;
  final DateTime createdAt;

  _HeldCart({
    required this.id,
    required this.customerId,
    required this.paymentMethod,
    required this.items,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'paymentMethod': paymentMethod,
      'items': items,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory _HeldCart.fromJson(Map<String, dynamic> json) {
    final rawItems = Map<String, dynamic>.from(json['items'] ?? {});
    return _HeldCart(
      id: (json['id'] ?? '').toString(),
      customerId: json['customerId']?.toString(),
      paymentMethod: json['paymentMethod']?.toString(),
      items: rawItems.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class _InvoiceItem {
  final String id;
  final String saleId;
  final double amount;
  String status;

  _InvoiceItem({
    required this.id,
    required this.saleId,
    required this.amount,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'saleId': saleId, 'amount': amount, 'status': status};
  }

  factory _InvoiceItem.fromJson(Map<String, dynamic> json) {
    return _InvoiceItem(
      id: (json['id'] ?? '').toString(),
      saleId: (json['saleId'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: (json['status'] ?? 'UNPAID').toString(),
    );
  }
}

class _PurchaseOrderItem {
  final String id;
  final String supplier;
  final int itemsCount;
  final double amount;

  _PurchaseOrderItem({
    required this.id,
    required this.supplier,
    required this.itemsCount,
    required this.amount,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplier': supplier,
      'itemsCount': itemsCount,
      'amount': amount,
    };
  }

  factory _PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    return _PurchaseOrderItem(
      id: (json['id'] ?? '').toString(),
      supplier: (json['supplier'] ?? '').toString(),
      itemsCount: (json['itemsCount'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _SyncItem {
  final DateTime timestamp;
  final String action;
  final String module;
  final String reference;

  _SyncItem({
    required this.timestamp,
    required this.action,
    required this.module,
    required this.reference,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'action': action,
      'module': module,
      'reference': reference,
    };
  }

  factory _SyncItem.fromJson(Map<String, dynamic> json) {
    return _SyncItem(
      timestamp:
          DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now(),
      action: (json['action'] ?? '').toString(),
      module: (json['module'] ?? '').toString(),
      reference: (json['reference'] ?? '').toString(),
    );
  }
}

class _CartLine {
  final _ProductItem product;
  final int qty;

  _CartLine({required this.product, required this.qty});
}
