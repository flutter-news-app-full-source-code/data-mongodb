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

    group('read', () {
      final productId = ObjectId();
      final product = Product(
        id: productId.oid,
        name: 'Existing Gadget',
        price: 49.99,
      );
      final productDoc = {
        '_id': productId,
        'name': 'Existing Gadget',
        'price': 49.99,
      };

      test('should read an item successfully by id', () async {
        // Arrange
        when(() => mockCollection.findOne(any()))
            .thenAnswer((_) async => productDoc);

        // Act
        final response = await client.read(id: productId.oid);

        // Assert
        expect(response.data, product);
        final captured =
            verify(() => mockCollection.findOne(captureAny())).captured.first;
        expect(captured, {'_id': productId});
      });

      test('should read an item successfully by id and userId', () async {
        // Arrange
        const userId = 'user-123';
        final productDocWithUser = {...productDoc, 'userId': userId};
        when(() => mockCollection.findOne(any()))
            .thenAnswer((_) async => productDocWithUser);

        // Act
        final response = await client.read(id: productId.oid, userId: userId);

        // Assert
        expect(response.data, product);
        final captured =
            verify(() => mockCollection.findOne(captureAny())).captured.first;
        expect(captured, {'_id': productId, 'userId': userId});
      });

      test('should throw BadRequestException for invalid id format', () {
        // Arrange
        const invalidId = 'not-an-object-id';

        // Act & Assert
        expect(
          () => client.read(id: invalidId),
          throwsA(isA<BadRequestException>()),
        );
        verifyNever(() => mockCollection.findOne(any()));
      });

      test('should throw NotFoundException if item does not exist', () {
        // Arrange
        when(() => mockCollection.findOne(any())).thenAnswer((_) async => null);

        // Act & Assert
        expect(() => client.read(id: productId.oid),
            throwsA(isA<NotFoundException>()));
      });
    });

    group('update', () {
      final productId = ObjectId();
      final updatedProduct = Product(
        id: productId.oid,
        name: 'Updated Gadget',
        price: 129.99,
      );
      final updatedProductDoc = {
        'name': 'Updated Gadget',
        'price': 129.99,
      };

      test('should update an item successfully', () async {
        // Arrange
        final writeResult = MockWriteResult();
        when(() => writeResult.nModified).thenReturn(1);
        when(() => mockCollection.replaceOne(any(), any()))
            .thenAnswer((_) async => writeResult);

        // Act
        final response =
            await client.update(id: productId.oid, item: updatedProduct);

        // Assert
        expect(response.data, updatedProduct);
        final captured =
            verify(() => mockCollection.replaceOne(captureAny(), captureAny()))
                .captured;
        expect(captured[0], {'_id': productId});
        expect(captured[1], updatedProductDoc);
      });

      test('should update a user-scoped item successfully', () async {
        // Arrange
        const userId = 'user-123';
        final updatedProductDocWithUser = {...updatedProductDoc, 'userId': userId};
        final writeResult = MockWriteResult();
        when(() => writeResult.nModified).thenReturn(1);
        when(() => mockCollection.replaceOne(any(), any()))
            .thenAnswer((_) async => writeResult);

        // Act
        final response = await client.update(
          id: productId.oid,
          item: updatedProduct,
          userId: userId,
        );

        // Assert
        expect(response.data, updatedProduct);
        final captured =
            verify(() => mockCollection.replaceOne(captureAny(), captureAny()))
                .captured;
        expect(captured[0], {'_id': productId, 'userId': userId});
        expect(captured[1], updatedProductDocWithUser);
      });

      test('should throw BadRequestException for invalid id format', () {
        // Arrange
        const invalidId = 'not-an-object-id';

        // Act & Assert
        expect(() => client.update(id: invalidId, item: updatedProduct),
            throwsA(isA<BadRequestException>()));
        verifyNever(() => mockCollection.replaceOne(any(), any()));
      });

      test('should throw NotFoundException if item to update does not exist',
          () {
        // Arrange
        final writeResult = MockWriteResult();
        when(() => writeResult.nModified).thenReturn(0);
        when(() => mockCollection.replaceOne(any(), any()))
            .thenAnswer((_) async => writeResult);

        // Act & Assert
        expect(() => client.update(id: productId.oid, item: updatedProduct),
            throwsA(isA<NotFoundException>()));
      });
    });

    group('delete', () {
      final productId = ObjectId();

      test('should delete an item successfully', () async {
        // Arrange
        final writeResult = MockWriteResult();
        when(() => writeResult.nRemoved).thenReturn(1);
        when(() => mockCollection.deleteOne(any()))
            .thenAnswer((_) async => writeResult);

        // Act
        await client.delete(id: productId.oid);

        // Assert
        final captured =
            verify(() => mockCollection.deleteOne(captureAny())).captured.first;
        expect(captured, {'_id': productId});
      });

      test('should delete a user-scoped item successfully', () async {
        // Arrange
        const userId = 'user-123';
        final writeResult = MockWriteResult();
        when(() => writeResult.nRemoved).thenReturn(1);
        when(() => mockCollection.deleteOne(any()))
            .thenAnswer((_) async => writeResult);

        // Act
        await client.delete(id: productId.oid, userId: userId);

        // Assert
        final captured =
            verify(() => mockCollection.deleteOne(captureAny())).captured.first;
        expect(captured, {'_id': productId, 'userId': userId});
      });

      test('should throw BadRequestException for invalid id format', () {
        // Arrange
        const invalidId = 'not-an-object-id';

        // Act & Assert
        expect(
          () => client.delete(id: invalidId),
          throwsA(isA<BadRequestException>()),
        );
        verifyNever(() => mockCollection.deleteOne(any()));
      });

      test('should throw NotFoundException if item to delete does not exist',
          () {
        // Arrange
        final writeResult = MockWriteResult();
        when(() => writeResult.nRemoved).thenReturn(0);
        when(() => mockCollection.deleteOne(any()))
            .thenAnswer((_) async => writeResult);

        // Act & Assert
        expect(() => client.delete(id: productId.oid),
            throwsA(isA<NotFoundException>()));
      });
    });
  });
}