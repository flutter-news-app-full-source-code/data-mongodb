# data_mongodb

![coverage: xx%](https://img.shields.io/badge/coverage-91-green)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![License: PolyForm Free Trial](https://img.shields.io/badge/License-PolyForm%20Free%20Trial-blue)](https://polyformproject.org/licenses/free-trial/1.0.0)

A production-ready MongoDB implementation of the `DataClient` interface, designed to connect Dart and Flutter applications to a MongoDB backend. This package is part of the [**Flutter News App - Full Source Code Toolkit**](https://github.com/flutter-news-app-full-source-code).

## Description

`DataMongodb` provides a robust, concrete implementation of the `DataClient` interface using the `mongo_dart` package. It acts as the bridge between your application's repositories and a MongoDB database.

It translates the abstract, high-level data requests from the `DataClient` interface—including rich filters, multi-field sorting, and cursor-based pagination—into native, efficient MongoDB queries.

A key feature of this implementation is its **ID management strategy**. It ensures that the application layer remains the source of truth for a document's ID by mapping the model's `id` string to the database's `_id` field. This is crucial for correctly handling both global documents (like headlines) and user-owned documents (like settings), where the document's `_id` must match the user's ID. For a deeper explanation, see the documentation within the `DataMongodb` class.

## Getting Started

This package is intended to be used as a dependency in backend services (like a Dart Frog API) or applications that connect directly to MongoDB.

To use this package, add `data_mongodb` and its peer dependencies to your `pubspec.yaml`.

```yaml
dependencies:
  # data_client defines the interface this package implements.
  data_client:
    git:
      url: https://github.com/flutter-news-app-full-source-code/data-client.git
      # ref: <specific_commit_or_tag>
  # core is needed for models and exceptions.
  core:
    git:
      url: https://github.com/flutter-news-app-full-source-code/core.git
      # ref: <specific_commit_or_tag>
  data_mongodb:
    git:
      url: https://github.com/flutter-news-app-full-source-code/data-mongodb.git
      # ref: <specific_commit_or_tag>
```

Then run `dart pub get` or `flutter pub get`.

## Features

- Implements the `DataClient<T>` interface from `package:data_client`.
- Includes `MongoDbConnectionManager` for robust connection lifecycle management.
- Translates `readAll` parameters (`filter`, `sort`, `pagination`) into native MongoDB queries.
- **Handles ID Management**: Faithfully maps the application-level `id` string to the database `_id`, preserving data integrity for all document types.
- **Supports Multiple Data Models**: Correctly handles both global documents (e.g., `Headline`) and user-owned documents (e.g., `UserAppSettings`) where the document `_id` serves as the foreign key to the user.
- Throws standard exceptions from `package:core` for consistent error handling.
- Implements `count` for efficient document counting.
- Implements `aggregate` to execute powerful, server-side aggregation pipelines.
- **Partial Text Search**: Translates a `q` filter parameter into a case-insensitive (`$regex`) across designated searchable fields.

## Usage

Here's a basic example of how to use `DataMongodb` with a simple `Product` model.

```dart
import 'package:data_client/data_client.dart';
import 'package:data_mongodb/data_mongodb.dart';
import 'package:core/core.dart';

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
    final client = DataMongodb<Product>(
      connectionManager: connectionManager,
      modelName: 'products', // The name of the MongoDB collection.
      fromJson: Product.fromJson,
      toJson: (product) => product.toJson(),
      searchableFields: ['name'], // Designate 'name' for partial-text search.
    );

    // 5. Use the client to perform operations.
    // Example: Forgiving search for products with "pro" in their name.
    final searchResponse = await client.readAll(
      filter: {'q': 'pro'},
      pagination: const PaginationOptions(limit: 5),
    );
    print('\nFound ${searchResponse.data.items.length} products matching "pro":');
    for (final product in searchResponse.data.items) {
      print('- ${product.name}');
    }
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

    // Example: Counting items
    final countResponse = await client.count(
      filter: {'price': {r'$lt': 15.0}},
    );
    print('Found ${countResponse.data} products cheaper than $15.');

    // Example: Running an aggregation pipeline
    final aggregateResponse = await client.aggregate(
      pipeline: [
        {
          r'$group': {'_id': null, 'averagePrice': {r'$avg': r'$price'}},
        },
      ],
    );
    if (aggregateResponse.data.isNotEmpty) {
      print(
        'Average product price: \$${aggregateResponse.data.first['averagePrice']}',
      );
    }
  } on HttpException catch (e) {
    print('An error occurred: ${e.message}');
  } finally {
    // 6. Always close the connection.
    await connectionManager.close();
  }
}
```


## 🔑 Licensing

This package is source-available and licensed under the [PolyForm Free Trial 1.0.0](LICENSE). Please review the terms before use.

For commercial licensing options that grant the right to build and distribute unlimited applications, please visit the main [**Flutter News App - Full Source Code Toolkit**](https://github.com/flutter-news-app-full-source-code) organization.
