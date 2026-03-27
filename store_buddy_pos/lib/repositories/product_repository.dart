import '../database/database.dart' as db;
import '../models/models.dart' as models;
import '../services/sync_service.dart';

class ProductRepository {
  final db.AppDatabase _database;
  final SyncService? _syncService;

  ProductRepository(this._database, [this._syncService]);

  Future<List<models.Product>> getAllProducts() async {
    final products = await _database.getAllProducts();
    return products
        .map(
          (p) => models.Product(
            id: p.id,
            tenantId: p.tenantId,
            name: p.name,
            sku: p.sku,
            barcode: p.barcode,
            price: p.price,
            costPrice: p.costPrice,
            category: p.category,
            type: p.type,
            unitOfMeasure: p.unitOfMeasure,
            stock: p.stock,
            minStock: p.minStock,
            locationId: p.locationId,
            synced: p.synced,
            createdAt: p.createdAt,
            updatedAt: p.updatedAt,
          ),
        )
        .toList();
  }

  Future<models.Product?> getProduct(String id) async {
    final product = await _database.getProduct(id);
    if (product != null) {
      return models.Product(
        id: product.id,
        tenantId: product.tenantId,
        name: product.name,
        sku: product.sku,
        barcode: product.barcode,
        price: product.price,
        costPrice: product.costPrice,
        category: product.category,
        type: product.type,
        unitOfMeasure: product.unitOfMeasure,
        stock: product.stock,
        minStock: product.minStock,
        locationId: product.locationId,
        synced: product.synced,
        createdAt: product.createdAt,
        updatedAt: product.updatedAt,
      );
    }
    return null;
  }

  Future<void> insertProduct(models.Product product) async {
    await _database.insertProduct(product.toCompanion());
    if (_syncService != null) {
      await _syncService.queueOperation(
        'INSERT',
        'products',
        product.id,
        product.toJson(),
      );
    }
  }

  Future<void> updateProduct(models.Product product) async {
    await _database.updateProduct(product.toCompanion());
    if (_syncService != null) {
      await _syncService.queueOperation(
        'UPDATE',
        'products',
        product.id,
        product.toJson(),
      );
    }
  }

  Future<void> deleteProduct(String id) async {
    await _database.deleteProduct(id);
    if (_syncService != null) {
      await _syncService.queueOperation('DELETE', 'products', id, {'id': id});
    }
  }
}
