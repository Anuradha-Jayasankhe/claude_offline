import 'package:drift/drift.dart';

import '../database/database.dart';

class Product {
  final String id;
  final String tenantId;
  final String name;
  final String? sku;
  final String? barcode;
  final double price;
  final double? costPrice;
  final String category;
  final String type; // 'PRODUCT' | 'SERVICE' | 'REPAIR'
  final String unitOfMeasure; // 'PIECE' | 'KG' | 'LITER' | 'METER'
  final double stock;
  final double minStock;
  final String? locationId;
  final bool synced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.tenantId,
    required this.name,
    this.sku,
    this.barcode,
    required this.price,
    this.costPrice,
    required this.category,
    required this.type,
    required this.unitOfMeasure,
    required this.stock,
    required this.minStock,
    this.locationId,
    required this.synced,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'] ?? json['id'],
      tenantId: json['tenantId'],
      name: json['name'],
      sku: json['sku'],
      barcode: json['barcode'],
      price: (json['price'] as num).toDouble(),
      costPrice: json['costPrice'] != null
          ? (json['costPrice'] as num).toDouble()
          : null,
      category: json['category'],
      type: json['type'],
      unitOfMeasure: json['unitOfMeasure'],
      stock: (json['stock'] as num).toDouble(),
      minStock: (json['minStock'] as num).toDouble(),
      locationId: json['locationId'],
      synced: json['synced'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  ProductsCompanion toCompanion() {
    return ProductsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      name: Value(name),
      sku: Value(sku),
      barcode: Value(barcode),
      price: Value(price),
      costPrice: Value(costPrice),
      category: Value(category),
      type: Value(type),
      unitOfMeasure: Value(unitOfMeasure),
      stock: Value(stock),
      minStock: Value(minStock),
      locationId: Value(locationId),
      synced: Value(synced),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'tenantId': tenantId,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'price': price,
      'costPrice': costPrice,
      'category': category,
      'type': type,
      'unitOfMeasure': unitOfMeasure,
      'stock': stock,
      'minStock': minStock,
      'locationId': locationId,
      'synced': synced,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class Sale {
  final String id;
  final String tenantId;
  final String? customerId;
  final String employeeId;
  final double total;
  final double tax;
  final double discount;
  final String paymentMethod; // 'CASH' | 'CARD' | 'CHEQUE' | 'INSTALLMENT'
  final String status; // 'COMPLETED' | 'RETURNED' | 'CANCELLED'
  final String locationId;
  final bool synced;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<SaleItem> items;
  final Customer? customer;

  Sale({
    required this.id,
    required this.tenantId,
    this.customerId,
    required this.employeeId,
    required this.total,
    required this.tax,
    required this.discount,
    required this.paymentMethod,
    required this.status,
    required this.locationId,
    required this.synced,
    this.createdAt,
    this.updatedAt,
    required this.items,
    this.customer,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['_id'] ?? json['id'],
      tenantId: json['tenantId'],
      customerId: json['customerId'],
      employeeId: json['employeeId'],
      total: (json['total'] as num).toDouble(),
      tax: (json['tax'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      paymentMethod: json['paymentMethod'],
      status: json['status'],
      locationId: json['locationId'],
      synced: json['synced'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      items:
          (json['items'] as List?)
              ?.map((item) => SaleItem.fromJson(item))
              .toList() ??
          [],
      customer: json['customer'] != null
          ? Customer.fromJson(json['customer'])
          : null,
    );
  }

  SalesCompanion toCompanion() {
    return SalesCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      customerId: Value(customerId),
      employeeId: Value(employeeId),
      total: Value(total),
      tax: Value(tax),
      discount: Value(discount),
      paymentMethod: Value(paymentMethod),
      status: Value(status),
      locationId: Value(locationId),
      synced: Value(synced),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }
}

class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double total;
  final String tenantId;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.tenantId,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id'],
      saleId: json['saleId'],
      productId: json['productId'],
      productName: json['productName'],
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      tenantId: json['tenantId'],
    );
  }

  SaleItemsCompanion toCompanion() {
    return SaleItemsCompanion(
      id: Value(id),
      saleId: Value(saleId),
      productId: Value(productId),
      productName: Value(productName),
      quantity: Value(quantity),
      unitPrice: Value(unitPrice),
      total: Value(total),
      tenantId: Value(tenantId),
    );
  }
}

class Customer {
  final String id;
  final String tenantId;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final double creditLimit;
  final double currentBalance;
  final bool synced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Customer({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    required this.creditLimit,
    required this.currentBalance,
    required this.synced,
    this.createdAt,
    this.updatedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['_id'] ?? json['id'],
      tenantId: json['tenantId'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      address: json['address'],
      creditLimit: (json['creditLimit'] as num).toDouble(),
      currentBalance: (json['currentBalance'] as num).toDouble(),
      synced: json['synced'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  CustomersCompanion toCompanion() {
    return CustomersCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      name: Value(name),
      phone: Value(phone),
      email: Value(email),
      address: Value(address),
      creditLimit: Value(creditLimit),
      currentBalance: Value(currentBalance),
      synced: Value(synced),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }
}

class Employee {
  final String id;
  final String tenantId;
  final String name;
  final String email;
  final String role; // 'OWNER' | 'MANAGER' | 'CASHIER' | 'TECHNICIAN'
  final String locationId;
  final bool synced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Employee({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.email,
    required this.role,
    required this.locationId,
    required this.synced,
    this.createdAt,
    this.updatedAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['_id'] ?? json['id'],
      tenantId: json['tenantId'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      locationId: json['locationId'],
      synced: json['synced'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  EmployeesCompanion toCompanion() {
    return EmployeesCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      name: Value(name),
      email: Value(email),
      role: Value(role),
      locationId: Value(locationId),
      synced: Value(synced),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }
}

class User {
  final String id;
  final String tenantId;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final String? token;
  final String? refreshToken;

  User({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.token,
    this.refreshToken,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'],
      tenantId: json['tenantId'] ?? '',
      name: json['name'],
      email: json['email'],
      role: json['role'],
      isActive: json['isActive'] ?? true,
      token: json['token'],
      refreshToken: json['refreshToken'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'tenantId': tenantId,
      'name': name,
      'email': email,
      'role': role,
      'isActive': isActive,
      'token': token,
      'refreshToken': refreshToken,
    };
  }
}
