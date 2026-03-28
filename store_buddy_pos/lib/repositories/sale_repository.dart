import 'package:drift/drift.dart';

import '../database/database.dart' as db;
import '../models/models.dart' as models;
import '../services/sync_service.dart';

class SaleRepository {
  final db.AppDatabase _database;
  final SyncService? _syncService;

  SaleRepository(this._database, [this._syncService]);

  Future<List<models.Sale>> getAllSales() async {
    final sales = await _database.getAllSales();
    final mapped = <models.Sale>[];

    for (final s in sales) {
      final items = await _database.getSaleItems(s.id);
      mapped.add(
        models.Sale(
          id: s.id,
          tenantId: s.tenantId,
          customerId: s.customerId,
          employeeId: s.employeeId,
          total: s.total,
          tax: s.tax,
          discount: s.discount,
          paymentMethod: s.paymentMethod,
          status: s.status,
          locationId: s.locationId,
          synced: s.synced,
          createdAt: s.createdAt,
          updatedAt: s.updatedAt,
          items: items
              .map(
                (i) => models.SaleItem(
                  id: i.id,
                  saleId: i.saleId,
                  productId: i.productId,
                  productName: i.productName,
                  quantity: i.quantity,
                  unitPrice: i.unitPrice,
                  total: i.total,
                  tenantId: i.tenantId,
                ),
              )
              .toList(),
        ),
      );
    }

    return mapped;
  }

  Future<void> insertSale(models.Sale sale) async {
    await _database.insertSale(sale.toCompanion());
    for (final item in sale.items) {
      await _database.insertSaleItem(item.toCompanion());
    }

    if (_syncService != null) {
      await _syncService.queueOperation('INSERT', 'sales', sale.id, {
        'id': sale.id,
        'tenantId': sale.tenantId,
        'customerId': sale.customerId,
        'employeeId': sale.employeeId,
        'total': sale.total,
        'tax': sale.tax,
        'discount': sale.discount,
        'paymentMethod': sale.paymentMethod,
        'status': sale.status,
        'locationId': sale.locationId,
        'items': sale.items
            .map(
              (i) => {
                'id': i.id,
                'saleId': i.saleId,
                'productId': i.productId,
                'productName': i.productName,
                'quantity': i.quantity,
                'unitPrice': i.unitPrice,
                'total': i.total,
                'tenantId': i.tenantId,
              },
            )
            .toList(),
      });
    }
  }

  Future<void> updateSaleStatus({
    required String saleId,
    required String status,
  }) async {
    final sale = await _database.getSale(saleId);
    if (sale == null) return;

    await _database.updateSale(
      db.SalesCompanion(
        id: Value(sale.id),
        tenantId: Value(sale.tenantId),
        customerId: Value(sale.customerId),
        employeeId: Value(sale.employeeId),
        total: Value(sale.total),
        tax: Value(sale.tax),
        discount: Value(sale.discount),
        paymentMethod: Value(sale.paymentMethod),
        status: Value(status),
        locationId: Value(sale.locationId),
        synced: Value(sale.synced),
        createdAt: Value(sale.createdAt),
        updatedAt: Value(sale.updatedAt),
      ),
    );

    if (_syncService != null) {
      await _syncService.queueOperation('UPDATE', 'sales', saleId, {
        'id': saleId,
        'status': status,
      });
    }
  }
}
