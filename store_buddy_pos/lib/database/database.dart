import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Products, Sales, SaleItems, Customers, Employees, SyncQueue],
)
class AppDatabase extends _$AppDatabase {
  final String tenantId;

  AppDatabase._internal(super.e, this.tenantId);

  static final Map<String, AppDatabase> _instances = {};

  factory AppDatabase(String tenantId) {
    if (_instances.containsKey(tenantId)) {
      return _instances[tenantId]!;
    }
    final db = AppDatabase._internal(_openConnection(tenantId), tenantId);
    _instances[tenantId] = db;
    return db;
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => await m.createAll(),
    onUpgrade: (m, from, to) async {
      // Handle migrations her
    },
  );

  static LazyDatabase _openConnection(String tenantId) {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'tenant_$tenantId.db'));
      return NativeDatabase(file);
    });
  }

  // Close database for a tenant
  static void closeDatabase(String tenantId) {
    final db = _instances.remove(tenantId);
    db?.close();
  }

  // Product operations
  Future<List<Product>> getAllProducts() => select(products).get();
  Future<Product?> getProduct(String id) =>
      (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();
  Future<int> insertProduct(ProductsCompanion product) =>
      into(products).insert(product);
  Future<bool> updateProduct(ProductsCompanion product) =>
      update(products).replace(product);
  Future<int> deleteProduct(String id) =>
      (delete(products)..where((p) => p.id.equals(id))).go();

  // Sale operations
  Future<List<Sale>> getAllSales() => select(sales).get();
  Future<Sale?> getSale(String id) =>
      (select(sales)..where((s) => s.id.equals(id))).getSingleOrNull();
  Future<int> insertSale(SalesCompanion sale) => into(sales).insert(sale);
  Future<bool> updateSale(SalesCompanion sale) => update(sales).replace(sale);

  // Sale items operations
  Future<List<SaleItem>> getSaleItems(String saleId) =>
      (select(saleItems)..where((si) => si.saleId.equals(saleId))).get();
  Future<int> insertSaleItem(SaleItemsCompanion item) =>
      into(saleItems).insert(item);

  // Customer operations
  Future<List<Customer>> getAllCustomers() => select(customers).get();
  Future<Customer?> getCustomer(String id) =>
      (select(customers)..where((c) => c.id.equals(id))).getSingleOrNull();
  Future<int> insertCustomer(CustomersCompanion customer) =>
      into(customers).insert(customer);
  Future<bool> updateCustomer(CustomersCompanion customer) =>
      update(customers).replace(customer);

  // Employee operations
  Future<List<Employee>> getAllEmployees() => select(employees).get();
  Future<Employee?> getEmployee(String id) =>
      (select(employees)..where((e) => e.id.equals(id))).getSingleOrNull();
  Future<int> insertEmployee(EmployeesCompanion employee) =>
      into(employees).insert(employee);
  Future<bool> updateEmployee(EmployeesCompanion employee) =>
      update(employees).replace(employee);

  // Sync queue operations
  Future<List<SyncQueueData>> getPendingSyncItems() => (select(
    syncQueue,
  )..orderBy([(s) => OrderingTerm(expression: s.createdAt)])).get();
  Future<int> insertSyncItem(SyncQueueCompanion item) =>
      into(syncQueue).insert(item);
  Future<int> deleteSyncItem(int id) =>
      (delete(syncQueue)..where((s) => s.id.equals(id))).go();
  Future<int> incrementRetryCount(int id) async {
    final current = await (select(
      syncQueue,
    )..where((s) => s.id.equals(id))).getSingle();
    return (update(syncQueue)..where((s) => s.id.equals(id))).write(
      SyncQueueCompanion(retryCount: Value(current.retryCount + 1)),
    );
  }
}
