import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../blocs/auth/auth_bloc.dart';
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
  static const String _workspaceStateKey = 'workspace_state_v1';

  final _storeNameController = TextEditingController();
  final _tenantIdController = TextEditingController();
  final _storeEmailController = TextEditingController();
  final _storePasswordController = TextEditingController();

  final _productSearchController = TextEditingController();
  final _customerSearchController = TextEditingController();
  final _paymentMethodController = ValueNotifier<String>('CASH');

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
    ),
    _ProductItem(
      id: 'P002',
      name: 'Coke 500ml',
      category: 'Beverage',
      price: 350,
      stock: 55,
      minStock: 12,
    ),
    _ProductItem(
      id: 'P003',
      name: 'French Fries',
      category: 'Food',
      price: 700,
      stock: 18,
      minStock: 10,
    ),
  ];
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
  final List<_SupplierItem> _suppliers = [];
  final List<_CouponItem> _coupons = [];
  final List<_ServiceJobItem> _serviceJobs = [];
  final List<_SaleRecord> _sales = [];
  final List<_InvoiceItem> _invoices = [];
  final List<_PurchaseOrderItem> _purchaseOrders = [];
  final List<_SyncItem> _syncQueue = [];

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
  DateTime? _lastSyncAt;

  SyncService? _syncService;
  bool _syncInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadStoreLogins();
    _selectedCustomerId = _customers.first.id;
    _loadPersistedWorkspaceData();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _tenantIdController.dispose();
    _storeEmailController.dispose();
    _storePasswordController.dispose();
    _productSearchController.dispose();
    _customerSearchController.dispose();
    _paymentMethodController.dispose();
    _syncService?.dispose();
    super.dispose();
  }

  void _enqueueSync(String action, String module, String ref) {
    _syncQueue.insert(
      0,
      _SyncItem(
        timestamp: DateTime.now(),
        action: action,
        module: module,
        reference: ref,
      ),
    );
    _persistWorkspaceData();
    _triggerRealtimeSync(action: action, module: module, reference: ref);
  }

  void _ensureSyncService(String tenantId) {
    if (_syncService != null) return;
    final apiClient = context.read<ApiClient>();
    _syncService = SyncService(apiClient, tenantId);
  }

  Future<void> _triggerRealtimeSync({
    required String action,
    required String module,
    required String reference,
  }) async {
    if (_syncService == null || _syncInProgress) return;
    _syncInProgress = true;

    try {
      await _syncService!.queueOperation(action, module, reference, {
        'id': reference,
        'module': module,
        'action': action,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await _syncService!.syncAllData();

      if (!mounted) return;
      setState(() {
        if (_syncQueue.isNotEmpty) {
          _syncQueue.removeAt(0);
        }
        _lastSyncAt = DateTime.now();
      });
      await _persistWorkspaceData();
    } catch (_) {
      // keep pending items in local queue if sync failed
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> _persistWorkspaceData() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'products': _products.map((e) => e.toJson()).toList(),
      'customers': _customers.map((e) => e.toJson()).toList(),
      'employees': _employees.map((e) => e.toJson()).toList(),
      'suppliers': _suppliers.map((e) => e.toJson()).toList(),
      'coupons': _coupons.map((e) => e.toJson()).toList(),
      'serviceJobs': _serviceJobs.map((e) => e.toJson()).toList(),
      'sales': _sales.map((e) => e.toJson()).toList(),
      'invoices': _invoices.map((e) => e.toJson()).toList(),
      'purchaseOrders': _purchaseOrders.map((e) => e.toJson()).toList(),
      'syncQueue': _syncQueue.map((e) => e.toJson()).toList(),
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
      final customerList = (decoded['customers'] as List<dynamic>? ?? [])
          .map((e) => _CustomerItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final employeeList = (decoded['employees'] as List<dynamic>? ?? [])
          .map((e) => _EmployeeItem.fromJson(Map<String, dynamic>.from(e)))
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
      final invoiceList = (decoded['invoices'] as List<dynamic>? ?? [])
          .map((e) => _InvoiceItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final poList = (decoded['purchaseOrders'] as List<dynamic>? ?? [])
          .map((e) => _PurchaseOrderItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final syncList = (decoded['syncQueue'] as List<dynamic>? ?? [])
          .map((e) => _SyncItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final settings = Map<String, dynamic>.from(decoded['settings'] ?? {});

      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addAll(productList);
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
        _invoices
          ..clear()
          ..addAll(invoiceList);
        _purchaseOrders
          ..clear()
          ..addAll(poList);
        _syncQueue
          ..clear()
          ..addAll(syncList);

        _companyName = settings['companyName'] ?? _companyName;
        _taxRate = settings['taxRate'] ?? _taxRate;
        _currency = settings['currency'] ?? _currency;
        _storeLocation = settings['storeLocation'] ?? _storeLocation;
        _receiptHeader = settings['receiptHeader'] ?? _receiptHeader;
        _receiptFooter = settings['receiptFooter'] ?? _receiptFooter;
        _receiptShowTax = settings['receiptShowTax'] ?? _receiptShowTax;
        _receiptShowLogo = settings['receiptShowLogo'] ?? _receiptShowLogo;
        _receiptNote = settings['receiptNote'] ?? _receiptNote;
        _lastSyncAt = settings['lastSyncAt'] != null
            ? DateTime.tryParse(settings['lastSyncAt'])
            : null;
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
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _receiptHeader,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Invoice: ${sale.id}'),
              pw.Text('Date: ${sale.createdAt.toLocal()}'),
              pw.Text('Customer: ${sale.customerName}'),
              pw.SizedBox(height: 12),
              ...lines.map(
                (line) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text('${line.product.name} x${line.qty}'),
                    ),
                    pw.Text(
                      '$_currency ${(line.product.price * line.qty).toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal'),
                  pw.Text('$_currency ${sale.subtotal.toStringAsFixed(2)}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Tax'),
                  pw.Text('$_currency ${sale.tax.toStringAsFixed(2)}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '$_currency ${sale.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Text(_receiptNote),
              pw.SizedBox(height: 8),
              pw.Text(_receiptFooter),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
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
    _ensureSyncService(state.user.tenantId);
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
              itemCount: _storeNavItems.length,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (context, index) {
                final item = _storeNavItems[index];
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
                'Owner',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _selectedPageTitle() {
    return _storeNavItems
        .firstWhere((item) => item.key == _selectedNavKey)
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
    final avgOrder = _sales.isEmpty ? 0 : totalRevenue / _sales.length;
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
                value: 'Rs ${totalRevenue.toStringAsFixed(2)}',
                icon: Icons.currency_rupee_rounded,
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
                value: 'Rs ${avgOrder.toStringAsFixed(2)}',
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
                                        trailing: Text(
                                          'Rs ${sale.total.toStringAsFixed(2)}',
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
                                    Text('Rs ${p.price.toStringAsFixed(2)}'),
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
                    ValueListenableBuilder<String>(
                      valueListenable: _paymentMethodController,
                      builder: (context, value, child) {
                        return DropdownButtonFormField<String>(
                          key: ValueKey<String>(value),
                          initialValue: value,
                          items: const [
                            DropdownMenuItem(
                              value: 'CASH',
                              child: Text('CASH'),
                            ),
                            DropdownMenuItem(
                              value: 'CARD',
                              child: Text('CARD'),
                            ),
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
                            if (v != null) _paymentMethodController.value = v;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Payment Method',
                            border: OutlineInputBorder(),
                          ),
                        );
                      },
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
                                  subtitle: Text(
                                    'Rs ${line.product.price.toStringAsFixed(2)}',
                                  ),
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
                      'Subtotal: Rs ${subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: cartItems.isEmpty
                            ? null
                            : () {
                                final sale = _SaleRecord(
                                  id: 'S${DateTime.now().millisecondsSinceEpoch}',
                                  customerName: _customers
                                      .firstWhere(
                                        (c) => c.id == _selectedCustomerId,
                                        orElse: () => _customers.first,
                                      )
                                      .name,
                                  paymentMethod: _paymentMethodController.value,
                                  subtotal: subtotal,
                                  tax: taxAmount,
                                  total: grandTotal,
                                  status: 'COMPLETED',
                                  createdAt: DateTime.now(),
                                );
                                setState(() {
                                  _sales.insert(0, sale);
                                  for (final line in cartItems) {
                                    line.product.stock -= line.qty;
                                  }
                                  _cart.clear();
                                  _enqueueSync('INSERT', 'sales', sale.id);
                                });
                                _printReceipt(sale: sale, lines: cartItems);
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
          p.id.toLowerCase().contains(q);
    }).toList();

    return _moduleCard(
      title: 'Product Management',
      action: ElevatedButton.icon(
        onPressed: () async {
          final item = await _showProductDialog();
          if (item == null) return;
          setState(() {
            _products.add(item);
            _enqueueSync('INSERT', 'products', item.id);
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
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
                    '${p.category} • Stock ${p.stock} • Min ${p.minStock}',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        onPressed: () async {
                          final edited = await _showProductDialog(existing: p);
                          if (edited == null) return;
                          setState(() {
                            final i = _products.indexWhere((x) => x.id == p.id);
                            _products[i] = edited;
                            _enqueueSync('UPDATE', 'products', edited.id);
                          });
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _products.removeWhere((x) => x.id == p.id);
                            _enqueueSync('DELETE', 'products', p.id);
                          });
                        },
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
    return _moduleCard(
      title: 'Sales Processing',
      action: OutlinedButton.icon(
        onPressed: () => setState(() {}),
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
      child: SizedBox(
        height: 520,
        child: _sales.isEmpty
            ? const Center(
                child: Text(
                  'No sales yet. Complete a POS checkout to generate sales.',
                ),
              )
            : ListView.builder(
                itemCount: _sales.length,
                itemBuilder: (context, index) {
                  final sale = _sales[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        '${sale.id} • Rs ${sale.total.toStringAsFixed(2)}',
                      ),
                      subtitle: Text(
                        '${sale.customerName} • ${sale.paymentMethod} • ${sale.createdAt.toLocal()}',
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
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            sale.status = v;
                            _enqueueSync('UPDATE', 'sales', sale.id);
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
        onPressed: () async {
          final customer = await _showCustomerDialog();
          if (customer == null) return;
          setState(() {
            _customers.add(customer);
            _enqueueSync('INSERT', 'customers', customer.id);
          });
        },
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
                      '${c.phone} • ${c.email.isEmpty ? 'No email' : c.email}',
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          onPressed: () async {
                            final edited = await _showCustomerDialog(
                              existing: c,
                            );
                            if (edited == null) return;
                            setState(() {
                              final i = _customers.indexWhere(
                                (x) => x.id == c.id,
                              );
                              _customers[i] = edited;
                              _enqueueSync('UPDATE', 'customers', edited.id);
                            });
                          },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _customers.removeWhere((x) => x.id == c.id);
                              _enqueueSync('DELETE', 'customers', c.id);
                            });
                          },
                          icon: const Icon(Icons.delete_outline),
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
        onPressed: () async {
          final po = await _showPurchaseOrderDialog();
          if (po == null) return;
          setState(() {
            _purchaseOrders.insert(0, po);
            _enqueueSync('INSERT', 'purchase_orders', po.id);
          });
        },
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
                          onPressed: () {
                            setState(() {
                              p.stock = (p.stock - 1).clamp(0, 1000000).toInt();
                              _enqueueSync('UPDATE', 'inventory', p.id);
                            });
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              p.stock += 1;
                              _enqueueSync('UPDATE', 'inventory', p.id);
                            });
                          },
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
                          'Items ${po.itemsCount} • Rs ${po.amount.toStringAsFixed(2)}',
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
        onPressed: () async {
          final employee = await _showEmployeeDialog();
          if (employee == null) return;
          setState(() {
            _employees.add(employee);
            _enqueueSync('INSERT', 'employees', employee.id);
          });
        },
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
                      onChanged: (v) {
                        setState(() {
                          e.active = v;
                          _enqueueSync('UPDATE', 'employees', e.id);
                        });
                      },
                    ),
                    IconButton(
                      onPressed: () async {
                        final edited = await _showEmployeeDialog(existing: e);
                        if (edited == null) return;
                        setState(() {
                          final i = _employees.indexWhere((x) => x.id == e.id);
                          _employees[i] = edited;
                          _enqueueSync('UPDATE', 'employees', edited.id);
                        });
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _employees.removeWhere((x) => x.id == e.id);
                          _enqueueSync('DELETE', 'employees', e.id);
                        });
                      },
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

  Widget _buildReportsPage() {
    final totalRevenue = _sales.fold<double>(0, (sum, s) => sum + s.total);
    final completed = _sales.where((s) => s.status == 'COMPLETED').length;
    final cancelled = _sales.where((s) => s.status == 'CANCELLED').length;
    final returned = _sales.where((s) => s.status == 'RETURNED').length;
    final lowStock = _products.where((p) => p.stock <= p.minStock).length;

    return _moduleCard(
      title: 'Reports & Analytics',
      action: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.download),
        label: const Text('Export'),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _statBox('Total Revenue', 'Rs ${totalRevenue.toStringAsFixed(2)}'),
          _statBox('Completed Sales', '$completed'),
          _statBox('Cancelled Sales', '$cancelled'),
          _statBox('Returned Sales', '$returned'),
          _statBox('Customers', '${_customers.length}'),
          _statBox('Low Stock Products', '$lowStock'),
        ],
      ),
    );
  }

  Widget _buildSettingsPage() {
    return _moduleCard(
      title: 'Settings',
      action: ElevatedButton.icon(
        onPressed: () async {
          _enqueueSync('UPDATE', 'settings', 'company_settings');
          await _persistWorkspaceData();
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Settings saved')));
        },
        icon: const Icon(Icons.save),
        label: const Text('Save'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
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
            initialValue: _taxRate,
            decoration: const InputDecoration(
              labelText: 'Tax Rate (%)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _taxRate = v,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _currency,
            decoration: const InputDecoration(
              labelText: 'Currency',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _currency = v,
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
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Receipt Editor',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _receiptHeader,
            decoration: const InputDecoration(
              labelText: 'Receipt Header',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _receiptHeader = v,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _receiptFooter,
            decoration: const InputDecoration(
              labelText: 'Receipt Footer',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _receiptFooter = v,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _receiptNote,
            decoration: const InputDecoration(
              labelText: 'Receipt Note',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _receiptNote = v,
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _printDemoReceipt,
                icon: const Icon(Icons.print),
                label: const Text('Print Demo Bill'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.preview),
                label: const Text('Refresh Preview'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: 360,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDE0EA)),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _receiptHeader,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                if (_receiptShowLogo)
                  const Text(
                    '[Logo]',
                    style: TextStyle(color: Color(0xFF6D7383)),
                  ),
                const Text('Demo Item A x1   Rs 1200.00'),
                const Text('Demo Item B x1   Rs 800.00'),
                const Divider(),
                const Text('Subtotal: Rs 2000.00'),
                Text(
                  'Tax: ${_receiptShowTax ? 'Enabled ($_taxRate%)' : 'Disabled'}',
                ),
                Text(
                  _receiptNote,
                  style: const TextStyle(color: Color(0xFF6D7383)),
                ),
                const SizedBox(height: 4),
                Text(_receiptFooter),
              ],
            ),
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
                      title: Text(
                        '${inv.id} • Rs ${inv.amount.toStringAsFixed(2)}',
                      ),
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
        onPressed: () {
          setState(() {
            _lastSyncAt = DateTime.now();
            _syncQueue.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Manual sync completed')),
          );
        },
        icon: const Icon(Icons.sync),
        label: const Text('Run Manual Sync'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last sync: ${_lastSyncAt?.toLocal().toString() ?? 'Never'}'),
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
                  ?action,
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
    final categoryController = TextEditingController(
      text: existing?.category ?? 'General',
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
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Product' : 'Edit Product'),
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
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
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
                category: categoryController.text.trim(),
                price: double.tryParse(priceController.text.trim()) ?? 0,
                stock: int.tryParse(stockController.text.trim()) ?? 0,
                minStock: int.tryParse(minStockController.text.trim()) ?? 0,
              );
              Navigator.pop(context, item);
            },
            child: const Text('Save'),
          ),
        ],
      ),
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
  double price;
  int stock;
  int minStock;

  _ProductItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.minStock,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
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
      price: (json['price'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      minStock: (json['minStock'] as num?)?.toInt() ?? 0,
    );
  }
}

class _CustomerItem {
  final String id;
  String name;
  String phone;
  String email;

  _CustomerItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'phone': phone, 'email': email};
  }

  factory _CustomerItem.fromJson(Map<String, dynamic> json) {
    return _CustomerItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
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
  final DateTime createdAt;

  _SaleRecord({
    required this.id,
    required this.customerName,
    required this.paymentMethod,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.status,
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
