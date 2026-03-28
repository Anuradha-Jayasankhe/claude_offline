import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../database/database.dart' as db;
import '../models/models.dart' as models;
import 'api_client.dart';

class SyncService {
  static const int _maxRetryCount = 6;
  final ApiClient _apiClient;
  final String tenantId;
  late final db.AppDatabase _database;

  SyncService(this._apiClient, this.tenantId) {
    _database = db.AppDatabase(tenantId);
  }

  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<bool> syncAllData() async {
    if (!await isOnline()) return false;

    try {
      // Download latest data from server
      await _downloadData();

      // Upload pending changes
      await _uploadPendingChanges();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _downloadData() async {
    final response = await _apiClient.get('/offline-sync/data');
    if (response.statusCode == 200) {
      final data = response.data;

      // Sync products
      if (data['products'] != null) {
        await _syncProducts(data['products']);
      }

      // Sync customers
      if (data['customers'] != null) {
        await _syncCustomers(data['customers']);
      }

      // Sync employees
      if (data['employees'] != null) {
        await _syncEmployees(data['employees']);
      }

      // Sync sales
      if (data['sales'] != null) {
        await _syncSales(data['sales']);
      }
      return;
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      message: 'Unexpected status code during download: ${response.statusCode}',
      type: DioExceptionType.badResponse,
    );
  }

  Future<void> _syncProducts(List<dynamic> productsData) async {
    for (final productData in productsData) {
      final product = models.Product.fromJson(productData);
      final existing = await _database.getProduct(product.id);

      if (existing == null) {
        await _database.insertProduct(product.toCompanion());
      } else {
        await _database.updateProduct(product.toCompanion());
      }
    }
  }

  Future<void> _syncCustomers(List<dynamic> customersData) async {
    for (final customerData in customersData) {
      final customer = models.Customer.fromJson(customerData);
      final existing = await _database.getCustomer(customer.id);

      if (existing == null) {
        await _database.insertCustomer(customer.toCompanion());
      } else {
        await _database.updateCustomer(customer.toCompanion());
      }
    }
  }

  Future<void> _syncEmployees(List<dynamic> employeesData) async {
    for (final employeeData in employeesData) {
      final employee = models.Employee.fromJson(employeeData);
      final existing = await _database.getEmployee(employee.id);

      if (existing == null) {
        await _database.insertEmployee(employee.toCompanion());
      } else {
        await _database.updateEmployee(employee.toCompanion());
      }
    }
  }

  Future<void> _syncSales(List<dynamic> salesData) async {
    for (final saleData in salesData) {
      final sale = models.Sale.fromJson(saleData);
      final existing = await _database.getSale(sale.id);

      if (existing == null) {
        await _database.insertSale(sale.toCompanion());
        // Insert sale items
        for (final item in sale.items) {
          await _database.insertSaleItem(item.toCompanion());
        }
      } else {
        await _database.updateSale(sale.toCompanion());
      }
    }
  }

  Future<void> _uploadPendingChanges() async {
    final pendingItems = await _database.getPendingSyncItems();

    for (final item in pendingItems) {
      if (item.retryCount >= _maxRetryCount) {
        // Keep in queue for manual conflict resolution review.
        continue;
      }

      if (!_isRetryWindowOpen(item)) {
        continue;
      }

      try {
        final data = jsonDecode(item.data);
        Response response;

        switch (item.operation) {
          case 'INSERT':
            response = await _apiClient.post(
              '/${item.entityTable}',
              data: data,
            );
            break;
          case 'UPDATE':
            response = await _apiClient.put(
              '/${item.entityTable}/${item.recordId}',
              data: data,
            );
            break;
          case 'DELETE':
            response = await _apiClient.delete(
              '/${item.entityTable}/${item.recordId}',
            );
            break;
          default:
            continue;
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Mark as synced and remove from queue
          await _database.deleteSyncItem(item.id);
        } else {
          // Increment retry count
          await _database.incrementRetryCount(item.id);
        }
      } on DioException catch (e) {
        // Treat conflict/validation/server errors as retriable queue entries.
        if (e.response?.statusCode == 409 ||
            e.response?.statusCode == 422 ||
            e.response?.statusCode == 500) {
          await _database.incrementRetryCount(item.id);
          continue;
        }

        await _database.incrementRetryCount(item.id);
      } catch (e) {
        await _database.incrementRetryCount(item.id);
      }
    }
  }

  bool _isRetryWindowOpen(db.SyncQueueData item) {
    if (item.retryCount <= 0) return true;

    final backoffSeconds = (5 * (1 << item.retryCount)).clamp(5, 300);
    final nextTryAt = item.createdAt.add(Duration(seconds: backoffSeconds));
    return DateTime.now().isAfter(nextTryAt);
  }

  Future<void> queueOperation(
    String operation,
    String entityTable,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    final syncItem = db.SyncQueueCompanion(
      operation: Value(operation),
      entityTable: Value(entityTable),
      recordId: Value(recordId),
      data: Value(jsonEncode(data)),
      createdAt: Value(DateTime.now()),
    );

    await _database.insertSyncItem(syncItem);
  }

  Future<List<db.SyncQueueData>> getPendingQueue() {
    return _database.getPendingSyncItems();
  }

  void dispose() {
    _database.close();
  }
}
