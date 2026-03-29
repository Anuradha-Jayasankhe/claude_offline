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
      label: 'Owner Dashboard',
      icon: Icons.dashboard_rounded,
    ),
    _NavItem(
      key: 'pos',
      label: 'Point of Sale',
      icon: Icons.point_of_sale_rounded,
    ),
    _NavItem(
      key: 'products',
      label: 'Products',
      icon: Icons.inventory_2_rounded,
    ),
    _NavItem(
      key: 'categories',
      label: 'Categories',
      icon: Icons.category_outlined,
    ),
    _NavItem(key: 'sales', label: 'Sales', icon: Icons.receipt_long_rounded),
    _NavItem(key: 'customers', label: 'Customers', icon: Icons.groups_rounded),
    _NavItem(
      key: 'creditManagement',
      label: 'Credit Management',
      icon: Icons.credit_card_outlined,
    ),
    _NavItem(key: 'employees', label: 'Employees', icon: Icons.badge_rounded),
    _NavItem(
      key: 'attendance',
      label: 'Attendance',
      icon: Icons.watch_later_outlined,
    ),
    _NavItem(key: 'payroll', label: 'Payroll', icon: Icons.paid_outlined),
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
      key: 'jobCards',
      label: 'Job Cards',
      icon: Icons.assignment_rounded,
    ),
    _NavItem(
      key: 'warranties',
      label: 'Warranties',
      icon: Icons.verified_user_outlined,
    ),
    _NavItem(
      key: 'suppliers',
      label: 'Suppliers',
      icon: Icons.local_shipping_rounded,
    ),
    _NavItem(
      key: 'purchaseOrders',
      label: 'Purchase Orders',
      icon: Icons.assignment_outlined,
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
  final List<_AttendanceRecordItem> _attendanceRecords = [];
  final List<_PayrollRecordItem> _payrollRecords = [];
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
  String _profileName = 'Admin Owner';
  String _profileEmail = 'owner@store.local';
  String _profilePhone = '+94 77 123 4567';
  String _profileCurrentPassword = '';
  String _profileNewPassword = '';
  String _profileConfirmPassword = '';
  String _companyEmail = 'hello@storebuddy.local';
  String _companyPhone = '+94 11 555 0101';
  String _companyAddress = 'No. 12, Main Street, Colombo';
  String _companyRegNo = 'BR-54820';
  String _uiTheme = 'Light';
  String _uiLanguage = 'English';
  bool _prefSound = true;
  bool _prefAutoPrint = false;
  bool _prefCompact = false;
  bool _prefRequireSaleConfirmation = true;
  bool _notifyEmail = true;
  bool _notifySms = false;
  bool _notifyPayroll = true;
  String _payrollCycle = 'Monthly';
  String _payrollWorkingDays = '26';
  String _payrollOtRate = '1.5';
  String _payrollLatePenalty = '500';
  bool _payrollAutoGenerate = false;
  bool _payrollEnableEpf = true;
  String _selectedReportType = 'sales';
  String _settingsTab = 'general';
  final String _salesFilterStatus = 'ALL';
  String _salesFilterPayment = 'ALL';
  String _salesCashierFilter = 'All Cashiers';
  String _salesCustomerFilter = 'All Customers';
  String _salesItemsFilter = 'All Items';
  String _salesTimeFilter = 'All Time';
  String _dashboardPeriod = 'This Month';
  String _posCategoryFilter = 'All Categories';
  String _purchaseOrderStatusFilter = 'All Statuses';
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
  final TextEditingController _attendanceSearchController =
      TextEditingController();
  final TextEditingController _employeeSearchController =
      TextEditingController();
  final TextEditingController _usersSearchController = TextEditingController();
  final TextEditingController _productSearchController =
      TextEditingController();
  final TextEditingController _paymentMethodController =
      TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _tenantIdController = TextEditingController();
  final TextEditingController _storeEmailController = TextEditingController();
  final TextEditingController _storePasswordController =
      TextEditingController();
  final TextEditingController _posCouponController = TextEditingController();
  final TextEditingController _posGiftCardController = TextEditingController();
  final TextEditingController _posCustomerSearchController =
      TextEditingController();
  final TextEditingController _posCustomerNameController =
      TextEditingController();
  final TextEditingController _posCustomerPhoneController =
      TextEditingController();
  final TextEditingController _amountPaidController = TextEditingController();
  final TextEditingController _purchaseOrderSearchController =
      TextEditingController();
  final TextEditingController _serviceSearchController =
      TextEditingController();
  final TextEditingController _warrantySearchController =
      TextEditingController();
  String _jobCardStatusFilter = 'ALL';
  String _jobCardPriorityFilter = 'ALL';
  String _warrantyTabKey = 'warranties';
  DateTime _attendanceMonth = DateTime.now();
  String _usersRoleFilter = 'All Roles';
  String _usersStatusFilter = 'All Statuses';
  String _usersLocationFilter = 'All Locations';

  static const String _workspaceStateKey = 'workspace_state';

  @override
  void initState() {
    super.initState();
    _paymentMethodController.text = 'CASH';
    _loadPersistedWorkspaceData();
    _loadStoreLogins();
  }

  @override
  void dispose() {
    _salesSearchController.dispose();
    _customerSearchController.dispose();
    _attendanceSearchController.dispose();
    _employeeSearchController.dispose();
    _usersSearchController.dispose();
    _productSearchController.dispose();
    _paymentMethodController.dispose();
    _storeNameController.dispose();
    _tenantIdController.dispose();
    _storeEmailController.dispose();
    _storePasswordController.dispose();
    _posCouponController.dispose();
    _posGiftCardController.dispose();
    _posCustomerSearchController.dispose();
    _posCustomerNameController.dispose();
    _posCustomerPhoneController.dispose();
    _amountPaidController.dispose();
    _purchaseOrderSearchController.dispose();
    _serviceSearchController.dispose();
    _warrantySearchController.dispose();
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
      address: item.address.isEmpty ? null : item.address,
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
      address: c.address ?? '',
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
    _SettingsTabItem(key: 'profile', label: 'Profile', icon: Icons.person),
    _SettingsTabItem(key: 'general', label: 'General', icon: Icons.tune),
    _SettingsTabItem(key: 'company', label: 'Company', icon: Icons.business),
    _SettingsTabItem(
      key: 'receipt',
      label: 'Receipt Settings',
      icon: Icons.receipt_long,
    ),
    _SettingsTabItem(
      key: 'preferences',
      label: 'User Preferences',
      icon: Icons.palette_outlined,
    ),
    _SettingsTabItem(
      key: 'notifications',
      label: 'Notifications',
      icon: Icons.notifications,
    ),
    _SettingsTabItem(
      key: 'payroll',
      label: 'Payroll',
      icon: Icons.request_page_outlined,
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
    final created = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AddCategory',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        final nameController = TextEditingController();
        final descriptionController = TextEditingController();
        final attributeController = TextEditingController();
        final attributes = <String>[];

        return StatefulBuilder(
          builder: (context, setLocal) {
            return Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.white,
                child: SizedBox(
                  width: 760,
                  height: double.infinity,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE6E2EF)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Add New Category',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Category Name *'),
                                        const SizedBox(height: 6),
                                        TextField(controller: nameController),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Description'),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: descriptionController,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  const Text(
                                    'Category Attributes',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      final value = attributeController.text
                                          .trim();
                                      if (value.isEmpty) return;
                                      if (attributes.any(
                                        (x) =>
                                            x.toLowerCase() ==
                                            value.toLowerCase(),
                                      )) {
                                        return;
                                      }
                                      setLocal(() => attributes.add(value));
                                      attributeController.clear();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFB227D6),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Attribute'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: attributeController,
                                decoration: const InputDecoration(
                                  hintText: 'Attribute name (e.g. Color, Size)',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) {
                                  final value = attributeController.text.trim();
                                  if (value.isEmpty) return;
                                  if (attributes.any(
                                    (x) =>
                                        x.toLowerCase() == value.toLowerCase(),
                                  )) {
                                    return;
                                  }
                                  setLocal(() => attributes.add(value));
                                  attributeController.clear();
                                },
                              ),
                              const SizedBox(height: 14),
                              if (attributes.isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: attributes
                                      .map(
                                        (a) => Chip(
                                          label: Text(a),
                                          onDeleted: () => setLocal(
                                            () => attributes.remove(a),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8F4FB),
                          border: Border(
                            top: BorderSide(color: Color(0xFFE6E2EF)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Spacer(),
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                final name = nameController.text.trim();
                                if (name.isEmpty) return;
                                Navigator.pop(context, name);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB227D6),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Create Category'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(position: offset, child: child);
      },
    );

    if (created == null) return;
    final exists = _productCategories.any(
      (c) => c.toLowerCase() == created.toLowerCase(),
    );
    if (exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Category already exists')));
      return;
    }

    setState(() {
      _productCategories = {..._productCategories, created}.toList();
      _posCategoryFilter = created;
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
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SaleDetails',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.white,
            child: SizedBox(
              width: 520,
              height: double.infinity,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE6E2EF)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Sale Details',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _overviewRow('Receipt #', sale.id),
                          _overviewRow(
                            'Date & Time',
                            '${sale.createdAt.month}/${sale.createdAt.day}/${sale.createdAt.year}, ${sale.createdAt.hour.toString().padLeft(2, '0')}:${sale.createdAt.minute.toString().padLeft(2, '0')} ${sale.createdAt.hour >= 12 ? 'PM' : 'AM'}',
                          ),
                          _overviewRow(
                            'Cashier',
                            _users.isNotEmpty ? _users.first.name : 'Cashier',
                          ),
                          _overviewRow(
                            'Customer',
                            sale.customerName.isEmpty
                                ? 'Walk-in'
                                : sale.customerName,
                          ),
                          _overviewRow('Payment', sale.paymentMethod),
                          _overviewRow('Status', sale.status),
                          const Divider(height: 24),
                          _overviewRow('Subtotal', _money(sale.subtotal)),
                          _overviewRow('Tax', _money(sale.tax)),
                          _overviewRow('Total', _money(sale.total)),
                          if (sale.returnReason != null &&
                              sale.returnReason!.isNotEmpty) ...[
                            const Divider(height: 24),
                            const Text(
                              'Return Reason',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(sale.returnReason!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFE6E2EF))),
                    ),
                    child: Row(
                      children: [
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(position: offset, child: child);
      },
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
      'attendanceRecords': _attendanceRecords.map((e) => e.toJson()).toList(),
      'payrollRecords': _payrollRecords.map((e) => e.toJson()).toList(),
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
        'profileName': _profileName,
        'profileEmail': _profileEmail,
        'profilePhone': _profilePhone,
        'companyEmail': _companyEmail,
        'companyPhone': _companyPhone,
        'companyAddress': _companyAddress,
        'companyRegNo': _companyRegNo,
        'uiTheme': _uiTheme,
        'uiLanguage': _uiLanguage,
        'prefSound': _prefSound,
        'prefAutoPrint': _prefAutoPrint,
        'prefCompact': _prefCompact,
        'prefRequireSaleConfirmation': _prefRequireSaleConfirmation,
        'notifyEmail': _notifyEmail,
        'notifySms': _notifySms,
        'notifyPayroll': _notifyPayroll,
        'payrollCycle': _payrollCycle,
        'payrollWorkingDays': _payrollWorkingDays,
        'payrollOtRate': _payrollOtRate,
        'payrollLatePenalty': _payrollLatePenalty,
        'payrollAutoGenerate': _payrollAutoGenerate,
        'payrollEnableEpf': _payrollEnableEpf,
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
      final attendanceList =
          (decoded['attendanceRecords'] as List<dynamic>? ?? [])
              .map(
                (e) => _AttendanceRecordItem.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList();
      final payrollList = (decoded['payrollRecords'] as List<dynamic>? ?? [])
          .map((e) => _PayrollRecordItem.fromJson(Map<String, dynamic>.from(e)))
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
        _attendanceRecords
          ..clear()
          ..addAll(attendanceList);
        _payrollRecords
          ..clear()
          ..addAll(payrollList);
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
        _profileName = settings['profileName'] ?? _profileName;
        _profileEmail = settings['profileEmail'] ?? _profileEmail;
        _profilePhone = settings['profilePhone'] ?? _profilePhone;
        _companyEmail = settings['companyEmail'] ?? _companyEmail;
        _companyPhone = settings['companyPhone'] ?? _companyPhone;
        _companyAddress = settings['companyAddress'] ?? _companyAddress;
        _companyRegNo = settings['companyRegNo'] ?? _companyRegNo;
        _uiTheme = settings['uiTheme'] ?? _uiTheme;
        _uiLanguage = settings['uiLanguage'] ?? _uiLanguage;
        _prefSound = settings['prefSound'] ?? _prefSound;
        _prefAutoPrint = settings['prefAutoPrint'] ?? _prefAutoPrint;
        _prefCompact = settings['prefCompact'] ?? _prefCompact;
        _prefRequireSaleConfirmation =
            settings['prefRequireSaleConfirmation'] ??
            _prefRequireSaleConfirmation;
        _notifyEmail = settings['notifyEmail'] ?? _notifyEmail;
        _notifySms = settings['notifySms'] ?? _notifySms;
        _notifyPayroll = settings['notifyPayroll'] ?? _notifyPayroll;
        _payrollCycle = settings['payrollCycle'] ?? _payrollCycle;
        _payrollWorkingDays =
            settings['payrollWorkingDays'] ?? _payrollWorkingDays;
        _payrollOtRate = settings['payrollOtRate'] ?? _payrollOtRate;
        _payrollLatePenalty =
            settings['payrollLatePenalty'] ?? _payrollLatePenalty;
        _payrollAutoGenerate =
            settings['payrollAutoGenerate'] ?? _payrollAutoGenerate;
        _payrollEnableEpf = settings['payrollEnableEpf'] ?? _payrollEnableEpf;
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
          String money(double v) => v.toStringAsFixed(2);

          pw.Widget rowLine(String label, String value, {bool bold = false}) {
            return pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    label,
                    style: pw.TextStyle(
                      fontSize: 11 * fontScale,
                      fontWeight: bold
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                ),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 11 * fontScale,
                    fontWeight: bold
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                  ),
                ),
              ],
            );
          }

          final cashierName = _users.isNotEmpty ? _users.first.name : 'Cashier';
          final amountPaid =
              double.tryParse(_amountPaidController.text.trim()) ?? sale.total;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  _companyName,
                  style: pw.TextStyle(
                    fontSize: 14 * fontScale,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  '123 Business Street, City, State 12345',
                  style: pw.TextStyle(fontSize: 9.5 * fontScale),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  '+1 (555) 123-4567',
                  style: pw.TextStyle(fontSize: 9.5 * fontScale),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Center(
                child: pw.Text(
                  'CUSTOMER RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 12 * fontScale,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              rowLine('Receipt # ::', sale.id),
              rowLine(
                'Date::',
                '${sale.createdAt.month}/${sale.createdAt.day}/${sale.createdAt.year}, ${sale.createdAt.hour.toString().padLeft(2, '0')}:${sale.createdAt.minute.toString().padLeft(2, '0')}:${sale.createdAt.second.toString().padLeft(2, '0')}',
              ),
              rowLine('Cashier::', cashierName),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Center(
                child: pw.Text(
                  'ITEMS PURCHASED',
                  style: pw.TextStyle(
                    fontSize: 11 * fontScale,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  'PRODUCTS',
                  style: pw.TextStyle(
                    fontSize: 10 * fontScale,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              ...lines.map(
                (line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        line.product.name,
                        style: pw.TextStyle(
                          fontSize: 11 * fontScale,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'SKU: ${line.product.id.toLowerCase()}',
                        style: pw.TextStyle(fontSize: 10 * fontScale),
                      ),
                      rowLine(
                        '${line.qty} x $_currency ${money(line.product.price)}',
                        '\$${money(line.product.price * line.qty)}',
                      ),
                    ],
                  ),
                ),
              ),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              rowLine('Subtotal:', '\$${money(sale.subtotal)}'),
              rowLine('TOTAL:', '\$${money(sale.total)}', bold: true),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              rowLine('Payment Method:', sale.paymentMethod),
              rowLine('Amount Paid:', '\$${money(amountPaid)}'),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(fontSize: 10 * fontScale),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Please keep this receipt for your records',
                  style: pw.TextStyle(fontSize: 9.5 * fontScale),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Return Policy: 30 days with receipt',
                  style: pw.TextStyle(fontSize: 9.5 * fontScale),
                ),
              ),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Center(
                child: pw.Text(
                  'Store Buddy POS',
                  style: pw.TextStyle(fontSize: 10 * fontScale),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Call 0662223968 for more info',
                  style: pw.TextStyle(fontSize: 9.5 * fontScale),
                ),
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
      decoration: const BoxDecoration(
        color: Color(0xFFF8F8FC),
        border: Border(right: BorderSide(color: Color(0xFFE8E5F4))),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            decoration: const BoxDecoration(
              color: Color(0xFFB227D6),
              border: Border(bottom: BorderSide(color: Color(0xFFE8E5F4))),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF6F0FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'S',
                      style: TextStyle(
                        color: Color(0xFF7A1EA4),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Store Buddy',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                        ? const Color(0xFFF1E4FA)
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
                              size: 18,
                              color: selected
                                  ? const Color(0xFFB227D6)
                                  : const Color(0xFF646B7C),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  color: selected
                                      ? const Color(0xFF7A1EA4)
                                      : const Color(0xFF2A3042),
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
          const Divider(height: 1, color: Color(0xFFE8E5F4)),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Material(
              color: const Color(0xFFF3F4F9),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () =>
                    context.read<AuthBloc>().add(AuthLogoutRequested()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFFB227D6),
                        child: Text(
                          state.user.name.isNotEmpty
                              ? state.user.name[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2A3042),
                              ),
                            ),
                            Text(
                              state.user.role.toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF7E8495),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: Color(0xFFE35D5D),
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
      height: 68,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      child: Row(
        children: [
          Text(
            'Welcome back, ${state.user.name.isEmpty ? 'User' : state.user.name} !',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF60667A),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD6D9E4)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.translate_rounded,
                  size: 16,
                  color: Color(0xFF60667A),
                ),
                SizedBox(width: 6),
                Text('English', style: TextStyle(color: Color(0xFF2A3042))),
                SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Color(0xFF60667A),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.dark_mode_outlined,
              color: Color(0xFF60667A),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFB227D6),
            child: Text(
              state.user.name.isNotEmpty
                  ? state.user.name.substring(0, 2).toUpperCase()
                  : 'US',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
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
      case 'categories':
        return _buildCategoriesPage();
      case 'sales':
        return _buildSalesPage();
      case 'customers':
        return _buildCustomersPage();
      case 'creditManagement':
        return _buildCreditManagementPage();
      case 'employees':
        return _buildEmployeesPage();
      case 'attendance':
        return _buildAttendancePage();
      case 'payroll':
        return _buildPayrollPage();
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
      case 'jobCards':
        return _buildJobCardsPage();
      case 'warranties':
        return _buildWarrantiesPage();
      case 'suppliers':
        return _buildSuppliersPage();
      case 'purchaseOrders':
        return _buildPurchaseOrdersPage();
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
    final activeEmployees = _employees.where((e) => e.active).length;
    final inventoryValue = _products.fold<double>(
      0,
      (sum, p) => sum + (p.price * p.stock),
    );
    final productRevenue = _sales.fold<double>(
      0,
      (sum, s) => sum + (s.paymentMethod == 'SERVICE' ? 0 : s.total),
    );
    final serviceRevenue = _sales.fold<double>(
      0,
      (sum, s) => sum + (s.paymentMethod == 'SERVICE' ? s.total : 0),
    );
    final profitMargin = totalRevenue == 0
        ? 0
        : ((totalRevenue - inventoryValue.clamp(0, totalRevenue)) /
                  totalRevenue) *
              100;
    final categorySummary =
        _products
            .fold<Map<String, int>>({}, (map, p) {
              map[p.category] = (map[p.category] ?? 0) + 1;
              return map;
            })
            .entries
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final topSeller = _sales.isEmpty ? null : _sales.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ABC Business',
                  style: TextStyle(fontSize: 46, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFB227D6), width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _dashboardPeriod,
                    items: const [
                      DropdownMenuItem(
                        value: 'This Week',
                        child: Text('This Week'),
                      ),
                      DropdownMenuItem(
                        value: 'This Month',
                        child: Text('This Month'),
                      ),
                      DropdownMenuItem(
                        value: 'This Quarter',
                        child: Text('This Quarter'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _dashboardPeriod = v);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Complete business overview and management tools.',
            style: TextStyle(color: Color(0xFF6D7383), fontSize: 22),
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
                subtitle: 'All time sales',
                deltaText: '+0.0%',
                deltaHint: 'vs last period',
                deltaColor: const Color(0xFF1FA35B),
              ),
              _MetricCard(
                title: 'Product Revenue',
                value: _money(productRevenue),
                icon: Icons.shopping_bag_outlined,
                subtitle: 'From products',
                deltaText: '+0.0%',
                deltaHint: 'vs last period',
                deltaColor: const Color(0xFF1FA35B),
              ),
              _MetricCard(
                title: 'Service Revenue',
                value: _money(serviceRevenue),
                icon: Icons.settings_suggest_outlined,
                subtitle: 'From services',
                deltaText: serviceRevenue.isNaN ? '+NaN%' : '+0.0%',
                deltaHint: 'vs last period',
                deltaColor: const Color(0xFF1FA35B),
              ),
              _MetricCard(
                title: 'Profit Margin',
                value: '${profitMargin.toStringAsFixed(1)}%',
                icon: Icons.bar_chart_rounded,
                subtitle: 'After product costs',
                deltaText: profitMargin >= 25
                    ? '+Excellent'
                    : 'Needs attention',
                deltaHint: 'vs last period',
                deltaColor: profitMargin >= 25
                    ? const Color(0xFF1FA35B)
                    : const Color(0xFFE35D5D),
              ),
              _MetricCard(
                title: 'Employee Cost',
                value: _money(0),
                icon: Icons.groups_2_outlined,
                subtitle: '$activeEmployees active employees',
                deltaText: '+${_money(0)}',
                deltaHint: 'vs last period',
                deltaColor: const Color(0xFF1FA35B),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Business Alerts (${lowStock > 0 ? 1 : 0})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFCB7E3D),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFAF2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF5E0C6)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Low Stock Alert',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '$lowStock products are running low on stock',
                                style: const TextStyle(
                                  color: Color(0xFF7E8495),
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () =>
                              setState(() => _selectedNavKey = 'products'),
                          child: const Text('Manage Products'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sales Overview',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _overviewRow('Today', _money(totalRevenue)),
                        _overviewRow('This Week', _money(totalRevenue)),
                        _overviewRow('This Month', _money(totalRevenue)),
                        const Divider(height: 22),
                        _overviewRow('Avg Transaction', _money(avgOrder)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Status',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _overviewRow('Total Invoices', '${_invoices.length}'),
                        _overviewRow('Pending Payments', '0'),
                        _overviewRow(
                          'Overdue Payments',
                          '0',
                          valueColor: const Color(0xFF1FA35B),
                        ),
                        const Divider(height: 22),
                        _overviewRow('Pending Amount', _money(0)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inventory Overview',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _overviewRow('Total Products', '${_products.length}'),
                        _overviewRow(
                          'Low Stock',
                          '$lowStock',
                          valueColor: lowStock > 0
                              ? const Color(0xFFE35D5D)
                              : const Color(0xFF1FA35B),
                        ),
                        _overviewRow('Inventory Value', _money(inventoryValue)),
                        const Divider(height: 22),
                        _overviewRow(
                          'Categories',
                          categorySummary.isEmpty
                              ? '-'
                              : categorySummary.first.key,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Team Performance',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4CC),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '1',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    topSeller?.customerName ??
                                        (_users.isNotEmpty
                                            ? _users.first.name
                                            : 'Team Member'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${_sales.length} sales',
                                    style: const TextStyle(
                                      color: Color(0xFF7E8495),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _money(topSeller?.total ?? totalRevenue),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(flex: 2, child: SizedBox()),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Management Actions',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _quickActionTile(
                          icon: Icons.bar_chart_rounded,
                          label: 'Sales Report',
                          onTap: () =>
                              setState(() => _selectedNavKey = 'reports'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _quickActionTile(
                          icon: Icons.groups_rounded,
                          label: 'Employees',
                          onTap: () =>
                              setState(() => _selectedNavKey = 'employees'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _quickActionTile(
                          icon: Icons.inventory_2_outlined,
                          label: 'Products',
                          onTap: () =>
                              setState(() => _selectedNavKey = 'products'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _quickActionTile(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Payroll',
                          onTap: () =>
                              setState(() => _selectedNavKey = 'payroll'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _quickActionTile(
                          icon: Icons.manage_accounts_rounded,
                          label: 'Users',
                          onTap: () =>
                              setState(() => _selectedNavKey = 'users'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _quickActionTile(
                          icon: Icons.refresh_rounded,
                          label: 'Refresh',
                          onTap: () => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF646B7C), fontSize: 16),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF2A3042),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        foregroundColor: const Color(0xFF4A5164),
        side: const BorderSide(color: Color(0xFFD7DBE8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 6),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildPosPage() {
    final filteredProducts = _products.where((p) {
      final q = _productSearchController.text.trim().toLowerCase();
      final matchCategory =
          _posCategoryFilter == 'All Categories' ||
          p.category == _posCategoryFilter;
      if (!matchCategory) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q) ||
          p.barcode.toLowerCase().contains(q);
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
    final paymentMethod = _paymentMethodController.text.isEmpty
        ? 'CASH'
        : _paymentMethodController.text;
    final posCategories = ['All Categories', ..._productCategories];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Point of Sale',
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          const Text(
            'Process sales transactions quickly and efficiently.',
            style: TextStyle(color: Color(0xFF6D7383), fontSize: 16),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE4E1EF)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _productSearchController,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText:
                                      'Search products or scan barcode...',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2E9C64),
                                side: const BorderSide(
                                  color: Color(0xFFBFE6CF),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.qr_code_scanner, size: 16),
                              label: const Text('Scanner Active'),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFD7DCE8),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _posCategoryFilter,
                                  items: posCategories
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(c),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() => _posCategoryFilter = v);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedNavKey = 'services'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9D35DA),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.build, size: 16),
                              label: const Text('Add Service'),
                            ),
                          ],
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
                                childAspectRatio: 2.0,
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
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(
                                    color: Color(0xFFE6E2EF),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'SKU: ${p.id.toLowerCase()}',
                                        style: const TextStyle(
                                          color: Color(0xFF7E8495),
                                        ),
                                      ),
                                      const Spacer(),
                                      Row(
                                        children: [
                                          Text(
                                            _money(p.price),
                                            style: const TextStyle(
                                              color: Color(0xFFB227D6),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: p.stock <= p.minStock
                                                  ? const Color(0xFFFFEAEA)
                                                  : const Color(0xFFE8F7EC),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Stock: ${p.stock}',
                                              style: TextStyle(
                                                color: p.stock <= p.minStock
                                                    ? const Color(0xFFE35D5D)
                                                    : const Color(0xFF2E9C64),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
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
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE6E2EF)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shopping Cart (${cartItems.length})',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: cartItems.isEmpty
                                ? const Text(
                                    'Cart is empty',
                                    style: TextStyle(color: Color(0xFF7E8495)),
                                  )
                                : Column(
                                    children: cartItems.map((line) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 5,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    line.product.name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${_money(line.product.price)} each',
                                                    style: const TextStyle(
                                                      color: Color(0xFF7E8495),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  final next = line.qty - 1;
                                                  if (next <= 0) {
                                                    _cart.remove(
                                                      line.product.id,
                                                    );
                                                  } else {
                                                    _cart[line.product.id] =
                                                        next;
                                                  }
                                                });
                                              },
                                              icon: const Icon(
                                                Icons.remove,
                                                size: 18,
                                              ),
                                            ),
                                            Text(
                                              '${line.qty}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  if (line.qty <
                                                      line.product.stock) {
                                                    _cart[line.product.id] =
                                                        line.qty + 1;
                                                  }
                                                });
                                              },
                                              icon: const Icon(
                                                Icons.add,
                                                size: 18,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  _cart.remove(line.product.id);
                                                });
                                              },
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: Color(0xFFE35D5D),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 72,
                                              child: Text(
                                                _money(
                                                  line.product.price * line.qty,
                                                ),
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                          const Divider(height: 20),
                          _overviewRow('Subtotal:', _money(subtotal)),
                          _overviewRow(
                            'Tax (${taxRate.toStringAsFixed(1)}%):',
                            _money(taxAmount),
                          ),
                          const Divider(height: 20),
                          _overviewRow('Total::', _money(grandTotal)),
                          const Divider(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _posCouponController,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter coupon code',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 40,
                                child: ElevatedButton(
                                  onPressed: () {},
                                  child: const Text('Apply'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _posGiftCardController,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter gift card code',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 40,
                                child: ElevatedButton(
                                  onPressed: () {},
                                  child: const Text('Apply'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Customer (Optional)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _posCustomerSearchController,
                            decoration: const InputDecoration(
                              hintText:
                                  'Search customer by name, vehicle number...',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _posCustomerNameController,
                            decoration: const InputDecoration(
                              hintText: 'Customer Name (Optional)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _posCustomerPhoneController,
                            decoration: const InputDecoration(
                              hintText: 'Phone Number (Optional)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Payment Method',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _posPaymentButton('CASH', 'Cash', paymentMethod),
                              const SizedBox(width: 8),
                              _posPaymentButton('CARD', 'Card', paymentMethod),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _posPaymentButton(
                                'CHEQUE',
                                'Cheque',
                                paymentMethod,
                              ),
                              const SizedBox(width: 8),
                              _posPaymentButton(
                                'INSTALLMENT',
                                'Installment',
                                paymentMethod,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Amount Paid',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _amountPaidController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: cartItems.isEmpty
                                  ? null
                                  : () async {
                                      final selectedCustomer = _customers
                                          .firstWhere(
                                            (c) => c.id == _selectedCustomerId,
                                            orElse: () => _customers.first,
                                          );
                                      final enteredName =
                                          _posCustomerNameController.text
                                              .trim();
                                      final customerName = enteredName.isEmpty
                                          ? selectedCustomer.name
                                          : enteredName;
                                      final sale = _SaleRecord(
                                        id: 'S${DateTime.now().millisecondsSinceEpoch}',
                                        customerName: customerName,
                                        paymentMethod: paymentMethod,
                                        subtotal: subtotal,
                                        tax: taxAmount,
                                        total: grandTotal,
                                        status: 'COMPLETED',
                                        createdAt: DateTime.now(),
                                      );
                                      setState(() {
                                        selectedCustomer.loyaltyPoints +=
                                            _loyaltyPointsForAmount(grandTotal);
                                        if (paymentMethod == 'INSTALLMENT') {
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

                                      await _printReceipt(
                                        sale: sale,
                                        lines: cartItems,
                                      );
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Sale completed: ${sale.id}',
                                          ),
                                        ),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC980D9),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                'Complete Sale',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _posPaymentButton(String key, String label, String selected) {
    final isSelected = key == selected;
    return Expanded(
      child: OutlinedButton(
        onPressed: () => setState(() => _paymentMethodController.text = key),
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected
              ? const Color(0xFFF4DDF8)
              : const Color(0xFFF2ECFA),
          foregroundColor: const Color(0xFF6B3E8F),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFFB227D6)
                : const Color(0xFFE4DDF1),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
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

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Products',
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          const Text(
            'Manage your inventory and product catalog.',
            style: TextStyle(color: Color(0xFF6D7383), fontSize: 16),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE4E1EF)),
            ),
            child: TextField(
              controller: _productSearchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE6E2EF)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Products (${filtered.length})',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _canManageCatalog
                              ? () => setState(
                                  () => _selectedNavKey = 'categories',
                                )
                              : null,
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
                                      (c) =>
                                          c.toLowerCase() ==
                                          item.category.toLowerCase(),
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
                                    await _enqueueSync(
                                      'INSERT',
                                      'products',
                                      item.id,
                                    );
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB227D6),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Add New Product'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF5F2FB),
                          ),
                          columnSpacing: 22,
                          columns: const [
                            DataColumn(label: Text('PRODUCT')),
                            DataColumn(label: Text('SKU')),
                            DataColumn(label: Text('TYPE')),
                            DataColumn(label: Text('CATEGORY')),
                            DataColumn(label: Text('PRICE')),
                            DataColumn(label: Text('ACTIONS')),
                          ],
                          rows: filtered.map((p) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        p.barcode,
                                        style: const TextStyle(
                                          color: Color(0xFF7E8495),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(p.id)),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3E8FA),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text('Unit'),
                                  ),
                                ),
                                DataCell(Text(p.category)),
                                DataCell(Text(_money(p.price))),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            _printProductBarcode(p),
                                        icon: const Icon(
                                          Icons.qr_code_2_outlined,
                                        ),
                                        tooltip: 'Print Barcode Label',
                                      ),
                                      IconButton(
                                        onPressed: _canManageCatalog
                                            ? () async {
                                                final edited =
                                                    await _showProductDialog(
                                                      existing: p,
                                                    );
                                                if (edited == null) return;
                                                setState(() {
                                                  final i = _products
                                                      .indexWhere(
                                                        (x) => x.id == p.id,
                                                      );
                                                  _products[i] = edited;
                                                  if (!_productCategories.any(
                                                    (c) =>
                                                        c.toLowerCase() ==
                                                        edited.category
                                                            .toLowerCase(),
                                                  )) {
                                                    _productCategories.add(
                                                      edited.category,
                                                    );
                                                  }
                                                });
                                                await _persistWorkspaceData();

                                                if (_productRepository !=
                                                    null) {
                                                  await _productRepository!
                                                      .updateProduct(
                                                        _toDomainProduct(
                                                          edited,
                                                        ),
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
                                                  _products.removeWhere(
                                                    (x) => x.id == p.id,
                                                  );
                                                });
                                                await _persistWorkspaceData();

                                                if (_productRepository !=
                                                    null) {
                                                  await _productRepository!
                                                      .deleteProduct(p.id);
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
                                ),
                              ],
                            );
                          }).toList(),
                        ),
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

    final totalRevenue = filtered.fold<double>(0, (sum, s) => sum + s.total);
    final productRevenue = filtered.fold<double>(
      0,
      (sum, s) => sum + (s.paymentMethod == 'SERVICE' ? 0 : s.total),
    );
    final serviceRevenue = filtered.fold<double>(
      0,
      (sum, s) => sum + (s.paymentMethod == 'SERVICE' ? s.total : 0),
    );
    final avgOrder = filtered.isEmpty ? 0.0 : totalRevenue / filtered.length;
    final itemCount = filtered.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales Management',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'View and analyze sales transactions.',
                      style: TextStyle(color: Color(0xFF6D7383), fontSize: 16),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportSalesCsv(filtered),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Export Data'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 220,
                        child: _salesSummaryCard(
                          'Total Sales',
                          '${filtered.length}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 240,
                        child: _salesSummaryCard(
                          'Total Revenue',
                          _money(totalRevenue),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 250,
                        child: _salesSummaryCard(
                          'Product Revenue',
                          _money(productRevenue),
                          subtitle: '$itemCount items sold',
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 250,
                        child: _salesSummaryCard(
                          'Service Revenue',
                          _money(serviceRevenue),
                          subtitle:
                              '${filtered.where((s) => s.paymentMethod == 'SERVICE').length} services',
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 230,
                        child: _salesSummaryCard(
                          'Avg Order Value',
                          _money(avgOrder),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE6E2EF)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                    width: 360,
                    child: TextField(
                      controller: _salesSearchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search sales, customers...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 170,
                    child: _salesFilterDropdown(
                      value: _salesCashierFilter,
                      items: const ['All Cashiers'],
                      onChanged: (v) => setState(() => _salesCashierFilter = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 180,
                    child: _salesFilterDropdown(
                      value: _salesCustomerFilter,
                      items: const ['All Customers'],
                      onChanged: (v) =>
                          setState(() => _salesCustomerFilter = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 200,
                    child: _salesFilterDropdown(
                      value: _salesFilterPayment,
                      items: const [
                        'ALL',
                        'CASH',
                        'CARD',
                        'CHEQUE',
                        'INSTALLMENT',
                        'SERVICE',
                      ],
                      onChanged: (v) => setState(() => _salesFilterPayment = v),
                      labelMapper: (v) =>
                          v == 'ALL' ? 'All Payment Methods' : v,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 160,
                    child: _salesFilterDropdown(
                      value: _salesItemsFilter,
                      items: const ['All Items'],
                      onChanged: (v) => setState(() => _salesItemsFilter = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 160,
                    child: _salesFilterDropdown(
                      value: _salesTimeFilter,
                      items: const [
                        'All Time',
                        'Today',
                        'This Week',
                        'This Month',
                      ],
                      onChanged: (v) => setState(() => _salesTimeFilter = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE6E2EF)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales Records (${filtered.length})',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No sales records found for selected filters.',
                              ),
                            )
                          : SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF5F2FB),
                                ),
                                columns: const [
                                  DataColumn(label: Text('RECEIPT #')),
                                  DataColumn(label: Text('DATE & TIME')),
                                  DataColumn(label: Text('CASHIER')),
                                  DataColumn(label: Text('CUSTOMER')),
                                  DataColumn(label: Text('ITEMS')),
                                  DataColumn(label: Text('TOTAL')),
                                  DataColumn(label: Text('PAYMENT')),
                                  DataColumn(label: Text('ACTIONS')),
                                ],
                                rows: filtered.map((sale) {
                                  return DataRow(
                                    onSelectChanged: (_) =>
                                        _showSaleDetails(sale),
                                    cells: [
                                      DataCell(Text(sale.id)),
                                      DataCell(
                                        Text(
                                          '${sale.createdAt.month}/${sale.createdAt.day}/${sale.createdAt.year}, ${sale.createdAt.hour.toString().padLeft(2, '0')}:${sale.createdAt.minute.toString().padLeft(2, '0')} ${sale.createdAt.hour >= 12 ? 'PM' : 'AM'}',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _users.isNotEmpty
                                              ? _users.first.name
                                              : 'Cashier',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          sale.customerName.isEmpty
                                              ? 'Walk-in'
                                              : sale.customerName,
                                        ),
                                      ),
                                      DataCell(const Text('1 Items')),
                                      DataCell(Text(_money(sale.total))),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8F7EC),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            sale.paymentMethod.toLowerCase(),
                                            style: const TextStyle(
                                              color: Color(0xFF2E9C64),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        IconButton(
                                          onPressed: () =>
                                              _showSaleDetails(sale),
                                          icon: const Icon(
                                            Icons.visibility_outlined,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
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

  Widget _salesSummaryCard(String title, String value, {String subtitle = ''}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE6E2EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Color(0xFF6D7383))),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Color(0xFF8A90A2))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _salesFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    String Function(String)? labelMapper,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(labelMapper == null ? item : labelMapper(item)),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        onChanged(v);
      },
      decoration: const InputDecoration(border: OutlineInputBorder()),
    );
  }

  Widget _buildCustomersPage() {
    final query = _customerSearchController.text.trim().toLowerCase();
    final filtered = _customers.where((c) {
      if (query.isEmpty) return true;
      return c.name.toLowerCase().contains(query) ||
          c.vehicleNumber.toLowerCase().contains(query) ||
          c.phone.toLowerCase().contains(query) ||
          c.email.toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Management',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage customer information and vehicle details.',
                      style: TextStyle(color: Color(0xFF6D7383), fontSize: 16),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _canManageCatalog
                    ? () async {
                        final customer = await _showCustomerDialog();
                        if (customer == null) return;
                        setState(() => _customers.add(customer));
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
                          await _enqueueSync(
                            'INSERT',
                            'customers',
                            customer.id,
                          );
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB227D6),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Customer'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE6E2EF)),
            ),
            child: TextField(
              controller: _customerSearchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText:
                    'Search customers by name, vehicle number, or phone...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE6E2EF)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.groups_outlined),
                        const SizedBox(width: 8),
                        Text(
                          'Customers (${filtered.length})',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.groups_outlined,
                                    size: 56,
                                    color: Color(0xFFB7A9D0),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No customers found. Add your first customer to get started.',
                                    style: TextStyle(
                                      color: Color(0xFF6F7690),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF5F2FB),
                                ),
                                columns: const [
                                  DataColumn(label: Text('CUSTOMER')),
                                  DataColumn(label: Text('VEHICLE NO')),
                                  DataColumn(label: Text('PHONE')),
                                  DataColumn(label: Text('EMAIL')),
                                  DataColumn(label: Text('CREDIT LIMIT')),
                                  DataColumn(label: Text('ACTIONS')),
                                ],
                                rows: filtered.map((c) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(c.name)),
                                      DataCell(
                                        Text(
                                          c.vehicleNumber.isEmpty
                                              ? 'N/A'
                                              : c.vehicleNumber,
                                        ),
                                      ),
                                      DataCell(Text(c.phone)),
                                      DataCell(
                                        Text(c.email.isEmpty ? 'N/A' : c.email),
                                      ),
                                      DataCell(Text(_money(c.creditLimit))),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              onPressed: _canManageCatalog
                                                  ? () async {
                                                      final edited =
                                                          await _showCustomerDialog(
                                                            existing: c,
                                                          );
                                                      if (edited == null)
                                                        return;
                                                      setState(() {
                                                        final i = _customers
                                                            .indexWhere(
                                                              (x) =>
                                                                  x.id == c.id,
                                                            );
                                                        _customers[i] = edited;
                                                      });
                                                      await _persistWorkspaceData();

                                                      if (_customerRepository !=
                                                          null) {
                                                        await _customerRepository!
                                                            .updateCustomer(
                                                              _toDomainCustomer(
                                                                edited,
                                                              ),
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
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: _canManageCatalog
                                                  ? () async {
                                                      setState(() {
                                                        _customers.removeWhere(
                                                          (x) => x.id == c.id,
                                                        );
                                                        _customerCreditPayments
                                                            .remove(c.id);
                                                      });
                                                      await _persistWorkspaceData();

                                                      if (_customerRepository !=
                                                          null) {
                                                        await _customerRepository!
                                                            .deleteCustomer(
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
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
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
    final query = _employeeSearchController.text.trim().toLowerCase();
    final filtered = _employees.where((e) {
      if (query.isEmpty) return true;
      return e.name.toLowerCase().contains(query) ||
          e.email.toLowerCase().contains(query) ||
          e.phone.toLowerCase().contains(query) ||
          e.position.toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Employees',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage your employee records and information.',
                      style: TextStyle(color: Color(0xFF6D7383), fontSize: 16),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _canManageEmployees
                    ? () async {
                        final employee = await _showEmployeeDialog();
                        if (employee == null) return;
                        setState(() => _employees.add(employee));
                        await _persistWorkspaceData();
                        await _enqueueSync('INSERT', 'employees', employee.id);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB227D6),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Employee'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE6E2EF)),
            ),
            child: TextField(
              controller: _employeeSearchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search employees...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE6E2EF)),
              ),
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No employees found matching your criteria.',
                        style: TextStyle(
                          color: Color(0xFF7A8093),
                          fontSize: 20,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFF5F2FB),
                        ),
                        columns: const [
                          DataColumn(label: Text('EMPLOYEE')),
                          DataColumn(label: Text('EMAIL')),
                          DataColumn(label: Text('POSITION')),
                          DataColumn(label: Text('DEPARTMENT')),
                          DataColumn(label: Text('PAYMENT TYPE')),
                          DataColumn(label: Text('SALARY')),
                          DataColumn(label: Text('STATUS')),
                          DataColumn(label: Text('ACTIONS')),
                        ],
                        rows: filtered.map((e) {
                          return DataRow(
                            cells: [
                              DataCell(Text(e.name)),
                              DataCell(Text(e.email.isEmpty ? 'N/A' : e.email)),
                              DataCell(
                                Text(e.position.isEmpty ? e.role : e.position),
                              ),
                              DataCell(
                                Text(
                                  e.department.isEmpty ? 'N/A' : e.department,
                                ),
                              ),
                              DataCell(
                                Text(
                                  e.paymentType.isEmpty
                                      ? 'Monthly'
                                      : e.paymentType,
                                ),
                              ),
                              DataCell(Text(_money(e.baseSalary))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: e.active
                                        ? const Color(0xFFD9F3E1)
                                        : const Color(0xFFF0F1F5),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    e.active ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: e.active
                                          ? const Color(0xFF19713F)
                                          : const Color(0xFF667085),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  onPressed: _canManageEmployees
                                      ? () async {
                                          final edited =
                                              await _showEmployeeDialog(
                                                existing: e,
                                              );
                                          if (edited == null) return;
                                          setState(() {
                                            final i = _employees.indexWhere(
                                              (x) => x.id == e.id,
                                            );
                                            _employees[i] = edited;
                                          });
                                          await _persistWorkspaceData();
                                          await _enqueueSync(
                                            'UPDATE',
                                            'employees',
                                            edited.id,
                                          );
                                        }
                                      : null,
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditManagementPage() {
    final query = _customerSearchController.text.trim().toLowerCase();
    final customersWithCredit = _customers
        .where((c) => c.currentBalance > 0)
        .where((c) {
          if (query.isEmpty) return true;
          return c.name.toLowerCase().contains(query) ||
              c.phone.toLowerCase().contains(query) ||
              c.vehicleNumber.toLowerCase().contains(query);
        })
        .toList();

    final totalOutstanding = customersWithCredit.fold<double>(
      0,
      (sum, c) => sum + c.currentBalance,
    );
    final overdueCustomers = 0;
    final overCreditLimit = customersWithCredit
        .where((c) => c.creditLimit > 0 && c.currentBalance > c.creditLimit)
        .length;

    Widget metricCard({
      required IconData icon,
      required Color iconColor,
      required Color iconBg,
      required String title,
      required String value,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE6E2EF)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Color(0xFF707793))),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Credit Management',
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          const Text(
            'Manage customer credit and payment tracking',
            style: TextStyle(color: Color(0xFF6D7383), fontSize: 16),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              metricCard(
                icon: Icons.credit_card,
                iconColor: const Color(0xFFB227D6),
                iconBg: const Color(0xFFF4E8FA),
                title: 'Total Outstanding',
                value: _money(totalOutstanding),
              ),
              const SizedBox(width: 12),
              metricCard(
                icon: Icons.attach_money,
                iconColor: const Color(0xFF1DAA65),
                iconBg: const Color(0xFFE6F7EE),
                title: 'Customers with Credit',
                value: '${customersWithCredit.length}',
              ),
              const SizedBox(width: 12),
              metricCard(
                icon: Icons.schedule,
                iconColor: const Color(0xFFF59A23),
                iconBg: const Color(0xFFFFF4DD),
                title: 'Overdue Customers',
                value: '$overdueCustomers',
              ),
              const SizedBox(width: 12),
              metricCard(
                icon: Icons.cancel_outlined,
                iconColor: const Color(0xFFE35D5D),
                iconBg: const Color(0xFFFCECED),
                title: 'Over Credit Limit',
                value: '$overCreditLimit',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE6E2EF)),
            ),
            child: TextField(
              controller: _customerSearchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE6E2EF)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.credit_card, color: Color(0xFF51556B)),
                        const SizedBox(width: 8),
                        Text(
                          'Customers with Credit (${customersWithCredit.length})',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: customersWithCredit.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.credit_card,
                                    size: 54,
                                    color: Color(0xFFB7A9D0),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'No customers found',
                                    style: TextStyle(
                                      color: Color(0xFF6F7690),
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF5F2FB),
                                ),
                                columns: const [
                                  DataColumn(label: Text('CUSTOMER')),
                                  DataColumn(label: Text('PHONE')),
                                  DataColumn(label: Text('OUTSTANDING')),
                                  DataColumn(label: Text('LIMIT')),
                                  DataColumn(label: Text('ACTIONS')),
                                ],
                                rows: customersWithCredit.map((c) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(c.name)),
                                      DataCell(Text(c.phone)),
                                      DataCell(Text(_money(c.currentBalance))),
                                      DataCell(Text(_money(c.creditLimit))),
                                      DataCell(
                                        Row(
                                          children: [
                                            OutlinedButton(
                                              onPressed: () =>
                                                  _recordCustomerCreditPayment(
                                                    c,
                                                  ),
                                              child: const Text(
                                                'Record Payment',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              onPressed: () =>
                                                  _showCustomerCreditHistory(c),
                                              icon: const Icon(Icons.history),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
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

  String _formatMonthLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildAttendancePage() {
    final visible = _attendanceRecords.where((r) {
      if (r.date.year != _attendanceMonth.year ||
          r.date.month != _attendanceMonth.month) {
        return false;
      }
      final q = _attendanceSearchController.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      return r.employeeName.toLowerCase().contains(q) ||
          r.status.toLowerCase().contains(q);
    }).toList();

    final today = DateTime.now();
    final presentToday = visible
        .where(
          (r) =>
              r.date.year == today.year &&
              r.date.month == today.month &&
              r.date.day == today.day &&
              r.status == 'Present',
        )
        .length;
    final absentToday = visible
        .where(
          (r) =>
              r.date.year == today.year &&
              r.date.month == today.month &&
              r.date.day == today.day &&
              r.status == 'Absent',
        )
        .length;
    final totalHours = visible.fold<double>(
      0,
      (sum, r) => sum + r.regularHours + r.overtimeHours,
    );

    Widget stat(String label, String value, Color valueColor) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE6E2EF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF8B92A7))),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Management',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Track employee attendance and working hours.',
                      style: TextStyle(color: Color(0xFF6D7383), fontSize: 16),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: _monthKey(_attendanceMonth),
                  items: List.generate(12, (i) {
                    final month = DateTime(today.year, i + 1, 1);
                    final key = _monthKey(month);
                    return DropdownMenuItem(
                      value: key,
                      child: Text(_formatMonthLabel(month)),
                    );
                  }),
                  onChanged: (value) {
                    if (value == null) return;
                    final parts = value.split('-');
                    if (parts.length != 2) return;
                    setState(
                      () => _attendanceMonth = DateTime(
                        int.tryParse(parts[0]) ?? today.year,
                        int.tryParse(parts[1]) ?? today.month,
                        1,
                      ),
                    );
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  final record = await _showAttendanceDialog();
                  if (record == null) return;
                  setState(() => _attendanceRecords.insert(0, record));
                  await _persistWorkspaceData();
                  await _enqueueSync('INSERT', 'attendance', record.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB227D6),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Attendance'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE6E2EF)),
            ),
            child: const Row(
              children: [
                Icon(Icons.watch_later_outlined),
                SizedBox(width: 8),
                Text(
                  "Today's Quick Actions",
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat(
                'Total Records',
                '${visible.length}',
                const Color(0xFF1D2439),
              ),
              const SizedBox(width: 12),
              stat('Present Today', '$presentToday', const Color(0xFF0A9F5A)),
              const SizedBox(width: 12),
              stat('Absent Today', '$absentToday', const Color(0xFFE53935)),
              const SizedBox(width: 12),
              stat(
                'Total Hours',
                totalHours.toStringAsFixed(1),
                const Color(0xFFB227D6),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE6E2EF)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Records (${visible.length})',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: visible.isEmpty
                          ? Center(
                              child: Text(
                                'No attendance records found for ${_monthKey(_attendanceMonth)}.',
                                style: const TextStyle(
                                  color: Color(0xFF6F7690),
                                  fontSize: 18,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF5F2FB),
                                ),
                                columns: const [
                                  DataColumn(label: Text('EMPLOYEE')),
                                  DataColumn(label: Text('DATE')),
                                  DataColumn(label: Text('CLOCK IN/OUT')),
                                  DataColumn(label: Text('HOURS')),
                                  DataColumn(label: Text('STATUS')),
                                  DataColumn(label: Text('ACTIONS')),
                                ],
                                rows: visible.map((r) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(r.employeeName)),
                                      DataCell(Text(_formatDate(r.date))),
                                      DataCell(
                                        Text('${r.clockIn} - ${r.clockOut}'),
                                      ),
                                      DataCell(
                                        Text(
                                          (r.regularHours + r.overtimeHours)
                                              .toStringAsFixed(1),
                                        ),
                                      ),
                                      DataCell(Text(r.status)),
                                      DataCell(
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _attendanceRecords.removeWhere(
                                                (x) => x.id == r.id,
                                              );
                                            });
                                            _enqueueSync(
                                              'DELETE',
                                              'attendance',
                                              r.id,
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
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

  Widget _buildPayrollPage() {
    final totalRecords = _payrollRecords.length;
    final pendingRecords = _payrollRecords
        .where((r) => r.status == 'Pending')
        .length;
    final pendingAmount = _payrollRecords
        .where((r) => r.status == 'Pending')
        .fold<double>(0, (sum, r) => sum + r.netPay);
    final totalPaid = _payrollRecords
        .where((r) => r.status == 'Paid')
        .fold<double>(0, (sum, r) => sum + r.netPay);

    Widget stat(String label, String value, Color valueColor) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE6E2EF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF8B92A7))),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payroll Management',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage employee payroll and compensation.',
                      style: TextStyle(color: Color(0xFF6D7383), fontSize: 16),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Monthly payroll generated')),
                  );
                },
                icon: const Icon(Icons.description_outlined),
                label: const Text('Generate Monthly'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  final payroll = await _showPayrollDialog();
                  if (payroll == null) return;
                  setState(() => _payrollRecords.insert(0, payroll));
                  await _persistWorkspaceData();
                  await _enqueueSync('INSERT', 'payroll', payroll.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB227D6),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Payroll'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              stat('Total Records', '$totalRecords', const Color(0xFF1D2439)),
              const SizedBox(width: 12),
              stat(
                'Pending Records',
                '$pendingRecords',
                const Color(0xFFFF6F00),
              ),
              const SizedBox(width: 12),
              stat(
                'Pending Amount',
                _money(pendingAmount),
                const Color(0xFFFF6F00),
              ),
              const SizedBox(width: 12),
              stat('Total Paid', _money(totalPaid), const Color(0xFF0A9F5A)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE6E2EF)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Employee ($totalRecords)',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _payrollRecords.isEmpty
                          ? const Center(
                              child: Text(
                                'No payroll records found.',
                                style: TextStyle(
                                  color: Color(0xFF6F7690),
                                  fontSize: 18,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF5F2FB),
                                ),
                                columns: const [
                                  DataColumn(label: Text('EMPLOYEE')),
                                  DataColumn(label: Text('PAYMENT TYPE')),
                                  DataColumn(label: Text('PAY PERIOD')),
                                  DataColumn(label: Text('GROSS PAY')),
                                  DataColumn(label: Text('NET PAY')),
                                  DataColumn(label: Text('STATUS')),
                                  DataColumn(label: Text('ACTIONS')),
                                ],
                                rows: _payrollRecords.map((r) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(r.employeeName)),
                                      DataCell(Text(r.paymentType)),
                                      DataCell(
                                        Text(
                                          '${r.payPeriodStart} - ${r.payPeriodEnd}',
                                        ),
                                      ),
                                      DataCell(Text(_money(r.grossPay))),
                                      DataCell(Text(_money(r.netPay))),
                                      DataCell(Text(r.status)),
                                      DataCell(
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _payrollRecords.removeWhere(
                                                (x) => x.id == r.id,
                                              );
                                            });
                                            _enqueueSync(
                                              'DELETE',
                                              'payroll',
                                              r.id,
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
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

  Widget _buildUsersPage() {
    final locationOptions = {
      'All Locations',
      _storeLocation.trim(),
      ..._users.expand((u) => u.locations),
    }.where((v) => v.isNotEmpty).toList();

    final roleOptions = {'All Roles', ..._users.map((u) => u.role)}.toList();

    final query = _usersSearchController.text.trim().toLowerCase();
    final filtered = _users.where((user) {
      if (query.isNotEmpty &&
          !user.name.toLowerCase().contains(query) &&
          !user.email.toLowerCase().contains(query)) {
        return false;
      }
      if (_usersRoleFilter != 'All Roles' && user.role != _usersRoleFilter) {
        return false;
      }
      if (_usersStatusFilter == 'Active' && !user.active) return false;
      if (_usersStatusFilter == 'Inactive' && user.active) return false;
      if (_usersLocationFilter != 'All Locations' &&
          !user.locations.contains(_usersLocationFilter)) {
        return false;
      }
      return true;
    }).toList();

    final totalUsers = _users.length;
    final activeUsers = _users.where((u) => u.active).length;
    final admins = _users.where((u) => u.role == 'ADMIN').length;
    final owners = _users.where((u) => u.role == 'OWNER').length;
    final cashiers = _users.where((u) => u.role == 'CASHIER').length;

    Widget metric({
      required IconData icon,
      required Color iconColor,
      required Color iconBg,
      required String value,
      required String label,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE6E2EF)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(label, style: const TextStyle(color: Color(0xFF7A8093))),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.group_outlined,
                      color: Color(0xFFB227D6),
                      size: 34,
                    ),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User Management',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Manage user accounts and permissions.',
                          style: TextStyle(
                            color: Color(0xFF6D7383),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB227D6),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add User'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              metric(
                icon: Icons.groups_outlined,
                iconColor: const Color(0xFFB227D6),
                iconBg: const Color(0xFFF4E8FA),
                value: '$totalUsers',
                label: 'users.totalUsers',
              ),
              const SizedBox(width: 12),
              metric(
                icon: Icons.check_circle_outline,
                iconColor: const Color(0xFF1DAA65),
                iconBg: const Color(0xFFE6F7EE),
                value: '$activeUsers',
                label: 'users.activeUsers',
              ),
              const SizedBox(width: 12),
              metric(
                icon: Icons.shield_outlined,
                iconColor: const Color(0xFFE35D5D),
                iconBg: const Color(0xFFFCECED),
                value: '$admins',
                label: 'users.admins',
              ),
              const SizedBox(width: 12),
              metric(
                icon: Icons.business_outlined,
                iconColor: const Color(0xFFB227D6),
                iconBg: const Color(0xFFF7EAFD),
                value: '$owners',
                label: 'users.owners',
              ),
              const SizedBox(width: 12),
              metric(
                icon: Icons.person_outline,
                iconColor: const Color(0xFFF59A23),
                iconBg: const Color(0xFFFFF4DD),
                value: '$cashiers',
                label: 'users.cashiers',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE6E2EF)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usersSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 160,
                  child: _salesFilterDropdown(
                    value: _usersRoleFilter,
                    items: roleOptions,
                    onChanged: (v) => setState(() => _usersRoleFilter = v),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 180,
                  child: _salesFilterDropdown(
                    value: _usersStatusFilter,
                    items: const ['All Statuses', 'Active', 'Inactive'],
                    onChanged: (v) => setState(() => _usersStatusFilter = v),
                    labelMapper: (v) =>
                        v == 'All Statuses' ? 'users.allStatuses' : v,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 200,
                  child: _salesFilterDropdown(
                    value: _usersLocationFilter,
                    items: locationOptions,
                    onChanged: (v) => setState(() => _usersLocationFilter = v),
                    labelMapper: (v) =>
                        v == 'All Locations' ? 'users.allLocations' : v,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE6E2EF)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Users (${filtered.length})',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF5F2FB),
                          ),
                          columns: const [
                            DataColumn(label: Text('USER')),
                            DataColumn(label: Text('EMAIL')),
                            DataColumn(label: Text('ROLE')),
                            DataColumn(label: Text('USERS.LOCATIONS')),
                            DataColumn(label: Text('STATUS')),
                            DataColumn(label: Text('LAST LOGIN')),
                            DataColumn(label: Text('ACTIONS')),
                          ],
                          rows: filtered.map((user) {
                            final initials = user.name.trim().isEmpty
                                ? 'U'
                                : user.name
                                      .trim()
                                      .split(' ')
                                      .take(2)
                                      .map((x) => x.substring(0, 1))
                                      .join()
                                      .toUpperCase();

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: const Color(
                                          0xFFD9F3E1,
                                        ),
                                        child: Text(
                                          initials,
                                          style: const TextStyle(
                                            color: Color(0xFF1E7D47),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '${user.permissions.length} custom permissions',
                                            style: const TextStyle(
                                              color: Color(0xFF7E8495),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(user.email)),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD9F3E1),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      user.role[0] +
                                          user.role.substring(1).toLowerCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF19713F),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    user.locations.isEmpty
                                        ? 'None assigned'
                                        : user.locations.join(', '),
                                    style: TextStyle(
                                      fontStyle: user.locations.isEmpty
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                      color: const Color(0xFF767D96),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: user.active
                                          ? const Color(0xFFD9F3E1)
                                          : const Color(0xFFF0F1F5),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      user.active ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        color: user.active
                                            ? const Color(0xFF19713F)
                                            : const Color(0xFF677084),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const DataCell(Text('Never')),
                                DataCell(
                                  IconButton(
                                    onPressed: _canManageEmployees
                                        ? () async {
                                            final edited =
                                                await _showUserDialog(
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
                                              final authService = context
                                                  .read<AuthService>();
                                              await authService
                                                  .createStoreLogin(
                                                    storeName: _companyName,
                                                    tenantId:
                                                        _activeTenantId ??
                                                        'local',
                                                    email: edited.user.email,
                                                    password: edited.password,
                                                    role: edited.user.role
                                                        .toLowerCase(),
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
                                ),
                              ],
                            );
                          }).toList(),
                        ),
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

  Widget _buildSettingsTabContent() {
    const inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
    );

    Widget sectionTitle(String title, String subtitle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF6D7383))),
        ],
      );
    }

    switch (_settingsTab) {
      case 'profile':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle(
              'Profile Settings',
              'Update your account information and password.',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _profileName,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: inputBorder,
                    ),
                    onChanged: (v) => _profileName = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _profileEmail,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: inputBorder,
                    ),
                    onChanged: (v) => _profileEmail = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _profilePhone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: inputBorder,
              ),
              onChanged: (v) => _profilePhone = v,
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 18),
            const Text(
              'Change Password',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _profileCurrentPassword,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: inputBorder,
              ),
              onChanged: (v) => _profileCurrentPassword = v,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _profileNewPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      border: inputBorder,
                    ),
                    onChanged: (v) => _profileNewPassword = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _profileConfirmPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      border: inputBorder,
                    ),
                    onChanged: (v) => _profileConfirmPassword = v,
                  ),
                ),
              ],
            ),
          ],
        );
      case 'general':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle(
              'General Settings',
              'Configure basic store operations and working hours.',
            ),
            const SizedBox(height: 18),
            TextFormField(
              initialValue: _companyName,
              decoration: const InputDecoration(
                labelText: 'Company Name',
                border: inputBorder,
              ),
              onChanged: (v) => _companyName = v,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _storeLocation,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: inputBorder,
              ),
              onChanged: (v) => _storeLocation = v,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _openFrom,
                    decoration: const InputDecoration(
                      labelText: 'Open From',
                      border: inputBorder,
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
                      border: inputBorder,
                    ),
                    onChanged: (v) => _openTo = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Billing & Scanner',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Accept Cash'),
              value: _acceptCash,
              onChanged: (v) => setState(() => _acceptCash = v ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Accept Card'),
              value: _acceptCard,
              onChanged: (v) => setState(() => _acceptCard = v ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Accept Cheque'),
              value: _acceptCheque,
              onChanged: (v) => setState(() => _acceptCheque = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Accept Installment'),
              value: _acceptInstallment,
              onChanged: (v) => setState(() => _acceptInstallment = v ?? false),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _taxRate,
                    decoration: const InputDecoration(
                      labelText: 'Tax Rate (%)',
                      border: inputBorder,
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
                      border: inputBorder,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      case 'company':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle(
              'Company Information',
              'Maintain your legal and contact details used in invoices.',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _companyName,
                    decoration: const InputDecoration(
                      labelText: 'Company Display Name',
                      border: inputBorder,
                    ),
                    onChanged: (v) => _companyName = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _companyRegNo,
                    decoration: const InputDecoration(
                      labelText: 'Registration Number',
                      border: inputBorder,
                    ),
                    onChanged: (v) => _companyRegNo = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _companyEmail,
                    decoration: const InputDecoration(
                      labelText: 'Company Email',
                      border: inputBorder,
                    ),
                    onChanged: (v) => _companyEmail = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _companyPhone,
                    decoration: const InputDecoration(
                      labelText: 'Company Phone',
                      border: inputBorder,
                    ),
                    onChanged: (v) => _companyPhone = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _companyAddress,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Company Address',
                border: inputBorder,
              ),
              onChanged: (v) => _companyAddress = v,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDDE0EA)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFFE7EBFA),
                    ),
                    child: const Icon(Icons.image_outlined),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Company logo uploader placeholder. Connect file upload for production use.',
                      style: TextStyle(color: Color(0xFF6D7383)),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Upload Logo'),
                  ),
                ],
              ),
            ),
          ],
        );
      case 'receipt':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle(
              'Receipt Settings',
              'Customize the print format and bill appearance.',
            ),
            const SizedBox(height: 18),
            TextFormField(
              initialValue: _receiptHeader,
              decoration: const InputDecoration(
                labelText: 'Receipt Header',
                border: inputBorder,
              ),
              onChanged: (v) => _receiptHeader = v,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: _receiptFooter,
              decoration: const InputDecoration(
                labelText: 'Receipt Footer',
                border: inputBorder,
              ),
              onChanged: (v) => _receiptFooter = v,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: _receiptNote,
              decoration: const InputDecoration(
                labelText: 'Receipt Note',
                border: inputBorder,
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
                      labelText: 'Receipt Width',
                      border: inputBorder,
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
                      border: inputBorder,
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
                border: inputBorder,
              ),
              onChanged: (v) => _receiptFontScale = v,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _printDemoReceipt,
                  icon: const Icon(Icons.print),
                  label: const Text('Print Demo Bill'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Preview Receipt'),
                ),
              ],
            ),
          ],
        );
      case 'preferences':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle(
              'User Preferences',
              'Configure workspace appearance and daily behavior.',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _uiTheme,
                    items: const [
                      DropdownMenuItem(value: 'Light', child: Text('Light')),
                      DropdownMenuItem(value: 'Dark', child: Text('Dark')),
                      DropdownMenuItem(
                        value: 'System',
                        child: Text('System Default'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _uiTheme = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Theme',
                      border: inputBorder,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _uiLanguage,
                    items: const [
                      DropdownMenuItem(
                        value: 'English',
                        child: Text('English'),
                      ),
                      DropdownMenuItem(
                        value: 'Sinhala',
                        child: Text('Sinhala'),
                      ),
                      DropdownMenuItem(value: 'Tamil', child: Text('Tamil')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _uiLanguage = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      border: inputBorder,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Notification Sounds'),
              value: _prefSound,
              onChanged: (v) => setState(() => _prefSound = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto Print Receipts After Sale'),
              value: _prefAutoPrint,
              onChanged: (v) => setState(() => _prefAutoPrint = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use Compact Tables'),
              value: _prefCompact,
              onChanged: (v) => setState(() => _prefCompact = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Require Confirmation Before Checkout'),
              value: _prefRequireSaleConfirmation,
              onChanged: (v) =>
                  setState(() => _prefRequireSaleConfirmation = v),
            ),
            const SizedBox(height: 4),
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
                labelText: 'Sync Mode',
                border: inputBorder,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _integrationWebhook,
              decoration: const InputDecoration(
                labelText: 'Webhook URL (optional)',
                border: inputBorder,
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Email Alerts'),
              value: _notifyEmail,
              onChanged: (v) => setState(() => _notifyEmail = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('SMS Alerts'),
              value: _notifySms,
              onChanged: (v) => setState(() => _notifySms = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Payroll Reminder Alerts'),
              value: _notifyPayroll,
              onChanged: (v) => setState(() => _notifyPayroll = v),
            ),
          ],
        );
      case 'payroll':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle(
              'Payroll Configuration',
              'Set default payroll cycle, overtime and deductions.',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _payrollCycle,
                    items: const [
                      DropdownMenuItem(
                        value: 'Monthly',
                        child: Text('Monthly'),
                      ),
                      DropdownMenuItem(
                        value: 'Bi-Weekly',
                        child: Text('Bi-Weekly'),
                      ),
                      DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _payrollCycle = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Pay Cycle',
                      border: inputBorder,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _payrollWorkingDays,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Working Days / Month',
                      border: inputBorder,
                    ),
                    onChanged: (v) => _payrollWorkingDays = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _payrollOtRate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Overtime Multiplier',
                      border: inputBorder,
                    ),
                    onChanged: (v) => _payrollOtRate = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _payrollLatePenalty,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Late Penalty (LKR)',
                      border: inputBorder,
                    ),
                    onChanged: (v) => _payrollLatePenalty = v,
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto Generate Payroll at Month End'),
              value: _payrollAutoGenerate,
              onChanged: (v) => setState(() => _payrollAutoGenerate = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable EPF/ETF Calculations'),
              value: _payrollEnableEpf,
              onChanged: (v) => setState(() => _payrollEnableEpf = v),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDDE0EA)),
              ),
              child: const Text(
                'These settings define defaults for payroll records created from the Payroll module.',
                style: TextStyle(color: Color(0xFF6D7383)),
              ),
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
            'Manage your profile, store preferences and operational settings.',
            style: TextStyle(color: Color(0xFF6D7383)),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 980;

              final sidePanel = Container(
                width: stacked ? double.infinity : 255,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDDE0EA)),
                  color: Colors.white,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _settingsTabs.map((tab) {
                      final selected = _settingsTab == tab.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _settingsTab = tab.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: selected
                                  ? const Color(0xFFEAF0FF)
                                  : Colors.transparent,
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFFBCD0FF)
                                    : const Color(0x00000000),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  tab.icon,
                                  size: 18,
                                  color: selected
                                      ? const Color(0xFF2454D3)
                                      : const Color(0xFF5F6475),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    tab.label,
                                    style: TextStyle(
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: selected
                                          ? const Color(0xFF2454D3)
                                          : const Color(0xFF2E3240),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );

              final contentPanel = Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDDE0EA)),
                  color: Colors.white,
                ),
                child: _buildSettingsTabContent(),
              );

              if (stacked) {
                return Column(
                  children: [
                    sidePanel,
                    const SizedBox(height: 12),
                    contentPanel,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sidePanel,
                  const SizedBox(width: 14),
                  Expanded(child: contentPanel),
                ],
              );
            },
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
    final query = _serviceSearchController.text.trim().toLowerCase();
    final filtered = _serviceJobs.where((s) {
      if (query.isEmpty) return true;
      return s.title.toLowerCase().contains(query) ||
          s.sku.toLowerCase().contains(query) ||
          s.description.toLowerCase().contains(query);
    }).toList();

    Future<void> addService() async {
      final job = await _showServiceDialog();
      if (job == null) return;
      setState(() => _serviceJobs.insert(0, job));
      await _persistWorkspaceData();
      await _enqueueSync('INSERT', 'services', job.id);
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Services Management',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage your service offerings',
                      style: TextStyle(color: Color(0xFF6D7383), fontSize: 16),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _selectedNavKey = 'jobCards');
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFB227D6),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Job Cards'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: addService,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB227D6),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Service'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE6E2EF)),
            ),
            child: TextField(
              controller: _serviceSearchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search services by name, SKU, or description...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE6E2EF)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Services (${filtered.length})',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No services found',
                                style: TextStyle(
                                  color: Color(0xFF7E8495),
                                  fontSize: 20,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF5F2FB),
                                ),
                                columns: const [
                                  DataColumn(label: Text('SERVICE')),
                                  DataColumn(label: Text('SKU')),
                                  DataColumn(label: Text('PRICE')),
                                  DataColumn(label: Text('STATUS')),
                                  DataColumn(label: Text('ACTIONS')),
                                ],
                                rows: filtered.map((s) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              s.description,
                                              style: const TextStyle(
                                                color: Color(0xFF7E8495),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(s.sku)),
                                      DataCell(Text(_money(s.defaultPrice))),
                                      DataCell(
                                        Switch(
                                          value: s.active,
                                          onChanged: (v) {
                                            setState(() => s.active = v);
                                            _enqueueSync(
                                              'UPDATE',
                                              'services',
                                              s.id,
                                            );
                                          },
                                        ),
                                      ),
                                      DataCell(
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _serviceJobs.removeWhere(
                                                (x) => x.id == s.id,
                                              );
                                            });
                                            _enqueueSync(
                                              'DELETE',
                                              'services',
                                              s.id,
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
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

  Widget _buildJobCardsPage() {
    bool isJobCard(_ServiceJobItem item) {
      return item.customerName.trim().isNotEmpty ||
          item.services.isNotEmpty ||
          item.materials.isNotEmpty;
    }

    final jobs = _serviceJobs.where(isJobCard).where((job) {
      final statusOk =
          _jobCardStatusFilter == 'ALL' || job.status == _jobCardStatusFilter;
      final priorityOk =
          _jobCardPriorityFilter == 'ALL' ||
          job.priority == _jobCardPriorityFilter;
      return statusOk && priorityOk;
    }).toList();

    Future<void> createJobCard() async {
      final job = await _showJobCardDialog();
      if (job == null) return;
      setState(() => _serviceJobs.insert(0, job));
      await _persistWorkspaceData();
      await _enqueueSync('INSERT', 'job_cards', job.id);
    }

    Color priorityColor(String priority) {
      switch (priority) {
        case 'HIGH':
          return const Color(0xFFE53935);
        case 'MEDIUM':
          return const Color(0xFFFF9800);
        default:
          return const Color(0xFF2E7D32);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Job Cards',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage service job cards and track progress',
                      style: TextStyle(color: Color(0xFF6D7383), fontSize: 16),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: createJobCard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB227D6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Create Job Card'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE6E2EF)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'All Job Cards',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            initialValue: _jobCardStatusFilter,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'ALL',
                                child: Text('All Statuses'),
                              ),
                              DropdownMenuItem(
                                value: 'OPEN',
                                child: Text('Open'),
                              ),
                              DropdownMenuItem(
                                value: 'IN_PROGRESS',
                                child: Text('In Progress'),
                              ),
                              DropdownMenuItem(
                                value: 'COMPLETED',
                                child: Text('Completed'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(
                                () => _jobCardStatusFilter = value ?? 'ALL',
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            initialValue: _jobCardPriorityFilter,
                            decoration: const InputDecoration(
                              labelText: 'Priority',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'ALL',
                                child: Text('All Priorities'),
                              ),
                              DropdownMenuItem(
                                value: 'LOW',
                                child: Text('Low'),
                              ),
                              DropdownMenuItem(
                                value: 'MEDIUM',
                                child: Text('Medium'),
                              ),
                              DropdownMenuItem(
                                value: 'HIGH',
                                child: Text('High'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(
                                () => _jobCardPriorityFilter = value ?? 'ALL',
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: jobs.isEmpty
                          ? const Center(
                              child: Text(
                                'No job cards found',
                                style: TextStyle(
                                  color: Color(0xFF8780A0),
                                  fontSize: 20,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF5F2FB),
                                ),
                                columns: const [
                                  DataColumn(label: Text('TITLE')),
                                  DataColumn(label: Text('CUSTOMER')),
                                  DataColumn(label: Text('PRIORITY')),
                                  DataColumn(label: Text('SCHEDULED')),
                                  DataColumn(label: Text('STATUS')),
                                  DataColumn(label: Text('TOTAL')),
                                ],
                                rows: jobs.map((job) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(job.title)),
                                      DataCell(
                                        Text(
                                          job.customerName.isEmpty
                                              ? 'Walk-in Customer'
                                              : job.customerName,
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: priorityColor(
                                              job.priority,
                                            ).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            job.priority,
                                            style: TextStyle(
                                              color: priorityColor(
                                                job.priority,
                                              ),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          [job.scheduledDate, job.scheduledTime]
                                              .where((s) => s.trim().isNotEmpty)
                                              .join(' ')
                                              .trim(),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEEE8FA),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            job.status,
                                            style: const TextStyle(
                                              color: Color(0xFF6A1B9A),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(_money(job.defaultPrice))),
                                    ],
                                  );
                                }).toList(),
                              ),
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

  Widget _buildWarrantiesPage() {
    final query = _warrantySearchController.text.trim().toLowerCase();
    final allWarrantyRows = _serviceJobs.where((job) {
      if (!job.warranty) return false;
      final haystack = [
        job.sku,
        job.title,
        job.customerName,
        job.deviceInfo,
      ].join(' ').toLowerCase();
      return query.isEmpty || haystack.contains(query);
    }).toList();

    final currentRows = allWarrantyRows.where((job) {
      switch (_warrantyTabKey) {
        case 'claims':
          return job.status == 'CLAIMED';
        case 'returns':
          return job.status == 'RETURNED';
        case 'analytics':
          return false;
        default:
          return true;
      }
    }).toList();

    Widget tabItem({
      required String key,
      required IconData icon,
      required String label,
    }) {
      final selected = _warrantyTabKey == key;
      return InkWell(
        onTap: () => setState(() => _warrantyTabKey = key),
        child: Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? const Color(0xFFB227D6) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? const Color(0xFFB227D6)
                    : const Color(0xFF777E93),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFFB227D6)
                      : const Color(0xFF777E93),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 28,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Warranty & Returns Management',
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          const Text(
            'Manage warranties, claims, and returns for your products',
            style: TextStyle(color: Color(0xFF6D7383), fontSize: 16),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              tabItem(
                key: 'warranties',
                icon: Icons.verified_user_outlined,
                label: 'Warranties',
              ),
              const SizedBox(width: 34),
              tabItem(
                key: 'claims',
                icon: Icons.warning_amber_rounded,
                label: 'Claims',
              ),
              const SizedBox(width: 34),
              tabItem(
                key: 'returns',
                icon: Icons.sync_alt_rounded,
                label: 'Returns',
              ),
              const SizedBox(width: 34),
              tabItem(
                key: 'analytics',
                icon: Icons.bar_chart_rounded,
                label: 'Analytics',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE6E2EF)),
            ),
            child: TextField(
              controller: _warrantySearchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText:
                    'Search warranties by serial number, product, or customer...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE6E2EF)),
              ),
              child: currentRows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 66,
                            color: Color(0xFFC7BCD9),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _warrantyTabKey == 'warranties'
                                ? 'No warranties found'
                                : _warrantyTabKey == 'claims'
                                ? 'No claims found'
                                : _warrantyTabKey == 'returns'
                                ? 'No returns found'
                                : 'No analytics found',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2E3448),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _warrantyTabKey == 'warranties'
                                ? 'No warranty records have been created yet.'
                                : _warrantyTabKey == 'claims'
                                ? 'No warranty claims have been created yet.'
                                : _warrantyTabKey == 'returns'
                                ? 'No return records have been created yet.'
                                : 'No analytics records are available yet.',
                            style: const TextStyle(
                              color: Color(0xFF7F8599),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFF5F2FB),
                        ),
                        columns: const [
                          DataColumn(label: Text('SERIAL')),
                          DataColumn(label: Text('PRODUCT')),
                          DataColumn(label: Text('CUSTOMER')),
                          DataColumn(label: Text('STATUS')),
                        ],
                        rows: currentRows.map((job) {
                          return DataRow(
                            cells: [
                              DataCell(Text(job.sku.isEmpty ? '-' : job.sku)),
                              DataCell(Text(job.title)),
                              DataCell(
                                Text(
                                  job.customerName.isEmpty
                                      ? 'Walk-in Customer'
                                      : job.customerName,
                                ),
                              ),
                              DataCell(Text(job.status)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ),
        ],
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

  Widget _buildCategoriesPage() {
    final categories = _productCategories.where((c) {
      final q = _productSearchController.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      return c.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Categories',
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          const Text(
            'Organize products using categories.',
            style: TextStyle(color: Color(0xFF6D7383), fontSize: 16),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _productSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search categories...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _canManageCatalog ? _manageCategories : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB227D6),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add New Category'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              child: ListView.separated(
                itemCount: categories.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final count = _products
                      .where(
                        (p) => p.category.toLowerCase() == cat.toLowerCase(),
                      )
                      .length;
                  return ListTile(
                    title: Text(cat),
                    subtitle: Text('$count products'),
                    trailing: _canManageCatalog
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _editCategory(cat),
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit category',
                              ),
                              IconButton(
                                onPressed: () => _deleteCategory(cat),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Delete category',
                              ),
                            ],
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _canManageCatalog ? () => _editCategory(cat) : null,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editCategory(String oldCategory) async {
    final controller = TextEditingController(text: oldCategory);
    final updated = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated == null || updated.isEmpty || updated == oldCategory) return;
    final duplicate = _productCategories.any(
      (c) => c.toLowerCase() == updated.toLowerCase(),
    );
    if (duplicate) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Category already exists')));
      return;
    }

    setState(() {
      _productCategories = _productCategories
          .map((c) => c == oldCategory ? updated : c)
          .toList();
      for (final product in _products) {
        if (product.category == oldCategory) {
          product.category = updated;
        }
      }
      if (_posCategoryFilter == oldCategory) {
        _posCategoryFilter = updated;
      }
    });
    await _persistWorkspaceData();
    await _enqueueSync('UPDATE', 'categories', updated);
  }

  Future<void> _deleteCategory(String category) async {
    final affectedCount = _products
        .where((p) => p.category.toLowerCase() == category.toLowerCase())
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          affectedCount > 0
              ? 'Delete "$category"? $affectedCount products will be moved to General.'
              : 'Delete "$category"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE35D5D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _productCategories.removeWhere((c) => c == category);
      if (_productCategories.isEmpty) {
        _productCategories.add('General');
      }
      if (affectedCount > 0) {
        if (!_productCategories.any((c) => c.toLowerCase() == 'general')) {
          _productCategories.add('General');
        }
        for (final product in _products) {
          if (product.category.toLowerCase() == category.toLowerCase()) {
            product.category = 'General';
          }
        }
      }
      if (_posCategoryFilter == category) {
        _posCategoryFilter = 'All Categories';
      }
    });
    await _persistWorkspaceData();
    await _enqueueSync('DELETE', 'categories', category);
  }

  Widget _buildPurchaseOrdersPage() {
    final query = _purchaseOrderSearchController.text.trim().toLowerCase();
    final filtered = _purchaseOrders.where((po) {
      if (_purchaseOrderStatusFilter != 'All Statuses' &&
          po.status != _purchaseOrderStatusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return po.id.toLowerCase().contains(query) ||
          po.supplier.toLowerCase().contains(query);
    }).toList();

    Future<void> createOrder() async {
      final po = await _showPurchaseOrderDialog();
      if (po == null) return;
      setState(() => _purchaseOrders.insert(0, po));
      await _persistWorkspaceData();
      await _enqueueSync('INSERT', 'purchase_orders', po.id);
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchase Orders',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage purchase orders and supplier relationships.',
                      style: TextStyle(color: Color(0xFF6D7383), fontSize: 16),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _canManageCatalog ? createOrder : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB227D6),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Create Order'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE6E2EF)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _purchaseOrderSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search purchase orders...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    initialValue: _purchaseOrderStatusFilter,
                    items: const [
                      DropdownMenuItem(
                        value: 'All Statuses',
                        child: Text('All Statuses'),
                      ),
                      DropdownMenuItem(value: 'DRAFT', child: Text('DRAFT')),
                      DropdownMenuItem(
                        value: 'PENDING',
                        child: Text('PENDING'),
                      ),
                      DropdownMenuItem(
                        value: 'RECEIVED',
                        child: Text('RECEIVED'),
                      ),
                      DropdownMenuItem(
                        value: 'CANCELLED',
                        child: Text('CANCELLED'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _purchaseOrderStatusFilter = v);
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 56,
                            color: const Color(0xFFB9A9D8),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No purchase orders yet',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Get started by creating your first purchase order to manage your inventory.',
                            style: TextStyle(color: Color(0xFF7E8495)),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: _canManageCatalog ? createOrder : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB227D6),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Create Your First Order'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final po = filtered[index];
                        return ListTile(
                          leading: const Icon(Icons.assignment_outlined),
                          title: Text('${po.id} • ${po.supplier}'),
                          subtitle: Text(
                            '${po.itemsCount} items • ${_money(po.amount)} • ${po.status}',
                          ),
                          trailing: Text(po.expectedDate),
                        );
                      },
                    ),
            ),
          ),
        ],
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
    final descriptionController = TextEditingController();
    final costController = TextEditingController();
    final unitController = TextEditingController(text: 'Unit');
    final warrantyController = TextEditingController(text: '0');
    String selectedType = 'Unit';

    return showGeneralDialog<_ProductItem>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AddProduct',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
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
          builder: (context, setLocal) {
            return Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.white,
                child: SizedBox(
                  width: 600,
                  height: double.infinity,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE6E2EF)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              existing == null
                                  ? 'Add New Product'
                                  : 'Edit Product',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Product Name *'),
                              const SizedBox(height: 6),
                              TextField(controller: nameController),
                              const SizedBox(height: 12),
                              const Text('Description'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: descriptionController,
                                maxLines: 3,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('SKU *'),
                                        const SizedBox(height: 6),
                                        TextField(controller: idController),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Category *'),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          key: ValueKey(selectedCategory),
                                          initialValue: selectedCategory,
                                          items: categories
                                              .map(
                                                (c) => DropdownMenuItem(
                                                  value: c,
                                                  child: Text(c),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (v) {
                                            if (v == null) return;
                                            setLocal(
                                              () => selectedCategory = v,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Product Type'),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          initialValue: selectedType,
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Unit',
                                              child: Text('Unit'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Service',
                                              child: Text('Service'),
                                            ),
                                          ],
                                          onChanged: (v) {
                                            if (v == null) return;
                                            setLocal(() => selectedType = v);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Price *'),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: priceController,
                                          keyboardType: TextInputType.number,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Cost'),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: costController,
                                          keyboardType: TextInputType.number,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Quantity'),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: stockController,
                                          keyboardType: TextInputType.number,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Minimum Stock'),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: minStockController,
                                          keyboardType: TextInputType.number,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Unit'),
                                        const SizedBox(height: 6),
                                        TextField(controller: unitController),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Barcode'),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: barcodeController,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: () {
                                      barcodeController.text =
                                          _generateBarcodeValue();
                                    },
                                    child: const Text('Generate'),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Warranty Period'),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: warrantyController,
                                          keyboardType: TextInputType.number,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child: Text('months'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    'Optional. Set 0 or leave empty for no warranty.',
                                    style: TextStyle(
                                      color: Color(0xFF7E8495),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => _printProductBarcode(
                                      _ProductItem(
                                        id: idController.text.trim(),
                                        name: nameController.text.trim(),
                                        category: selectedCategory,
                                        barcode: barcodeController.text.trim(),
                                        price:
                                            double.tryParse(
                                              priceController.text.trim(),
                                            ) ??
                                            0,
                                        stock:
                                            int.tryParse(
                                              stockController.text.trim(),
                                            ) ??
                                            0,
                                        minStock:
                                            int.tryParse(
                                              minStockController.text.trim(),
                                            ) ??
                                            0,
                                      ),
                                    ),
                                    icon: const Icon(Icons.qr_code_2_outlined),
                                    tooltip: 'Print barcode preview',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Divider(),
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
                                      final value = newCategoryController.text
                                          .trim();
                                      if (value.isEmpty) return;
                                      if (categories.any(
                                        (c) =>
                                            c.toLowerCase() ==
                                            value.toLowerCase(),
                                      )) {
                                        return;
                                      }
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
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFE6E2EF)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Spacer(),
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                final item = _ProductItem(
                                  id: idController.text.trim(),
                                  name: nameController.text.trim(),
                                  category: selectedCategory,
                                  barcode: barcodeController.text.trim(),
                                  price:
                                      double.tryParse(
                                        priceController.text.trim(),
                                      ) ??
                                      0,
                                  stock:
                                      int.tryParse(
                                        stockController.text.trim(),
                                      ) ??
                                      0,
                                  minStock:
                                      int.tryParse(
                                        minStockController.text.trim(),
                                      ) ??
                                      0,
                                );
                                if (!_productCategories.any(
                                  (c) =>
                                      c.toLowerCase() ==
                                      selectedCategory.toLowerCase(),
                                )) {
                                  _productCategories.add(selectedCategory);
                                }
                                Navigator.pop(context, item);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB227D6),
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                existing == null
                                    ? 'Create Product'
                                    : 'Update Product',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(position: offset, child: child);
      },
    );
  }

  Future<_CustomerItem?> _showCustomerDialog({_CustomerItem? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final vehicleController = TextEditingController(
      text: existing?.vehicleNumber ?? '',
    );
    final addressController = TextEditingController(
      text: existing?.address ?? '',
    );
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final creditLimitController = TextEditingController(
      text: (existing?.creditLimit ?? 0).toString(),
    );

    final created = await showGeneralDialog<_CustomerItem>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AddCustomer',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.white,
            child: SizedBox(
              width: 460,
              height: double.infinity,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE6E2EF)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          existing == null
                              ? 'Add New Customer'
                              : 'Edit Customer',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Customer Name *'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              hintText: 'Enter customer name',
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text('Vehicle Number (License Plate) *'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: vehicleController,
                            decoration: const InputDecoration(
                              hintText: 'e.g., ABC-1234',
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text('Credit Limit'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: creditLimitController,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 14),
                          const Text('Phone Number'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                              hintText: 'Enter phone number',
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text('Email Address'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              hintText: 'Enter email address',
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text('Address'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: addressController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Enter address',
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text('Notes'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Additional notes',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFE6E2EF))),
                    ),
                    child: Row(
                      children: [
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            final id =
                                existing?.id ??
                                'C${DateTime.now().millisecondsSinceEpoch % 100000}';
                            Navigator.pop(
                              context,
                              _CustomerItem(
                                id: id,
                                name: nameController.text.trim(),
                                vehicleNumber: vehicleController.text.trim(),
                                phone: phoneController.text.trim(),
                                email: emailController.text.trim(),
                                address: addressController.text.trim(),
                                notes: notesController.text.trim(),
                                creditLimit:
                                    double.tryParse(
                                      creditLimitController.text.trim(),
                                    ) ??
                                    0,
                                currentBalance: existing?.currentBalance ?? 0,
                                loyaltyPoints: existing?.loyaltyPoints ?? 0,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB227D6),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            existing == null
                                ? 'Create Customer'
                                : 'Update Customer',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(position: offset, child: child);
      },
    );

    nameController.dispose();
    vehicleController.dispose();
    addressController.dispose();
    notesController.dispose();
    phoneController.dispose();
    emailController.dispose();
    creditLimitController.dispose();

    return created;
  }

  Future<_AttendanceRecordItem?> _showAttendanceDialog() async {
    final dateController = TextEditingController(
      text: _formatDate(DateTime.now()),
    );
    final inController = TextEditingController(text: '');
    final outController = TextEditingController(text: '');
    final regularHoursController = TextEditingController(text: '8');
    final overtimeHoursController = TextEditingController(text: '0');
    final notesController = TextEditingController();
    String selectedEmployeeId = _employees.isEmpty ? '' : _employees.first.id;
    String status = 'Present';
    bool isHoliday = false;

    final created = await showGeneralDialog<_AttendanceRecordItem>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AddAttendance',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.white,
                child: SizedBox(
                  width: 620,
                  height: double.infinity,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE6E2EF)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Add New Attendance Record',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Employee *'),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: selectedEmployeeId.isEmpty
                                    ? null
                                    : selectedEmployeeId,
                                items: _employees
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e.id,
                                        child: Text(e.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setLocal(() => selectedEmployeeId = value);
                                },
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _labeledTextField(
                                      'Date',
                                      dateController,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Status'),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          initialValue: status,
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Present',
                                              child: Text('Present'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Absent',
                                              child: Text('Absent'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Leave',
                                              child: Text('Leave'),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            if (value == null) return;
                                            setLocal(() => status = value);
                                          },
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _labeledTextField(
                                      'In:',
                                      inController,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _labeledTextField(
                                      'Out:',
                                      outController,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _labeledTextField(
                                      'Regular Hours',
                                      regularHoursController,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _labeledTextField(
                                      'Overtime Hours',
                                      overtimeHoursController,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _labeledTextField(
                                'Notes',
                                notesController,
                                maxLines: 3,
                              ),
                              const SizedBox(height: 10),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: isHoliday,
                                onChanged: (value) =>
                                    setLocal(() => isHoliday = value ?? false),
                                title: const Text('Mark as Holiday'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFE6E2EF)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Spacer(),
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                final employee = _employees.firstWhere(
                                  (e) => e.id == selectedEmployeeId,
                                  orElse: () => _EmployeeItem(
                                    id: 'EMP',
                                    name: 'Employee',
                                    role: 'STAFF',
                                    active: true,
                                  ),
                                );
                                final dateParts = dateController.text
                                    .trim()
                                    .split('/');
                                DateTime parsedDate = DateTime.now();
                                if (dateParts.length == 3) {
                                  parsedDate = DateTime(
                                    int.tryParse(dateParts[2]) ??
                                        DateTime.now().year,
                                    int.tryParse(dateParts[0]) ??
                                        DateTime.now().month,
                                    int.tryParse(dateParts[1]) ??
                                        DateTime.now().day,
                                  );
                                }
                                Navigator.pop(
                                  context,
                                  _AttendanceRecordItem(
                                    id: 'AT${DateTime.now().millisecondsSinceEpoch}',
                                    employeeId: employee.id,
                                    employeeName: employee.name,
                                    date: parsedDate,
                                    status: status,
                                    clockIn: inController.text.trim().isEmpty
                                        ? '--:--'
                                        : inController.text.trim(),
                                    clockOut: outController.text.trim().isEmpty
                                        ? '--:--'
                                        : outController.text.trim(),
                                    regularHours:
                                        double.tryParse(
                                          regularHoursController.text.trim(),
                                        ) ??
                                        0,
                                    overtimeHours:
                                        double.tryParse(
                                          overtimeHoursController.text.trim(),
                                        ) ??
                                        0,
                                    notes: notesController.text.trim(),
                                    isHoliday: isHoliday,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB227D6),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Create Attendance'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(position: offset, child: child);
      },
    );

    dateController.dispose();
    inController.dispose();
    outController.dispose();
    regularHoursController.dispose();
    overtimeHoursController.dispose();
    notesController.dispose();

    return created;
  }

  Future<_PayrollRecordItem?> _showPayrollDialog() async {
    String selectedEmployeeId = _employees.isEmpty ? '' : _employees.first.id;
    final baseSalaryController = TextEditingController();
    final overtimeController = TextEditingController(text: '0');
    final bonusController = TextEditingController(text: '0');
    final deductionsController = TextEditingController(text: '0');
    final taxController = TextEditingController(text: '0');
    final payPeriodStartController = TextEditingController(text: 'mm/dd/yyyy');
    final payPeriodEndController = TextEditingController(text: 'mm/dd/yyyy');
    final payDateController = TextEditingController(text: 'mm/dd/yyyy');
    final daysWorkedController = TextEditingController(text: '22');
    final hoursWorkedController = TextEditingController(text: '176');
    final notesController = TextEditingController();

    if (_employees.isNotEmpty) {
      baseSalaryController.text = _employees.first.baseSalary.toStringAsFixed(
        2,
      );
    }

    final created = await showGeneralDialog<_PayrollRecordItem>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AddPayroll',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.white,
                child: SizedBox(
                  width: 760,
                  height: double.infinity,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE6E2EF)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Add Payroll Record',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Employee *'),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: selectedEmployeeId.isEmpty
                                    ? null
                                    : selectedEmployeeId,
                                items: _employees
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e.id,
                                        child: Text(e.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  final employee = _employees.firstWhere(
                                    (e) => e.id == value,
                                  );
                                  setLocal(() {
                                    selectedEmployeeId = value;
                                    baseSalaryController.text = employee
                                        .baseSalary
                                        .toStringAsFixed(2);
                                  });
                                },
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _labeledTextField(
                                      'Base Salary *',
                                      baseSalaryController,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _labeledTextField(
                                      'Overtime',
                                      overtimeController,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _labeledTextField(
                                      'Bonus',
                                      bonusController,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _labeledTextField(
                                      'Deductions',
                                      deductionsController,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _labeledTextField(
                                      'Tax',
                                      taxController,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _labeledTextField(
                                      'Pay Period Start *',
                                      payPeriodStartController,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _labeledTextField(
                                      'Pay Period End *',
                                      payPeriodEndController,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _labeledTextField(
                                      'Pay Date *',
                                      payDateController,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _labeledTextField(
                                      'Days Worked',
                                      daysWorkedController,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _labeledTextField(
                                      'Hours Worked',
                                      hoursWorkedController,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _labeledTextField(
                                'Notes',
                                notesController,
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFE6E2EF)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Spacer(),
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                final employee = _employees.firstWhere(
                                  (e) => e.id == selectedEmployeeId,
                                  orElse: () => _EmployeeItem(
                                    id: 'EMP',
                                    name: 'Employee',
                                    role: 'STAFF',
                                    active: true,
                                  ),
                                );
                                final baseSalary =
                                    double.tryParse(
                                      baseSalaryController.text.trim(),
                                    ) ??
                                    0;
                                final overtime =
                                    double.tryParse(
                                      overtimeController.text.trim(),
                                    ) ??
                                    0;
                                final bonus =
                                    double.tryParse(
                                      bonusController.text.trim(),
                                    ) ??
                                    0;
                                final deductions =
                                    double.tryParse(
                                      deductionsController.text.trim(),
                                    ) ??
                                    0;
                                final tax =
                                    double.tryParse(
                                      taxController.text.trim(),
                                    ) ??
                                    0;
                                Navigator.pop(
                                  context,
                                  _PayrollRecordItem(
                                    id: 'PR${DateTime.now().millisecondsSinceEpoch}',
                                    employeeId: employee.id,
                                    employeeName: employee.name,
                                    paymentType: employee.paymentType,
                                    baseSalary: baseSalary,
                                    overtime: overtime,
                                    bonus: bonus,
                                    deductions: deductions,
                                    tax: tax,
                                    payPeriodStart: payPeriodStartController
                                        .text
                                        .trim(),
                                    payPeriodEnd: payPeriodEndController.text
                                        .trim(),
                                    payDate: payDateController.text.trim(),
                                    daysWorked:
                                        int.tryParse(
                                          daysWorkedController.text.trim(),
                                        ) ??
                                        0,
                                    hoursWorked:
                                        double.tryParse(
                                          hoursWorkedController.text.trim(),
                                        ) ??
                                        0,
                                    notes: notesController.text.trim(),
                                    status: 'Pending',
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB227D6),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Create Payroll Record'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(position: offset, child: child);
      },
    );

    baseSalaryController.dispose();
    overtimeController.dispose();
    bonusController.dispose();
    deductionsController.dispose();
    taxController.dispose();
    payPeriodStartController.dispose();
    payPeriodEndController.dispose();
    payDateController.dispose();
    daysWorkedController.dispose();
    hoursWorkedController.dispose();
    notesController.dispose();

    return created;
  }

  Future<_EmployeeItem?> _showEmployeeDialog({_EmployeeItem? existing}) async {
    final firstNameController = TextEditingController(
      text: existing?.firstName ?? '',
    );
    final lastNameController = TextEditingController(
      text: existing?.lastName ?? '',
    );
    final emailController = TextEditingController(text: existing?.email ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final positionController = TextEditingController(
      text: existing?.position ?? existing?.role ?? '',
    );
    final departmentController = TextEditingController(
      text: existing?.department ?? '',
    );
    String paymentType = existing?.paymentType.isNotEmpty == true
        ? existing!.paymentType
        : 'Monthly';
    final baseSalaryController = TextEditingController(
      text: existing == null ? '0' : existing.baseSalary.toStringAsFixed(2),
    );
    final hireDateController = TextEditingController(
      text: existing?.hireDate ?? 'mm/dd/yyyy',
    );
    final bankAccountController = TextEditingController(
      text: existing?.bankAccount ?? '',
    );
    final addressController = TextEditingController(
      text: existing?.address ?? '',
    );
    final emergencyContactController = TextEditingController(
      text: existing?.emergencyContact ?? '',
    );
    final emergencyPhoneController = TextEditingController(
      text: existing?.emergencyPhone ?? '',
    );
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final locationOptions = {
      _storeLocation.trim(),
      'Main Branch',
      'Warehouse',
      'Online',
    }.where((v) => v.isNotEmpty).toList();
    final selectedLocations = <String>{
      ...(existing?.assignedLocations ?? [locationOptions.first]),
    };

    final created = await showGeneralDialog<_EmployeeItem>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AddEmployee',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.white,
                child: SizedBox(
                  width: 760,
                  height: double.infinity,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE6E2EF)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              existing == null
                                  ? 'Add New Employee'
                                  : 'Edit Employee',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _labeledTextField(
                                      'First Name *',
                                      firstNameController,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _labeledTextField(
                                      'Last Name *',
                                      lastNameController,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _labeledTextField(
                                      'Email *',
                                      emailController,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _labeledTextField(
                                      'Phone',
                                      phoneController,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _labeledTextField(
                                      'Position *',
                                      positionController,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _labeledTextField(
                                      'Department *',
                                      departmentController,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Payment Type *'),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          initialValue: paymentType,
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Monthly',
                                              child: Text('Monthly'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Hourly',
                                              child: Text('Hourly'),
                                            ),
                                          ],
                                          onChanged: (v) => setLocal(
                                            () =>
                                                paymentType = v ?? paymentType,
                                          ),
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _labeledTextField(
                                      'Base Salary *',
                                      baseSalaryController,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _labeledTextField(
                                      'Hire Date *',
                                      hireDateController,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _labeledTextField(
                                      'Bank Account',
                                      bankAccountController,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _labeledTextField(
                                'Address',
                                addressController,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _labeledTextField(
                                      'Emergency Contact',
                                      emergencyContactController,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _labeledTextField(
                                      'Emergency Phone',
                                      emergencyPhoneController,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _labeledTextField(
                                'Notes',
                                notesController,
                                maxLines: 3,
                              ),
                              const SizedBox(height: 12),
                              const Text('Assigned Locations'),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFE6E2EF),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: locationOptions
                                      .map(
                                        (loc) => FilterChip(
                                          label: Text(loc),
                                          selected: selectedLocations.contains(
                                            loc,
                                          ),
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
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFE6E2EF)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Spacer(),
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                final firstName = firstNameController.text
                                    .trim();
                                final lastName = lastNameController.text.trim();
                                final fullName = '$firstName $lastName'.trim();
                                Navigator.pop(
                                  context,
                                  _EmployeeItem(
                                    id:
                                        existing?.id ??
                                        'E${DateTime.now().millisecondsSinceEpoch % 100000}',
                                    name: fullName.isEmpty
                                        ? 'Employee'
                                        : fullName,
                                    role: positionController.text.trim().isEmpty
                                        ? 'STAFF'
                                        : positionController.text
                                              .trim()
                                              .toUpperCase(),
                                    active: existing?.active ?? true,
                                    firstName: firstName,
                                    lastName: lastName,
                                    email: emailController.text.trim(),
                                    phone: phoneController.text.trim(),
                                    position: positionController.text.trim(),
                                    department: departmentController.text
                                        .trim(),
                                    paymentType: paymentType,
                                    baseSalary:
                                        double.tryParse(
                                          baseSalaryController.text.trim(),
                                        ) ??
                                        0,
                                    hireDate: hireDateController.text.trim(),
                                    bankAccount: bankAccountController.text
                                        .trim(),
                                    address: addressController.text.trim(),
                                    emergencyContact: emergencyContactController
                                        .text
                                        .trim(),
                                    emergencyPhone: emergencyPhoneController
                                        .text
                                        .trim(),
                                    notes: notesController.text.trim(),
                                    assignedLocations: selectedLocations
                                        .toList(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB227D6),
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                existing == null
                                    ? 'Create Employee'
                                    : 'Update Employee',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(position: offset, child: child);
      },
    );

    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    positionController.dispose();
    departmentController.dispose();
    baseSalaryController.dispose();
    hireDateController.dispose();
    bankAccountController.dispose();
    addressController.dispose();
    emergencyContactController.dispose();
    emergencyPhoneController.dispose();
    notesController.dispose();

    return created;
  }

  Widget _labeledTextField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
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
    final skuController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController(text: '0');
    bool active = true;

    return showGeneralDialog<_ServiceJobItem>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AddService',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.white,
                child: SizedBox(
                  width: 760,
                  height: double.infinity,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE6E2EF)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Add New Service',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Service Name *'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: titleController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter service name',
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text('SKU *'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: skuController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter SKU',
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text('Description'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: descriptionController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: 'Enter service description',
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text('Default Price *'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: priceController,
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'This is the suggested price. Actual price can be customized at checkout.',
                                style: TextStyle(color: Color(0xFF7E8495)),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Checkbox(
                                    value: active,
                                    onChanged: (v) =>
                                        setLocal(() => active = v ?? true),
                                  ),
                                  const Text(
                                    'Active (available in POS)',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8F4FB),
                          border: Border(
                            top: BorderSide(color: Color(0xFFE6E2EF)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Spacer(),
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(
                                  context,
                                  _ServiceJobItem(
                                    id: 'SRV${DateTime.now().millisecondsSinceEpoch}',
                                    title: titleController.text.trim(),
                                    sku: skuController.text.trim(),
                                    description: descriptionController.text
                                        .trim(),
                                    defaultPrice:
                                        double.tryParse(
                                          priceController.text.trim(),
                                        ) ??
                                        0,
                                    active: active,
                                    technician: '',
                                    warranty: false,
                                    status: 'PENDING',
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB227D6),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Create Service'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(position: offset, child: child);
      },
    );
  }

  Future<_ServiceJobItem?> _showJobCardDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final scheduledDateController = TextEditingController();
    final scheduledTimeController = TextEditingController();
    final durationController = TextEditingController(text: '0');
    final locationController = TextEditingController();
    final deviceInfoController = TextEditingController();
    final discountController = TextEditingController(text: '0');
    final taxController = TextEditingController(text: '0');
    final internalNotesController = TextEditingController();
    final customerNotesController = TextEditingController();
    final tagsController = TextEditingController();

    final serviceControllers = [TextEditingController()];
    final materialControllers = [TextEditingController()];
    String selectedPriority = 'NORMAL';
    String selectedCustomerId = _customers.isNotEmpty
        ? _customers.first.id
        : '';

    if (_customers.isNotEmpty) {
      final first = _customers.first;
      phoneController.text = first.phone;
      emailController.text = first.email;
    }

    final created = await showGeneralDialog<_ServiceJobItem>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CreateJobCard',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.white,
                child: SizedBox(
                  width: 760,
                  height: double.infinity,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE6E2EF)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Create New Job Card',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Basic Information',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: titleController,
                                decoration: const InputDecoration(
                                  labelText: 'Title *',
                                  hintText:
                                      'e.g., AC Installation, Laptop Repair',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: descriptionController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  hintText: 'Brief description of the job',
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Customer Information',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                initialValue: selectedCustomerId.isEmpty
                                    ? null
                                    : selectedCustomerId,
                                decoration: const InputDecoration(
                                  labelText: 'Customer *',
                                  border: OutlineInputBorder(),
                                ),
                                items: _customers
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  final selected = _customers.firstWhere(
                                    (c) => c.id == value,
                                  );
                                  setLocal(() {
                                    selectedCustomerId = value;
                                    phoneController.text = selected.phone;
                                    emailController.text = selected.email;
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: phoneController,
                                      decoration: const InputDecoration(
                                        labelText: 'Phone',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: emailController,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Services *',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              ...serviceControllers.map((controller) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(
                                      hintText: 'Service name',
                                    ),
                                  ),
                                );
                              }),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setLocal(() {
                                      serviceControllers.add(
                                        TextEditingController(),
                                      );
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFB227D6),
                                    side: const BorderSide(
                                      color: Color(0xFFB227D6),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Service'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text('Materials (Optional)'),
                              const SizedBox(height: 8),
                              ...materialControllers.map((controller) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(
                                      hintText: 'Material name',
                                    ),
                                  ),
                                );
                              }),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setLocal(() {
                                      materialControllers.add(
                                        TextEditingController(),
                                      );
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFB227D6),
                                    side: const BorderSide(
                                      color: Color(0xFFB227D6),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Material'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Scheduling & Assignment',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: selectedPriority,
                                      decoration: const InputDecoration(
                                        labelText: 'Priority',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'NORMAL',
                                          child: Text('Normal'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'LOW',
                                          child: Text('Low'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'MEDIUM',
                                          child: Text('Medium'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'HIGH',
                                          child: Text('High'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setLocal(() {
                                          selectedPriority = value ?? 'NORMAL';
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: scheduledDateController,
                                      decoration: const InputDecoration(
                                        labelText: 'Scheduled Date',
                                        hintText: 'mm/dd/yyyy',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: scheduledTimeController,
                                      decoration: const InputDecoration(
                                        labelText: 'Scheduled Time',
                                        hintText: '--:--',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: durationController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Estimated Duration (minutes)',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: locationController,
                                      decoration: const InputDecoration(
                                        labelText: 'Location',
                                        hintText: 'e.g., Workshop, On-site',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: deviceInfoController,
                                      decoration: const InputDecoration(
                                        labelText: 'Device/Asset Info',
                                        hintText: 'model, serial number, etc.',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Cost Adjustments',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: discountController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Discount',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: taxController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Tax',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F3FB),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE6E2EF),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _summaryLine('Services', 0),
                                    _summaryLine('Materials', 0),
                                    _summaryLine(
                                      'Discount',
                                      -(double.tryParse(
                                            discountController.text.trim(),
                                          ) ??
                                          0),
                                    ),
                                    _summaryLine(
                                      'Tax',
                                      double.tryParse(
                                            taxController.text.trim(),
                                          ) ??
                                          0,
                                    ),
                                    const Divider(),
                                    Row(
                                      children: [
                                        const Text(
                                          'Total',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _money(
                                            (double.tryParse(
                                                      taxController.text.trim(),
                                                    ) ??
                                                    0) -
                                                (double.tryParse(
                                                      discountController.text
                                                          .trim(),
                                                    ) ??
                                                    0),
                                          ),
                                          style: const TextStyle(
                                            color: Color(0xFFB227D6),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Notes',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: internalNotesController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Internal Notes',
                                  hintText: 'Notes for internal use only',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: customerNotesController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Customer Notes',
                                  hintText: 'Notes visible to customer',
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: tagsController,
                                      decoration: const InputDecoration(
                                        labelText: 'Tags',
                                        hintText: 'Add a tag',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton(
                                    onPressed: () {},
                                    child: const Text('Add'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFE6E2EF)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Spacer(),
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                final selectedCustomer = _customers.firstWhere(
                                  (c) => c.id == selectedCustomerId,
                                  orElse: () => _CustomerItem(
                                    id: 'WALKIN',
                                    name: 'Walk-in Customer',
                                    phone: phoneController.text.trim(),
                                    email: emailController.text.trim(),
                                  ),
                                );

                                final services = serviceControllers
                                    .map((c) => c.text.trim())
                                    .where((s) => s.isNotEmpty)
                                    .toList();
                                final materials = materialControllers
                                    .map((c) => c.text.trim())
                                    .where((s) => s.isNotEmpty)
                                    .toList();
                                final discount =
                                    double.tryParse(
                                      discountController.text.trim(),
                                    ) ??
                                    0;
                                final tax =
                                    double.tryParse(
                                      taxController.text.trim(),
                                    ) ??
                                    0;
                                final total = (0 - discount) + tax;

                                Navigator.pop(
                                  context,
                                  _ServiceJobItem(
                                    id: 'JOB${DateTime.now().millisecondsSinceEpoch}',
                                    title: titleController.text.trim().isEmpty
                                        ? 'Service Job'
                                        : titleController.text.trim(),
                                    sku:
                                        'JC-${DateTime.now().millisecondsSinceEpoch % 100000}',
                                    description: descriptionController.text
                                        .trim(),
                                    defaultPrice: total,
                                    active: true,
                                    technician: '',
                                    warranty: false,
                                    status: 'OPEN',
                                    priority: selectedPriority,
                                    customerName: selectedCustomer.name,
                                    customerPhone: phoneController.text.trim(),
                                    customerEmail: emailController.text.trim(),
                                    scheduledDate: scheduledDateController.text
                                        .trim(),
                                    scheduledTime: scheduledTimeController.text
                                        .trim(),
                                    estimatedDurationMinutes: durationController
                                        .text
                                        .trim(),
                                    location: locationController.text.trim(),
                                    deviceInfo: deviceInfoController.text
                                        .trim(),
                                    discount: discount,
                                    taxAmount: tax,
                                    internalNotes: internalNotesController.text
                                        .trim(),
                                    customerNotes: customerNotesController.text
                                        .trim(),
                                    services: services,
                                    materials: materials,
                                    tags: tagsController.text.trim(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB227D6),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Create Job Card'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(position: offset, child: child);
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    phoneController.dispose();
    emailController.dispose();
    scheduledDateController.dispose();
    scheduledTimeController.dispose();
    durationController.dispose();
    locationController.dispose();
    deviceInfoController.dispose();
    discountController.dispose();
    taxController.dispose();
    internalNotesController.dispose();
    customerNotesController.dispose();
    tagsController.dispose();
    for (final controller in serviceControllers) {
      controller.dispose();
    }
    for (final controller in materialControllers) {
      controller.dispose();
    }

    return created;
  }

  Widget _summaryLine(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF666F87))),
          const Spacer(),
          Text(_money(value), style: const TextStyle(color: Color(0xFF5A6480))),
        ],
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
    final notesController = TextEditingController();
    final expectedDateController = TextEditingController(
      text: DateTime.now()
          .add(const Duration(days: 7))
          .toIso8601String()
          .split('T')
          .first,
    );
    final suppliers = _suppliers.isEmpty
        ? [
            _SupplierItem(
              id: 'SUP-FALLBACK',
              name: 'Astronauts',
              contact: '',
              email: '',
            ),
          ]
        : _suppliers;

    return showGeneralDialog<_PurchaseOrderItem>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CreateOrder',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        String selectedSupplier = suppliers.first.name;
        final items = <Map<String, dynamic>>[
          {
            'productId': _products.isEmpty ? '' : _products.first.id,
            'qtyController': TextEditingController(text: '1'),
            'priceController': TextEditingController(
              text: _products.isEmpty
                  ? '0'
                  : _products.first.price.toStringAsFixed(2),
            ),
          },
        ];

        return StatefulBuilder(
          builder: (context, setLocal) {
            double rowTotal(Map<String, dynamic> row) {
              final qty =
                  int.tryParse(
                    (row['qtyController'] as TextEditingController).text.trim(),
                  ) ??
                  0;
              final unitPrice =
                  double.tryParse(
                    (row['priceController'] as TextEditingController).text
                        .trim(),
                  ) ??
                  0;
              return qty * unitPrice;
            }

            double grandTotal() {
              return items.fold<double>(0, (sum, row) => sum + rowTotal(row));
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 120,
                vertical: 40,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: SizedBox(
                width: 860,
                height: 700,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE6E2EF)),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Create Order',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Supplier *'),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: selectedSupplier,
                              items: suppliers
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s.name,
                                      child: Text(s.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setLocal(() => selectedSupplier = v);
                              },
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Text('Items *'),
                                const Spacer(),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setLocal(() {
                                      items.add({
                                        'productId': _products.isEmpty
                                            ? ''
                                            : _products.first.id,
                                        'qtyController': TextEditingController(
                                          text: '1',
                                        ),
                                        'priceController':
                                            TextEditingController(
                                              text: _products.isEmpty
                                                  ? '0'
                                                  : _products.first.price
                                                        .toStringAsFixed(2),
                                            ),
                                      });
                                    });
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Item'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFE6E2EF),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: items.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final row = entry.value;
                                  final qtyController =
                                      row['qtyController']
                                          as TextEditingController;
                                  final priceController =
                                      row['priceController']
                                          as TextEditingController;
                                  final productId = row['productId'] as String;
                                  final selectedProduct = _products.firstWhere(
                                    (p) => p.id == productId,
                                    orElse: () => _products.isEmpty
                                        ? _ProductItem(
                                            id: '',
                                            name: 'No Product',
                                            category: '',
                                            price: 0,
                                            stock: 0,
                                            minStock: 0,
                                          )
                                        : _products.first,
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child:
                                              DropdownButtonFormField<String>(
                                                initialValue:
                                                    selectedProduct.id,
                                                items: _products
                                                    .map(
                                                      (p) => DropdownMenuItem(
                                                        value: p.id,
                                                        child: Text(
                                                          '${p.name} (${p.id})',
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                                onChanged: (v) {
                                                  if (v == null) return;
                                                  final product = _products
                                                      .firstWhere(
                                                        (p) => p.id == v,
                                                      );
                                                  setLocal(() {
                                                    row['productId'] = v;
                                                    priceController.text =
                                                        product.price
                                                            .toStringAsFixed(2);
                                                  });
                                                },
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'Product',
                                                    ),
                                              ),
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          width: 100,
                                          child: TextField(
                                            controller: qtyController,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Quantity',
                                            ),
                                            onChanged: (_) => setLocal(() {}),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          width: 120,
                                          child: TextField(
                                            controller: priceController,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Unit Price',
                                            ),
                                            onChanged: (_) => setLocal(() {}),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          width: 120,
                                          child: TextFormField(
                                            initialValue: rowTotal(
                                              row,
                                            ).toStringAsFixed(2),
                                            enabled: false,
                                            decoration: const InputDecoration(
                                              labelText: 'Total',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          onPressed: items.length <= 1
                                              ? null
                                              : () => setLocal(
                                                  () => items.removeAt(index),
                                                ),
                                          icon: const Icon(
                                            Icons.close,
                                            color: Color(0xFFE35D5D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text('Expected Delivery Date'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: expectedDateController,
                              decoration: const InputDecoration(
                                hintText: 'YYYY-MM-DD',
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text('Notes'),
                            const SizedBox(height: 6),
                            TextField(controller: notesController, maxLines: 4),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8F4FB),
                        border: Border(
                          top: BorderSide(color: Color(0xFFE6E2EF)),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Spacer(),
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              final total = grandTotal();
                              final count = items.fold<int>(
                                0,
                                (sum, row) =>
                                    sum +
                                    (int.tryParse(
                                          (row['qtyController']
                                                  as TextEditingController)
                                              .text
                                              .trim(),
                                        ) ??
                                        0),
                              );
                              Navigator.pop(
                                context,
                                _PurchaseOrderItem(
                                  id: 'PO${DateTime.now().millisecondsSinceEpoch}',
                                  supplier: selectedSupplier,
                                  itemsCount: count,
                                  amount: total,
                                  status: 'PENDING',
                                  expectedDate: expectedDateController.text
                                      .trim(),
                                  notes: notesController.text.trim(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB227D6),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Create Order'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
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
  final String subtitle;
  final String deltaText;
  final String deltaHint;
  final Color deltaColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle = '',
    this.deltaText = '+0.0%',
    this.deltaHint = 'vs last period',
    this.deltaColor = const Color(0xFF0B9F69),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF7A8093),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7EBFA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: const Color(0xFFB227D6), size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF242B3D),
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF646B7C),
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  text: deltaText,
                  style: TextStyle(
                    color: deltaColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  children: [
                    TextSpan(
                      text: '  $deltaHint',
                      style: const TextStyle(
                        color: Color(0xFF7A8093),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
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
  String vehicleNumber;
  String phone;
  String email;
  String address;
  String notes;
  double creditLimit;
  double currentBalance;
  int loyaltyPoints;

  _CustomerItem({
    required this.id,
    required this.name,
    this.vehicleNumber = '',
    required this.phone,
    required this.email,
    this.address = '',
    this.notes = '',
    this.creditLimit = 0,
    this.currentBalance = 0,
    this.loyaltyPoints = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'vehicleNumber': vehicleNumber,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'creditLimit': creditLimit,
      'currentBalance': currentBalance,
      'loyaltyPoints': loyaltyPoints,
    };
  }

  factory _CustomerItem.fromJson(Map<String, dynamic> json) {
    return _CustomerItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      vehicleNumber: (json['vehicleNumber'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      creditLimit: (json['creditLimit'] as num?)?.toDouble() ?? 0,
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0,
      loyaltyPoints: (json['loyaltyPoints'] as num?)?.toInt() ?? 0,
    );
  }
}

class _AttendanceRecordItem {
  final String id;
  String employeeId;
  String employeeName;
  DateTime date;
  String status;
  String clockIn;
  String clockOut;
  double regularHours;
  double overtimeHours;
  String notes;
  bool isHoliday;

  _AttendanceRecordItem({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.status,
    required this.clockIn,
    required this.clockOut,
    required this.regularHours,
    required this.overtimeHours,
    this.notes = '',
    this.isHoliday = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'date': date.toIso8601String(),
      'status': status,
      'clockIn': clockIn,
      'clockOut': clockOut,
      'regularHours': regularHours,
      'overtimeHours': overtimeHours,
      'notes': notes,
      'isHoliday': isHoliday,
    };
  }

  factory _AttendanceRecordItem.fromJson(Map<String, dynamic> json) {
    return _AttendanceRecordItem(
      id: (json['id'] ?? '').toString(),
      employeeId: (json['employeeId'] ?? '').toString(),
      employeeName: (json['employeeName'] ?? '').toString(),
      date:
          DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
      status: (json['status'] ?? 'Present').toString(),
      clockIn: (json['clockIn'] ?? '--:--').toString(),
      clockOut: (json['clockOut'] ?? '--:--').toString(),
      regularHours: (json['regularHours'] as num?)?.toDouble() ?? 0,
      overtimeHours: (json['overtimeHours'] as num?)?.toDouble() ?? 0,
      notes: (json['notes'] ?? '').toString(),
      isHoliday: json['isHoliday'] as bool? ?? false,
    );
  }
}

class _PayrollRecordItem {
  final String id;
  String employeeId;
  String employeeName;
  String paymentType;
  double baseSalary;
  double overtime;
  double bonus;
  double deductions;
  double tax;
  String payPeriodStart;
  String payPeriodEnd;
  String payDate;
  int daysWorked;
  double hoursWorked;
  String notes;
  String status;

  _PayrollRecordItem({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.paymentType,
    required this.baseSalary,
    this.overtime = 0,
    this.bonus = 0,
    this.deductions = 0,
    this.tax = 0,
    required this.payPeriodStart,
    required this.payPeriodEnd,
    required this.payDate,
    this.daysWorked = 0,
    this.hoursWorked = 0,
    this.notes = '',
    this.status = 'Pending',
  });

  double get grossPay => baseSalary + overtime + bonus;
  double get netPay => grossPay - deductions - tax;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'paymentType': paymentType,
      'baseSalary': baseSalary,
      'overtime': overtime,
      'bonus': bonus,
      'deductions': deductions,
      'tax': tax,
      'payPeriodStart': payPeriodStart,
      'payPeriodEnd': payPeriodEnd,
      'payDate': payDate,
      'daysWorked': daysWorked,
      'hoursWorked': hoursWorked,
      'notes': notes,
      'status': status,
    };
  }

  factory _PayrollRecordItem.fromJson(Map<String, dynamic> json) {
    return _PayrollRecordItem(
      id: (json['id'] ?? '').toString(),
      employeeId: (json['employeeId'] ?? '').toString(),
      employeeName: (json['employeeName'] ?? '').toString(),
      paymentType: (json['paymentType'] ?? 'Monthly').toString(),
      baseSalary: (json['baseSalary'] as num?)?.toDouble() ?? 0,
      overtime: (json['overtime'] as num?)?.toDouble() ?? 0,
      bonus: (json['bonus'] as num?)?.toDouble() ?? 0,
      deductions: (json['deductions'] as num?)?.toDouble() ?? 0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0,
      payPeriodStart: (json['payPeriodStart'] ?? '').toString(),
      payPeriodEnd: (json['payPeriodEnd'] ?? '').toString(),
      payDate: (json['payDate'] ?? '').toString(),
      daysWorked: (json['daysWorked'] as num?)?.toInt() ?? 0,
      hoursWorked: (json['hoursWorked'] as num?)?.toDouble() ?? 0,
      notes: (json['notes'] ?? '').toString(),
      status: (json['status'] ?? 'Pending').toString(),
    );
  }
}

class _EmployeeItem {
  final String id;
  String name;
  String role;
  bool active;
  String firstName;
  String lastName;
  String email;
  String phone;
  String position;
  String department;
  String paymentType;
  double baseSalary;
  String hireDate;
  String bankAccount;
  String address;
  String emergencyContact;
  String emergencyPhone;
  String notes;
  List<String> assignedLocations;

  _EmployeeItem({
    required this.id,
    required this.name,
    required this.role,
    required this.active,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.position = '',
    this.department = '',
    this.paymentType = 'Monthly',
    this.baseSalary = 0,
    this.hireDate = '',
    this.bankAccount = '',
    this.address = '',
    this.emergencyContact = '',
    this.emergencyPhone = '',
    this.notes = '',
    this.assignedLocations = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'active': active,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'position': position,
      'department': department,
      'paymentType': paymentType,
      'baseSalary': baseSalary,
      'hireDate': hireDate,
      'bankAccount': bankAccount,
      'address': address,
      'emergencyContact': emergencyContact,
      'emergencyPhone': emergencyPhone,
      'notes': notes,
      'assignedLocations': assignedLocations,
    };
  }

  factory _EmployeeItem.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString();
    final splitName = name.trim().split(RegExp(r'\s+'));
    final inferredFirst = splitName.isEmpty ? '' : splitName.first;
    final inferredLast = splitName.length <= 1
        ? ''
        : splitName.sublist(1).join(' ');
    return _EmployeeItem(
      id: (json['id'] ?? '').toString(),
      name: name,
      role: (json['role'] ?? 'CASHIER').toString(),
      active: json['active'] as bool? ?? true,
      firstName: (json['firstName'] ?? inferredFirst).toString(),
      lastName: (json['lastName'] ?? inferredLast).toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      position: (json['position'] ?? '').toString(),
      department: (json['department'] ?? '').toString(),
      paymentType: (json['paymentType'] ?? 'Monthly').toString(),
      baseSalary: (json['baseSalary'] as num?)?.toDouble() ?? 0,
      hireDate: (json['hireDate'] ?? '').toString(),
      bankAccount: (json['bankAccount'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      emergencyContact: (json['emergencyContact'] ?? '').toString(),
      emergencyPhone: (json['emergencyPhone'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      assignedLocations: (json['assignedLocations'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
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
  String sku;
  String description;
  double defaultPrice;
  bool active;
  String technician;
  bool warranty;
  String status;
  String priority;
  String customerName;
  String customerPhone;
  String customerEmail;
  String scheduledDate;
  String scheduledTime;
  String estimatedDurationMinutes;
  String location;
  String deviceInfo;
  double discount;
  double taxAmount;
  String internalNotes;
  String customerNotes;
  List<String> services;
  List<String> materials;
  String tags;

  _ServiceJobItem({
    required this.id,
    required this.title,
    this.sku = '',
    this.description = '',
    this.defaultPrice = 0,
    this.active = true,
    required this.technician,
    required this.warranty,
    required this.status,
    this.priority = 'NORMAL',
    this.customerName = '',
    this.customerPhone = '',
    this.customerEmail = '',
    this.scheduledDate = '',
    this.scheduledTime = '',
    this.estimatedDurationMinutes = '',
    this.location = '',
    this.deviceInfo = '',
    this.discount = 0,
    this.taxAmount = 0,
    this.internalNotes = '',
    this.customerNotes = '',
    this.services = const [],
    this.materials = const [],
    this.tags = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'sku': sku,
      'description': description,
      'defaultPrice': defaultPrice,
      'active': active,
      'technician': technician,
      'warranty': warranty,
      'status': status,
      'priority': priority,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'scheduledDate': scheduledDate,
      'scheduledTime': scheduledTime,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'location': location,
      'deviceInfo': deviceInfo,
      'discount': discount,
      'taxAmount': taxAmount,
      'internalNotes': internalNotes,
      'customerNotes': customerNotes,
      'services': services,
      'materials': materials,
      'tags': tags,
    };
  }

  factory _ServiceJobItem.fromJson(Map<String, dynamic> json) {
    return _ServiceJobItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      sku: (json['sku'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      defaultPrice: (json['defaultPrice'] as num?)?.toDouble() ?? 0,
      active: json['active'] as bool? ?? true,
      technician: (json['technician'] ?? '').toString(),
      warranty: json['warranty'] as bool? ?? false,
      status: (json['status'] ?? 'PENDING').toString(),
      priority: (json['priority'] ?? 'NORMAL').toString(),
      customerName: (json['customerName'] ?? '').toString(),
      customerPhone: (json['customerPhone'] ?? '').toString(),
      customerEmail: (json['customerEmail'] ?? '').toString(),
      scheduledDate: (json['scheduledDate'] ?? '').toString(),
      scheduledTime: (json['scheduledTime'] ?? '').toString(),
      estimatedDurationMinutes: (json['estimatedDurationMinutes'] ?? '')
          .toString(),
      location: (json['location'] ?? '').toString(),
      deviceInfo: (json['deviceInfo'] ?? '').toString(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
      internalNotes: (json['internalNotes'] ?? '').toString(),
      customerNotes: (json['customerNotes'] ?? '').toString(),
      services: (json['services'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      materials: (json['materials'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      tags: (json['tags'] ?? '').toString(),
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
  final String status;
  final String expectedDate;
  final String notes;

  _PurchaseOrderItem({
    required this.id,
    required this.supplier,
    required this.itemsCount,
    required this.amount,
    this.status = 'PENDING',
    this.expectedDate = '',
    this.notes = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplier': supplier,
      'itemsCount': itemsCount,
      'amount': amount,
      'status': status,
      'expectedDate': expectedDate,
      'notes': notes,
    };
  }

  factory _PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    return _PurchaseOrderItem(
      id: (json['id'] ?? '').toString(),
      supplier: (json['supplier'] ?? '').toString(),
      itemsCount: (json['itemsCount'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: (json['status'] ?? 'PENDING').toString(),
      expectedDate: (json['expectedDate'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
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
