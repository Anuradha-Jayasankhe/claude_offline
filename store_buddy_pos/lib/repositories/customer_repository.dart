import '../database/database.dart' as db;
import '../models/models.dart' as models;
import '../services/sync_service.dart';

class CustomerRepository {
  final db.AppDatabase _database;
  final SyncService? _syncService;

  CustomerRepository(this._database, [this._syncService]);

  Future<List<models.Customer>> getAllCustomers() async {
    final customers = await _database.getAllCustomers();
    return customers
        .map(
          (c) => models.Customer(
            id: c.id,
            tenantId: c.tenantId,
            name: c.name,
            phone: c.phone,
            email: c.email,
            address: c.address,
            creditLimit: c.creditLimit,
            currentBalance: c.currentBalance,
            synced: c.synced,
            createdAt: c.createdAt,
            updatedAt: c.updatedAt,
          ),
        )
        .toList();
  }

  Future<void> insertCustomer(models.Customer customer) async {
    await _database.insertCustomer(customer.toCompanion());
    if (_syncService != null) {
      await _syncService.queueOperation('INSERT', 'customers', customer.id, {
        'id': customer.id,
        'tenantId': customer.tenantId,
        'name': customer.name,
        'phone': customer.phone,
        'email': customer.email,
        'address': customer.address,
        'creditLimit': customer.creditLimit,
        'currentBalance': customer.currentBalance,
      });
    }
  }

  Future<void> updateCustomer(models.Customer customer) async {
    await _database.updateCustomer(customer.toCompanion());
    if (_syncService != null) {
      await _syncService.queueOperation('UPDATE', 'customers', customer.id, {
        'id': customer.id,
        'tenantId': customer.tenantId,
        'name': customer.name,
        'phone': customer.phone,
        'email': customer.email,
        'address': customer.address,
        'creditLimit': customer.creditLimit,
        'currentBalance': customer.currentBalance,
      });
    }
  }

  Future<void> deleteCustomer(String id) async {
    await (_database.delete(
      _database.customers,
    )..where((c) => c.id.equals(id))).go();
    if (_syncService != null) {
      await _syncService.queueOperation('DELETE', 'customers', id, {'id': id});
    }
  }
}
