// ignore_for_file: inference_failure_on_function_invocation, use_raw_strings, avoid_redundant_argument_values

import 'package:core/core.dart';
import 'package:data_mongodb/data_mongodb.dart';
import 'package:equatable/equatable.dart';
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
  group('DataMongodb', () {
    late DataMongodb<Product> client;
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

      client = DataMongodb<Product>(
        connectionManager: mockConnectionManager,
        modelName: modelName,
        fromJson: Product.fromJson,
        toJson: (product) => product.toJson(),
      );
    });

    test('can be instantiated', () {
      expect(client, isA<DataMongodb<Product>>());
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
        when(() => mockCollection.insertOne(any()))
            .thenAnswer((_) async => writeResult);
        // The implementation now fetches the doc after creation for verification
        when(() => mockCollection.findOne(any()))
            .thenAnswer((_) async => createdDoc);

        // Act
        final response = await client.create(item: newProduct);

        // Assert
        expect(response.data, newProduct);
        final capturedInsert =
            verify(() => mockCollection.insertOne(captureAny())).captured.first
                as Map<String, dynamic>;
        // Remove the '_id' as it's generated and not part of the original doc
        capturedInsert.remove('_id');
        expect(capturedInsert, newProductDoc);
        verify(() => mockCollection.findOne({'_id': createdDoc['_id']}))
            .called(1);
      });

      test('should ignore userId and create an item successfully', () async {
        // Arrange
        const userId = 'user-123';
        final writeResult = MockWriteResult();
        when(() => writeResult.isSuccess).thenReturn(true);
        when(() => mockCollection.insertOne(any()))
            .thenAnswer((_) async => writeResult);
        when(() => mockCollection.findOne(any()))
            .thenAnswer((_) async => createdDoc);

        // Act
        final response = await client.create(item: newProduct, userId: userId);

        // Assert
        expect(response.data, newProduct);
        final capturedInsert =
            verify(() => mockCollection.insertOne(captureAny())).captured.first
                as Map<String, dynamic>;
        capturedInsert.remove('_id');
        // The captured document should NOT contain the userId
        expect(capturedInsert, newProductDoc);
        verify(() => mockCollection.findOne({'_id': createdDoc['_id']}))
            .called(1);
      });

      test('should throw ServerException on database error', () async {
        // Arrange
        when(
          () => mockCollection.insertOne(any()),
        ).thenThrow(Exception('DB connection failed'));

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
        expect(
          () => client.create(item: newProduct),
          throwsA(isA<ServerException>()),
        );
      });

      test('should throw BadRequestException for invalid model ID on create',
          () {
        // Arrange
        final productWithInvalidId = Product(
          id: 'invalid-id',
          name: 'Invalid',
          price: 0,
        );

        // Act & Assert
        expect(
          () => client.create(item: productWithInvalidId),
          throwsA(isA<BadRequestException>()),
        );
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
        when(
          () => mockCollection.findOne(any()),
        ).thenAnswer((_) async => productDoc);

        // Act
        final response = await client.read(id: productId.oid);

        // Assert
        expect(response.data, product);
        final captured = verify(
          () => mockCollection.findOne(captureAny()),
        ).captured.first;
        expect(captured, {'_id': productId});
      });

      test('should ignore userId and read an item successfully by id',
          () async {
        // Arrange
        const userId = 'user-123';
        when(() => mockCollection.findOne(any()))
            .thenAnswer((_) async => productDoc);

        // Act
        final response = await client.read(id: productId.oid, userId: userId);

        // Assert
        expect(response.data, product);
        final captured =
            verify(() => mockCollection.findOne(captureAny())).captured.first;
        // The selector should NOT contain the userId
        expect(captured, {'_id': productId});
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
        expect(
          () => client.read(id: productId.oid),
          throwsA(isA<NotFoundException>()),
        );
      });

      test('should throw ServerException on database error', () {
        // Arrange
        when(
          () => mockCollection.findOne(any()),
        ).thenThrow(Exception('DB connection failed'));

        // Act & Assert
        expect(
          () => client.read(id: productId.oid),
          throwsA(isA<ServerException>()),
        );
      });
    });

    group('update', () {
      final productId = ObjectId();
      final updatedProduct = Product(
        id: productId.oid,
        name: 'Updated Gadget',
        price: 129.99,
      );
      final updatedProductDoc = {'name': 'Updated Gadget', 'price': 129.99};

      test('should update an item successfully', () async {
        // Arrange
        final updatedDocFromDb = {
          '_id': productId,
          ...updatedProductDoc,
        };
        when(() => mockCollection.findAndModify(
              query: any(named: 'query'),
              update: any(named: 'update'),
              returnNew: any(named: 'returnNew'),
            )).thenAnswer((_) async => updatedDocFromDb);

        // Act
        final response = await client.update(
          id: productId.oid,
          item: updatedProduct,
        );

        // Assert
        expect(response.data, updatedProduct);
        final captured = verify(() => mockCollection.findAndModify(
              query: captureAny(named: 'query'),
              update: captureAny(named: 'update'),
              returnNew: captureAny(named: 'returnNew'),
            )).captured;
        expect(captured[0], {'_id': productId});
        expect(captured[1], {r'$set': updatedProductDoc});
        expect(captured[2], isTrue);
      });

      test('should ignore userId and update an item successfully', () async {
        // Arrange
        const userId = 'user-123';
        final updatedDocFromDb = {
          '_id': productId,
          ...updatedProductDoc,
        };
        when(() => mockCollection.findAndModify(
              query: any(named: 'query'),
              update: any(named: 'update'),
              returnNew: any(named: 'returnNew'),
            )).thenAnswer((_) async => updatedDocFromDb);

        // Act
        final response = await client.update(
          id: productId.oid,
          item: updatedProduct,
          userId: userId,
        );

        // Assert
        expect(response.data, updatedProduct);
        final captured = verify(() => mockCollection.findAndModify(
              query: captureAny(named: 'query'),
              update: captureAny(named: 'update'),
              returnNew: captureAny(named: 'returnNew'),
            )).captured;
        // The query should NOT contain the userId
        expect(captured[0], {'_id': productId});
        expect(captured[1], {r'$set': updatedProductDoc});
        expect(captured[2], isTrue);
      });

      test('should throw BadRequestException for invalid id format', () {
        // Arrange
        const invalidId = 'not-an-object-id';

        // Act & Assert
        expect(
          () => client.update(id: invalidId, item: updatedProduct),
          throwsA(isA<BadRequestException>()),
        );
        verifyNever(() => mockCollection.findAndModify(
              query: any(named: 'query'),
              update: any(named: 'update'),
              returnNew: any(named: 'returnNew'),
            ));
      });

      test(
        'should throw NotFoundException if item to update does not exist',
        () {
          // Arrange
          when(() => mockCollection.findAndModify(
                query: any(named: 'query'),
                update: any(named: 'update'),
                returnNew: any(named: 'returnNew'),
              )).thenAnswer((_) async => null);

          // Act & Assert
          expect(
            () => client.update(id: productId.oid, item: updatedProduct),
            throwsA(isA<NotFoundException>()),
          );
        },
      );

      test('should throw ServerException on database error', () {
        // Arrange
        when(() => mockCollection.findAndModify(
              query: any(named: 'query'),
              update: any(named: 'update'),
              returnNew: any(named: 'returnNew'),
            )).thenThrow(Exception('DB connection failed'));

        // Act & Assert
        expect(
          () => client.update(id: productId.oid, item: updatedProduct),
          throwsA(isA<ServerException>()),
        );
      });

      test('should throw BadRequestException for invalid model ID on update',
          () {
        // Arrange
        final productWithInvalidId = Product(
          id: 'invalid-id',
          name: 'Invalid',
          price: 0,
        );

        // Act & Assert
        expect(
          () => client.update(id: productId.oid, item: productWithInvalidId),
          throwsA(isA<BadRequestException>()),
        );
      });
    });

    group('delete', () {
      final productId = ObjectId();

      test('should delete an item successfully', () async {
        // Arrange
        final writeResult = MockWriteResult();
        when(() => writeResult.nRemoved).thenReturn(1);
        when(
          () => mockCollection.deleteOne(any()),
        ).thenAnswer((_) async => writeResult);

        // Act
        await client.delete(id: productId.oid);

        // Assert
        final captured = verify(
          () => mockCollection.deleteOne(captureAny()),
        ).captured.first;
        expect(captured, {'_id': productId});
      });

      test('should ignore userId and delete an item successfully', () async {
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
        // The selector should NOT contain the userId
        expect(captured, {'_id': productId});
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

      test(
        'should throw NotFoundException if item to delete does not exist',
        () {
          // Arrange
          final writeResult = MockWriteResult();
          when(() => writeResult.nRemoved).thenReturn(0);
          when(
            () => mockCollection.deleteOne(any()),
          ).thenAnswer((_) async => writeResult);

          // Act & Assert
          expect(
            () => client.delete(id: productId.oid),
            throwsA(isA<NotFoundException>()),
          );
        },
      );

      test('should throw ServerException on database error', () {
        // Arrange
        when(
          () => mockCollection.deleteOne(any()),
        ).thenThrow(Exception('DB connection failed'));

        // Act & Assert
        expect(
          () => client.delete(id: productId.oid),
          throwsA(isA<ServerException>()),
        );
      });
    });

    group('readAll', () {
      // Helper to create a list of product documents for mocking.
      List<Map<String, dynamic>> createProductDocs(int count) {
        return List.generate(count, (i) {
          final id = ObjectId();
          return {'_id': id, 'name': 'Product $i', 'price': 10.0 + i};
        });
      }

      // Helper to set up the mock for the find operation.
      void setupMockFind(List<Map<String, dynamic>> docs) {
        // The `modernFind` method returns a stream-like object. We mock it to return
        // a stream created from our list of mock documents.
        when(
          () => mockCollection.modernFind(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            skip: any(named: 'skip'),
            projection: any(named: 'projection'),
            hint: any(named: 'hint'),
            hintDocument: any(named: 'hintDocument'),
            findOptions: any(named: 'findOptions'),
            rawOptions: any(named: 'rawOptions'),
          ),
        ).thenAnswer((_) => Stream.fromIterable(docs));
      }

      test('should return all items when no parameters are provided', () async {
        // Arrange
        final productDocs = createProductDocs(3);
        setupMockFind(productDocs);

        // Act
        final response = await client.readAll();

        // Assert
        expect(response.data.items.length, 3);
        expect(response.data.hasMore, isFalse);
        expect(response.data.cursor, isNull);
        expect(response.data.items[0].name, 'Product 0');
        expect(response.data.items[1].name, 'Product 1');
        expect(response.data.items[2].name, 'Product 2');

        // Verify that the correct arguments were passed to modernFind().
        final captured = verify(
          () => mockCollection.modernFind(
            filter: captureAny(named: 'filter'),
            sort: captureAny(named: 'sort'),
            limit: captureAny(named: 'limit'),
            skip: any(named: 'skip'),
            projection: any(named: 'projection'),
            hint: any(named: 'hint'),
            hintDocument: any(named: 'hintDocument'),
            findOptions: any(named: 'findOptions'),
            rawOptions: any(named: 'rawOptions'),
          ),
        ).captured;

        final filterArg = captured[0] as Map<String, dynamic>?;
        final sortArg = captured[1] as Map<String, int>?;
        final limitArg = captured[2] as int?;

        expect(filterArg, isEmpty);
        expect(sortArg, {'_id': 1});
        expect(limitArg, 21);
      });

      test('should ignore userId and apply filter correctly', () async {
        // Arrange
        final productDocs = createProductDocs(2);
        setupMockFind(productDocs);
        const userId = 'user-abc';

        // Act
        await client.readAll(userId: userId);

        // Assert
        final captured = verify(
          () => mockCollection.modernFind(
            filter: captureAny(named: 'filter'),
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            skip: any(named: 'skip'),
            projection: any(named: 'projection'),
            hint: any(named: 'hint'),
            hintDocument: any(named: 'hintDocument'),
            findOptions: any(named: 'findOptions'),
            rawOptions: any(named: 'rawOptions'),
          ),
        ).captured;
        // The filter should be empty because userId is ignored
        expect(captured.first, isEmpty);
      });

      test('should apply complex filter correctly', () async {
        // Arrange
        final productDocs = createProductDocs(1);
        setupMockFind(productDocs);
        final filter = {
          'price': {r'$gte': 12.0},
        };

        // Act
        await client.readAll(filter: filter);

        // Assert
        final captured = verify(
          () => mockCollection.modernFind(
            filter: captureAny(named: 'filter'),
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            skip: any(named: 'skip'),
            projection: any(named: 'projection'),
            hint: any(named: 'hint'),
            hintDocument: any(named: 'hintDocument'),
            findOptions: any(named: 'findOptions'),
            rawOptions: any(named: 'rawOptions'),
          ),
        ).captured;
        expect(captured.first, {
          'price': {r'$gte': 12.0},
        });
      });

      test('should ignore userId and apply complex filter correctly', () async {
        // Arrange
        final productDocs = createProductDocs(1);
        setupMockFind(productDocs);
        const userId = 'user-abc';
        final filter = {
          'price': {r'$gte': 12.0},
        };

        // Act
        await client.readAll(userId: userId, filter: filter);

        // Assert
        final captured = verify(
          () => mockCollection.modernFind(
            filter: captureAny(named: 'filter'),
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            skip: any(named: 'skip'),
            projection: any(named: 'projection'),
            hint: any(named: 'hint'),
            hintDocument: any(named: 'hintDocument'),
            findOptions: any(named: 'findOptions'),
            rawOptions: any(named: 'rawOptions'),
          ),
        ).captured;
        // The filter should NOT contain the userId
        expect(captured.first, {
          'price': {r'$gte': 12.0},
        });
      });

      test('should apply search query correctly', () async {
        // Arrange
        final searchableClient = DataMongodb<Product>(
          connectionManager: mockConnectionManager,
          modelName: modelName,
          fromJson: Product.fromJson,
          toJson: (product) => product.toJson(),
          searchableFields: ['name'],
        );
        setupMockFind([]);
        final filter = {'q': 'Gadget'};

        // Act
        await searchableClient.readAll(filter: filter);

        // Assert
        final captured = verify(
          () => mockCollection.modernFind(
            filter: captureAny(named: 'filter'),
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            skip: any(named: 'skip'),
            projection: any(named: 'projection'),
            hint: any(named: 'hint'),
            hintDocument: any(named: 'hintDocument'),
            findOptions: any(named: 'findOptions'),
            rawOptions: any(named: 'rawOptions'),
          ),
        ).captured;
        expect(captured.first, {
          r'$and': [
            {},
            {
              r'$or': [
                {
                  'name': {r'$regex': 'Gadget', r'$options': 'i'},
                }
              ],
            }
          ],
        });
      });

      test('should apply a single sort option correctly', () async {
        // Arrange
        final productDocs = createProductDocs(2);
        setupMockFind(productDocs);
        final sort = [const SortOption('price', SortOrder.desc)];

        // Act
        await client.readAll(sort: sort);

        // Assert
        final captured = verify(
          () => mockCollection.modernFind(
            filter: any(named: 'filter'),
            sort: captureAny(named: 'sort'),
            limit: any(named: 'limit'),
            skip: any(named: 'skip'),
            projection: any(named: 'projection'),
            hint: any(named: 'hint'),
            hintDocument: any(named: 'hintDocument'),
            findOptions: any(named: 'findOptions'),
            rawOptions: any(named: 'rawOptions'),
          ),
        ).captured;
        expect(captured.first, {'price': -1, '_id': 1});
      });

      test('should apply multiple sort options correctly', () async {
        // Arrange
        final productDocs = createProductDocs(2);
        setupMockFind(productDocs);
        final sort = [
          const SortOption('name', SortOrder.asc),
          const SortOption('price', SortOrder.desc),
        ];

        // Act
        await client.readAll(sort: sort);

        // Assert
        final captured = verify(
          () => mockCollection.modernFind(
            filter: any(named: 'filter'),
            sort: captureAny(named: 'sort'),
            limit: any(named: 'limit'),
            skip: any(named: 'skip'),
            projection: any(named: 'projection'),
            hint: any(named: 'hint'),
            hintDocument: any(named: 'hintDocument'),
            findOptions: any(named: 'findOptions'),
            rawOptions: any(named: 'rawOptions'),
          ),
        ).captured;
        expect(captured.first, {'name': 1, 'price': -1, '_id': 1});
      });

      test(
        'should respect explicit _id sort order and not add a duplicate',
        () async {
          // Arrange
          final productDocs = createProductDocs(2);
          setupMockFind(productDocs);
          final sort = [
            const SortOption('price', SortOrder.asc),
            const SortOption('_id', SortOrder.desc), // Explicit _id sort
          ];

          // Act
          await client.readAll(sort: sort);

          // Assert
          final captured = verify(
            () => mockCollection.modernFind(
              filter: any(named: 'filter'),
              sort: captureAny(named: 'sort'),
              limit: any(named: 'limit'),
              skip: any(named: 'skip'),
              projection: any(named: 'projection'),
              hint: any(named: 'hint'),
              hintDocument: any(named: 'hintDocument'),
              findOptions: any(named: 'findOptions'),
              rawOptions: any(named: 'rawOptions'),
            ),
          ).captured;
          expect(captured.first, {'price': 1, '_id': -1});
        },
      );

      group('pagination', () {
        test(
          'should return paginated response with hasMore true when more items exist',
          () async {
            // Arrange
            final productDocs = createProductDocs(5); // 5 items in DB
            setupMockFind(productDocs);
            const pagination = PaginationOptions(limit: 3);

            // Act
            final response = await client.readAll(pagination: pagination);

            // Assert
            expect(response.data.items.length, 3);
            expect(response.data.hasMore, isTrue);
            expect(response.data.cursor, isNotNull);
            expect(
              response.data.cursor,
              (productDocs[2]['_id']! as ObjectId).oid,
            );

            final captured = verify(
              () => mockCollection.modernFind(
                filter: any(named: 'filter'),
                sort: any(named: 'sort'),
                limit: captureAny(named: 'limit'),
                skip: any(named: 'skip'),
                projection: any(named: 'projection'),
                hint: any(named: 'hint'),
                hintDocument: any(named: 'hintDocument'),
                findOptions: any(named: 'findOptions'),
                rawOptions: any(named: 'rawOptions'),
              ),
            ).captured;
            expect(captured.first, 4); // limit (3) + 1
          },
        );

        test(
          'should return paginated response with hasMore false when items match limit',
          () async {
            // Arrange
            final productDocs = createProductDocs(3); // 3 items in DB
            setupMockFind(productDocs);
            const pagination = PaginationOptions(limit: 3);

            // Act
            final response = await client.readAll(pagination: pagination);

            // Assert
            expect(response.data.items.length, 3);
            expect(response.data.hasMore, isFalse);
            expect(response.data.cursor, isNull);
          },
        );

        test(
          'should return paginated response with hasMore false when items are less than limit',
          () async {
            // Arrange
            final productDocs = createProductDocs(2); // 2 items in DB
            setupMockFind(productDocs);
            const pagination = PaginationOptions(limit: 3);

            // Act
            final response = await client.readAll(pagination: pagination);

            // Assert
            expect(response.data.items.length, 2);
            expect(response.data.hasMore, isFalse);
            expect(response.data.cursor, isNull);
          },
        );

        test('should fetch the next page correctly using a cursor', () async {
          // --- ARRANGE ---
          final productDocs = createProductDocs(5); // Total 5 items
          const limit = 2;

          // --- FIRST CALL ---
          // Mock find() to return the first page + 1 extra item
          setupMockFind(productDocs.take(limit + 1).toList());
          final firstResponse = await client.readAll(
            pagination: const PaginationOptions(limit: limit),
          );
          final cursor = firstResponse.data.cursor;

          // Assert first call was correct
          expect(cursor, isNotNull);
          expect(firstResponse.data.items.length, limit);
          expect(firstResponse.data.hasMore, isTrue);

          // --- SECOND CALL ---
          // The cursor document is the last item of the first page
          final cursorDoc = productDocs[limit - 1];
          final cursorId = cursorDoc['_id']! as ObjectId;

          // Mock findOne() for when _addCursorToSelector looks up the cursor doc
          when(
            () => mockCollection.findOne(any()),
          ).thenAnswer((_) async => cursorDoc);

          // Mock find() for the second page call
          setupMockFind(productDocs.skip(limit).toList());

          // Act
          final secondResponse = await client.readAll(
            pagination: PaginationOptions(limit: limit, cursor: cursor),
          );

          // Assert second call results
          expect(secondResponse.data.items.length, limit);
          expect(secondResponse.data.hasMore, isTrue);
          expect(secondResponse.data.items[0].name, 'Product 2');
          expect(secondResponse.data.items[1].name, 'Product 3');

          // Verify the findOne call for the cursor document
          final capturedFindOne =
              verify(() => mockCollection.findOne(captureAny())).captured.first
                  as Map<String, dynamic>;
          expect(capturedFindOne['_id'], cursorId);

          // Verify the main find call contains the correct cursor logic
          final captured = verify(
            () => mockCollection.modernFind(
              filter: captureAny(named: 'filter'),
              sort: any(named: 'sort'),
              limit: any(named: 'limit'),
              skip: any(named: 'skip'),
              projection: any(named: 'projection'),
              hint: any(named: 'hint'),
              hintDocument: any(named: 'hintDocument'),
              findOptions: any(named: 'findOptions'),
              rawOptions: any(named: 'rawOptions'),
            ),
          ).captured;
          final filterArg = captured.last as Map<String, dynamic>;
          expect(filterArg, contains(r'$or'));
          expect(filterArg[r'$or'], [
            {
              '_id': {r'$gt': cursorId},
            },
          ]);
        });

        test(
          'should throw BadRequestException for invalid cursor format',
          () async {
            // Arrange
            const invalidCursor = 'not-a-valid-cursor';
            const pagination = PaginationOptions(cursor: invalidCursor);

            // Act & Assert
            expect(
              () => client.readAll(pagination: pagination),
              throwsA(isA<BadRequestException>()),
            );
            verifyNever(() => mockCollection.findOne(any()));
          },
        );

        test(
          'should throw BadRequestException if cursor doc is not found',
          () async {
            // Arrange
            final validButNotFoundCursor = ObjectId().oid;
            final pagination = PaginationOptions(
              cursor: validButNotFoundCursor,
            );

            // Mock findOne to return null, simulating a not-found cursor doc
            when(
              () => mockCollection.findOne(any()),
            ).thenAnswer((_) async => null);

            // Act & Assert
            expect(
              () => client.readAll(pagination: pagination),
              throwsA(isA<BadRequestException>()),
            );
            verify(() => mockCollection.findOne(any())).called(1);
          },
        );

        test(
          'should build correct cursor query with multiple sort fields',
          () async {
            // Arrange
            final cursorId = ObjectId();
            final cursorDoc = {
              '_id': cursorId,
              'name': 'Product B',
              'price': 50.0,
            };
            final cursor = cursorId.oid;
            final sortOptions = [
              const SortOption('price', SortOrder.desc),
              const SortOption('name', SortOrder.asc),
            ];

            when(
              () => mockCollection.findOne(any()),
            ).thenAnswer((_) async => cursorDoc);
            setupMockFind([]); // Don't care about the result, just the query

            // Act
            await client.readAll(
              pagination: PaginationOptions(cursor: cursor),
              sort: sortOptions,
            );

            // Assert
            final captured = verify(
              () => mockCollection.modernFind(
                filter: captureAny(named: 'filter'),
                sort: any(named: 'sort'),
                limit: any(named: 'limit'),
                skip: any(named: 'skip'),
                projection: any(named: 'projection'),
                hint: any(named: 'hint'),
                hintDocument: any(named: 'hintDocument'),
                findOptions: any(named: 'findOptions'),
                rawOptions: any(named: 'rawOptions'),
              ),
            ).captured;
            final filterArg = captured.last as Map<String, dynamic>;

            // Verify the complex $or condition for multi-field sort
            expect(filterArg[r'$or'], [
              {
                'price': {r'$lt': 50.0},
              },
              {
                'price': 50.0,
                'name': {r'$gt': 'Product B'},
              },
              {
                'price': 50.0,
                'name': 'Product B',
                '_id': {r'$gt': cursorId},
              },
            ]);
          },
        );

        test('should throw ServerException on database error', () async {
          // Arrange
          when(
            () => mockCollection.modernFind(
              filter: any(named: 'filter'),
              sort: any(named: 'sort'),
              limit: any(named: 'limit'),
              skip: any(named: 'skip'),
              projection: any(named: 'projection'),
              hint: any(named: 'hint'),
              hintDocument: any(named: 'hintDocument'),
              findOptions: any(named: 'findOptions'),
              rawOptions: any(named: 'rawOptions'),
            ),
          ).thenThrow(Exception('DB connection failed'));

          // Act & Assert
          expect(() => client.readAll(), throwsA(isA<ServerException>()));
        });
      });
    });

    group('count', () {
      test('should return the total count of items', () async {
        // Arrange
        when(() => mockCollection.count(any())).thenAnswer((_) async => 10);

        // Act
        final response = await client.count();

        // Assert
        expect(response.data, 10);
        final captured = verify(
          () => mockCollection.count(captureAny()),
        ).captured.first;
        expect(captured, isEmpty); // No filter, no userId
      });

      test('should apply filter correctly', () async {
        // Arrange
        final filter = {'price': 10.0};
        when(() => mockCollection.count(any())).thenAnswer((_) async => 3);

        // Act
        final response = await client.count(filter: filter);

        // Assert
        expect(response.data, 3);
        final captured = verify(
          () => mockCollection.count(captureAny()),
        ).captured.first;
        expect(captured, filter);
      });

      test('should ignore userId and apply filter correctly', () async {
        // Arrange
        const userId = 'user-123';
        final filter = {'price': 10.0};
        when(() => mockCollection.count(any())).thenAnswer((_) async => 3);

        // Act
        final response = await client.count(userId: userId, filter: filter);

        // Assert
        expect(response.data, 3);
        final captured =
            verify(() => mockCollection.count(captureAny())).captured.first;
        // The selector should NOT contain the userId
        expect(captured, {'price': 10.0});
      });

      test('should throw ServerException on database error', () async {
        // Arrange
        when(
          () => mockCollection.count(any()),
        ).thenThrow(Exception('DB connection failed'));

        // Act & Assert
        expect(() => client.count(), throwsA(isA<ServerException>()));
      });
    });

    group('aggregate', () {
      final pipeline = [
        {
          r'$group': {'_id': r'$category', 'count': 1},
        },
      ];
      final results = [
        {'_id': 'A', 'count': 5},
        {'_id': 'B', 'count': 3},
      ];

      test('should execute a simple pipeline successfully', () async {
        // Arrange
        when(
          () => mockCollection.aggregateToStream(any()),
        ).thenAnswer((_) => Stream.fromIterable(results));

        // Act
        final response = await client.aggregate(pipeline: pipeline);

        // Assert
        expect(response.data, results);
        final captured = verify(
          () => mockCollection.aggregateToStream(captureAny()),
        ).captured.first;
        expect(captured, pipeline);
      });

      test('should ignore userId and execute a pipeline successfully',
          () async {
        // Arrange
        const userId = 'user-123';
        when(() => mockCollection.aggregateToStream(any()))
            .thenAnswer((_) => Stream.fromIterable(results));

        // Act
        await client.aggregate(pipeline: pipeline, userId: userId);

        // Assert
        final captured = verify(() => mockCollection.aggregateToStream(captureAny()))
            .captured
            .first as List<Map<String, Object>>;

        // The pipeline should NOT be modified to include a userId match stage
        expect(captured, pipeline);
      });

      test(
        'should throw BadRequestException for a failed command MongoDartError',
        () async {
          // Arrange
          final mongoError = MongoDartError(
            'Command failed: Invalid pipeline stage specified',
          );
          when(
            () => mockCollection.aggregateToStream(any()),
          ).thenThrow(mongoError);

          // Act & Assert
          expect(
            () => client.aggregate(pipeline: pipeline),
            throwsA(isA<BadRequestException>()),
          );
        },
      );

      test(
        'should throw ServerException for a generic MongoDartError',
        () async {
          // Arrange
          final mongoError = MongoDartError('Some other connection error');
          when(
            () => mockCollection.aggregateToStream(any()),
          ).thenThrow(mongoError);

          // Act & Assert
          expect(
            () => client.aggregate(pipeline: pipeline),
            throwsA(isA<ServerException>()),
          );
        },
      );

      test('should throw ServerException on other database errors', () async {
        // Arrange
        when(
          () => mockCollection.aggregateToStream(any()),
        ).thenThrow(Exception('DB connection failed'));

        // Act & Assert
        expect(
          () => client.aggregate(pipeline: pipeline),
          throwsA(isA<ServerException>()),
        );
      });
    });
  });
}
