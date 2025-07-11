# ht_data_mongodb

![coverage: xx%](https://img.shields.io/badge/coverage-XX-green)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![License: PolyForm Free Trial](https://img.shields.io/badge/License-PolyForm%20Free%20Trial-blue)](https://polyformproject.org/licenses/free-trial/1.0.0)

A production-ready MongoDB implementation of the `HtDataClient` interface, designed to connect Dart and Flutter applications to a MongoDB backend. This package is part of the Headlines Toolkit (HT) ecosystem.

## Description

`HtDataMongodb` provides a robust, concrete implementation of the `HtDataClient` interface using the `mongo_dart` package. It acts as the bridge between your application's repositories and a MongoDB database.

It translates the abstract, high-level data requests from the `HtDataClient` interface—including rich filters, multi-field sorting, and cursor-based pagination—into native, efficient MongoDB queries.

## Getting Started

This package is intended to be used as a dependency in backend services (like a Dart Frog API) or applications that connect directly to MongoDB.

To use this package, add `ht_data_mongodb` and its peer dependencies to your `pubspec.yaml`.

```yaml
dependencies:
  # ht_data_client defines the interface this package implements.
  ht_data_client:
    git:
      url: https://github.com/headlines-toolkit/ht-data-client.git
      # ref: <specific_commit_or_tag>
  # ht_shared is needed for models and exceptions.
  ht_shared:
    git:
      url: https://github.com/headlines-toolkit/ht-shared.git
      # ref: <specific_commit_or_tag>
  ht_data_mongodb:
    git:
      url: https://github.com/headlines-toolkit/ht-data-mongodb.git
      # ref: <specific_commit_or_tag>
```

Then run `dart pub get` or `flutter pub get`.

## Features

- Implements the `HtDataClient<T>` interface from `package:ht_data_client`.
- Includes `MongoDbConnectionManager` for robust connection lifecycle management.
- Translates `readAll` parameters (`filter`, `sort`, `pagination`) into native MongoDB queries.
- Automatically handles the mapping between your models' `String id` and MongoDB's `ObjectId _id`.
- Supports both user-scoped and global data operations.
- Throws standard exceptions from `package:ht_shared` for consistent error handling.

## Usage

Here's a basic example of how to use `HtDataMongodb` with a simple `Product` model.

```dart
import 'package:ht_data_client/ht_data_client.dart';
import 'package:ht_data_mongodb/ht_data_mongodb.dart';
import 'package:ht_shared/ht_shared.dart';

// 1. Define your model.
class Product {
  Product({required this.id, required this.name, required this.price});
  final String id;
  final String name;
  final double price;

  // Your fromJson/toJson factories.
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      price: json['price'] as double,
    );
  }
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};
}

void main() async {
  // 2. Set up the connection manager.
  final connectionManager = MongoDbConnectionManager();
  const connectionString = 'mongodb://localhost:27017/my_database';

  try {
    // 3. Initialize the database connection.
    await connectionManager.init(connectionString);

    // 4. Instantiate the client for your model.
    final client = HtDataMongodb<Product>(
      connectionManager: connectionManager,
      modelName: 'products', // The name of the MongoDB collection.
      fromJson: Product.fromJson,
      toJson: (product) => product.toJson(),
    );

    // 5. Use the client to perform operations.
    final filter = {
      'price': {r'$gte': 10.0} // Find products with price >= 10.0
    };
    final sort = [const SortOption('price', SortOrder.desc)];
    final pagination = const PaginationOptions(limit: 10);

    final response = await client.readAll(
      filter: filter,
      sort: sort,
      pagination: pagination,
    );

    print('Found ${response.data.items.length} products.');
    for (final product in response.data.items) {
      print('- ${product.name} (\$${product.price})');
    }
  } on HtHttpException catch (e) {
    print('An error occurred: ${e.message}');
  } finally {
    // 6. Always close the connection.
    await connectionManager.close();
  }
}
```

## License

This package is licensed under the PolyForm Free Trial 1.0.0. Please review the terms before use.