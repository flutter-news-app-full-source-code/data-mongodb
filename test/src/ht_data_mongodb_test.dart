import 'package:equatable/equatable.dart';
import 'package:ht_data_mongodb/ht_data_mongodb.dart';
import 'package:ht_data_mongodb/src/mongo_db_connection_manager.dart';
import 'package:ht_shared/ht_shared.dart';
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

// Mock for WriteResult as it's a concrete class from mongo_dart.
class MockWriteResult extends Mock implements WriteResult {}

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

    group('create', () {
      final newProduct = Product(
        id: ObjectId().oid,
        name: 'New Gadget',
        price: 99.99,
      );
      final newProductDoc = {'name': 'New Gadget', 'price': 99.99};
      final createdDoc = {
        '_id': ObjectId.fromHexString(newProduct.id),
        ...newProductDoc,
      };

      test('should create an item successfully', () async {
        // Arrange
        final writeResult = MockWriteResult();
        when(() => writeResult.isSuccess).thenReturn(true);
        when(() => writeResult.document).thenReturn(createdDoc);
        when(() => mockCollection.insertOne(any()))
            .thenAnswer((_) async => writeResult);

        // Act
        final response = await client.create(item: newProduct);

        // Assert
        expect(response.data, newProduct);
        verify(() => mockCollection.insertOne(newProductDoc)).called(1);
      });

      test('should create an item successfully with userId', () async {
        // Arrange
        const userId = 'user-123';
        final newProductDocWithUser = {...newProductDoc, 'userId': userId};
        final createdDocWithUser = {...createdDoc, 'userId': userId};

        final writeResult = MockWriteResult();
        when(() => writeResult.isSuccess).thenReturn(true);
        when(() => writeResult.document).thenReturn(createdDocWithUser);
        when(() => mockCollection.insertOne(any()))
            .thenAnswer((_) async => writeResult);

        // Act
        final response = await client.create(item: newProduct, userId: userId);

        // Assert
        expect(response.data, newProduct);
        verify(() => mockCollection.insertOne(newProductDocWithUser))
            .called(1);
      });

      test('should throw ServerException on database error', () async {
        // Arrange
        when(() => mockCollection.insertOne(any()))
            .thenThrow(Exception('DB connection failed'));

        // Act & Assert
        expect(
          () => client.create(item: newProduct),
          throwsA(isA<ServerException>()),
        );
      });

      test('should throw ServerException if write is not successful', () {
        // Arrange
        final writeResult = MockWriteResult();
        when(() => writeResult.isSuccess).thenReturn(false);
        when(() => writeResult.document).thenReturn(null);
        when(() => mockCollection.insertOne(any()))
            .thenAnswer((_) async => writeResult);

        // Act & Assert
        expect(() => client.create(item: newProduct),
            throwsA(isA<ServerException>()));
      });
    });
  });
}