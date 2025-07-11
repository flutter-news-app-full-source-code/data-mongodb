import 'package:equatable/equatable.dart';
import 'package:ht_data_mongodb/ht_data_mongodb.dart';
import 'package:ht_data_mongodb/src/mongo_db_connection_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';

// A simple model for testing purposes.
class Product extends Equatable {
  const Product({required this.id, required this.name, required this.price});

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      price: json['price'] as double,
    );
  }

  final String id;
  final String name;
  final double price;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};

  @override
  List<Object?> get props => [id, name, price];
}

// Mock classes for mongo_dart dependencies.
class MockMongoDbConnectionManager extends Mock
    implements MongoDbConnectionManager {}

class MockDb extends Mock implements Db {}

class MockDbCollection extends Mock implements DbCollection {}

void main() {
  group('HtDataMongodb', () {
    late HtDataMongodb<Product> client;
    late MockMongoDbConnectionManager mockConnectionManager;
    late MockDb mockDb;
    late MockDbCollection mockCollection;

    const modelName = 'products';

    setUp(() {
      mockConnectionManager = MockMongoDbConnectionManager();
      mockDb = MockDb();
      mockCollection = MockDbCollection();

      when(() => mockConnectionManager.db).thenReturn(mockDb);
      when(() => mockDb.collection(any())).thenReturn(mockCollection);

      client = HtDataMongodb<Product>(
        connectionManager: mockConnectionManager,
        modelName: modelName,
        fromJson: Product.fromJson,
        toJson: (product) => product.toJson(),
      );
    });

    test('can be instantiated', () {
      expect(client, isA<HtDataMongodb<Product>>());
    });
  });
}