// ignore_for_file: inference_failure_on_function_invocation, use_raw_strings, avoid_redundant_argument_values

import 'package:equatable/equatable.dart';
import 'package:ht_data_mongodb/ht_data_mongodb.dart';
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
        when(
          () => mockCollection.insertOne(any()),
        ).thenAnswer((_) async => writeResult);

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
        when(
          () => mockCollection.insertOne(any()),
        ).thenAnswer((_) async => writeResult);

        // Act
        final response = await client.create(item: newProduct, userId: userId);

        // Assert
        expect(response.data, newProduct);
        verify(() => mockCollection.insertOne(newProductDocWithUser)).called(1);
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
        when(
          () => mockCollection.insertOne(any()),
        ).thenAnswer((_) async => writeResult);

        // Act & Assert
        expect(
          () => client.create(item: newProduct),
          throwsA(isA<ServerException>()),
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

      test('should read an item successfully by id and userId', () async {
        // Arrange
        const userId = 'user-123';
        final productDocWithUser = {...productDoc, 'userId': userId};
        when(
          () => mockCollection.findOne(any()),
        ).thenAnswer((_) async => productDocWithUser);

        // Act
        final response = await client.read(id: productId.oid, userId: userId);

        // Assert
        expect(response.data, product);
        final captured = verify(
          () => mockCollection.findOne(captureAny()),
        ).captured.first;
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
      final updatedProductDoc = {
        'name': 'Updated Gadget',
        'price': 129.99,
      };

      test('should update an item successfully', () async {
        // Arrange
        final writeResult = MockWriteResult();
        when(() => writeResult.nModified).thenReturn(1);
        when(
          () => mockCollection.replaceOne(any(), any()),
        ).thenAnswer((_) async => writeResult);

        // Act
        final response = await client.update(
          id: productId.oid,
          item: updatedProduct,
        );

        // Assert
        expect(response.data, updatedProduct);
        final captured = verify(
          () => mockCollection.replaceOne(captureAny(), captureAny()),
        ).captured;
        expect(captured[0], {'_id': productId});
        expect(captured[1], updatedProductDoc);
      });

      test('should update a user-scoped item successfully', () async {
        // Arrange
        const userId = 'user-123';
        final updatedProductDocWithUser = {
          ...updatedProductDoc,
          'userId': userId,
        };
        final writeResult = MockWriteResult();
        when(() => writeResult.nModified).thenReturn(1);
        when(
          () => mockCollection.replaceOne(any(), any()),
        ).thenAnswer((_) async => writeResult);

        // Act
        final response = await client.update(
          id: productId.oid,
          item: updatedProduct,
          userId: userId,
        );

        // Assert
        expect(response.data, updatedProduct);
        final captured = verify(
          () => mockCollection.replaceOne(captureAny(), captureAny()),
        ).captured;
        expect(captured[0], {'_id': productId, 'userId': userId});
        expect(captured[1], updatedProductDocWithUser);
      });

      test('should throw BadRequestException for invalid id format', () {
        // Arrange
        const invalidId = 'not-an-object-id';

        // Act & Assert
        expect(
          () => client.update(id: invalidId, item: updatedProduct),
          throwsA(isA<BadRequestException>()),
        );
        verifyNever(() => mockCollection.replaceOne(any(), any()));
      });

      test(
        'should throw NotFoundException if item to update does not exist',
        () {
          // Arrange
          final writeResult = MockWriteResult();
          when(() => writeResult.nModified).thenReturn(0);
          when(
            () => mockCollection.replaceOne(any(), any()),
          ).thenAnswer((_) async => writeResult);

          // Act & Assert
          expect(
            () => client.update(id: productId.oid, item: updatedProduct),
            throwsA(isA<NotFoundException>()),
          );
        },
      );

      test('should throw ServerException on database error', () {
        // Arrange
        when(
          () => mockCollection.replaceOne(any(), any()),
        ).thenThrow(Exception('DB connection failed'));

        // Act & Assert
        expect(
          () => client.update(id: productId.oid, item: updatedProduct),
          throwsA(isA<ServerException>()),
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

      test('should delete a user-scoped item successfully', () async {
        // Arrange
        const userId = 'user-123';
        final writeResult = MockWriteResult();
        when(() => writeResult.nRemoved).thenReturn(1);
        when(
          () => mockCollection.deleteOne(any()),
        ).thenAnswer((_) async => writeResult);

        // Act
        await client.delete(id: productId.oid, userId: userId);

        // Assert
        final captured = verify(
          () => mockCollection.deleteOne(captureAny()),
        ).captured.first;
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
          return {
            '_id': id,
            'name': 'Product $i',
            'price': 10.0 + i,
          };
        });
      }

      // Helper to set up the mock for the find operation.
      void setupMockFind(List<Map<String, dynamic>> docs) {
        // The `find` method returns a stream-like object. We mock it to return
        // a stream created from our list of mock documents.
        when(
          () => mockCollection.find(any()),
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

        // Verify that the correct SelectorBuilder was passed to find().
        final captured = verify(
          () => mockCollection.find(captureAny()),
        ).captured.first;
        expect(captured, isA<SelectorBuilder>());

        final builder = captured as SelectorBuilder;
        // Check that the default sort order by _id is applied.
        expect(builder.map, containsPair('orderby', {'_id': 1}));
        // Check that the limit is the default (20) + 1 for hasMore check.
        expect(builder.paramLimit, 21);
      });

      test('should apply userId filter correctly', () async {
        // Arrange
        final productDocs = createProductDocs(2);
        setupMockFind(productDocs);
        const userId = 'user-abc';

        // Act
        await client.readAll(userId: userId);

        // Assert
        final captured = verify(
          () => mockCollection.find(captureAny()),
        ).captured.first;
        final builder = captured as SelectorBuilder;

        // The raw selector is inside the map of the builder
        expect(builder.map, containsPair('userId', userId));
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
          () => mockCollection.find(captureAny()),
        ).captured.first;
        final builder = captured as SelectorBuilder;

        expect(builder.map, containsPair('price', {'\$gte': 12.0}));
      });

      test('should combine userId and complex filter correctly', () async {
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
          () => mockCollection.find(captureAny()),
        ).captured.first;
        final builder = captured as SelectorBuilder;

        expect(builder.map, containsPair('userId', userId));
        expect(builder.map, containsPair('price', {'\$gte': 12.0}));
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
          () => mockCollection.find(captureAny()),
        ).captured.first;
        final builder = captured as SelectorBuilder;

        // The sort options are in the 'orderby' key of the builder's map
        expect(
          builder.map,
          containsPair('orderby', {'price': -1, '_id': 1}),
        );
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
          () => mockCollection.find(captureAny()),
        ).captured.first;
        final builder = captured as SelectorBuilder;

        expect(
          builder.map,
          containsPair('orderby', {'name': 1, 'price': -1, '_id': 1}),
        );
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
            () => mockCollection.find(captureAny()),
          ).captured.first;
          final builder = captured as SelectorBuilder;

          expect(
            builder.map,
            containsPair('orderby', {'price': 1, '_id': -1}),
          );
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
              () => mockCollection.find(captureAny()),
            ).captured.first;
            final builder = captured as SelectorBuilder;
            expect(builder.paramLimit, 4); // limit (3) + 1
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
          verify(
            () => mockCollection.findOne(
              any(
                that: isA<SelectorBuilder>().having(
                  (s) => s.map,
                  'map',
                  {
                    r'$query': {'_id': cursorId},
                  },
                ),
              ),
            ),
          ).called(1);

          // Verify the main find call contains the correct cursor logic
          final captured = verify(
            () => mockCollection.find(captureAny()),
          ).captured.last;
          final builder = captured as SelectorBuilder;
          expect(builder.map, contains(r'$or'));
          expect(builder.map[r'$or'], [
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
              () => mockCollection.find(captureAny()),
            ).captured.last;
            final builder = captured as SelectorBuilder;

            // Verify the complex $or condition for multi-field sort
            expect(builder.map[r'$or'], [
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
            () => mockCollection.find(any()),
          ).thenThrow(Exception('DB connection failed'));

          // Act & Assert
          expect(
            () => client.readAll(),
            throwsA(isA<ServerException>()),
          );
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
        final captured =
            verify(() => mockCollection.count(captureAny())).captured.first;
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
        final captured =
            verify(() => mockCollection.count(captureAny())).captured.first;
        expect(captured, filter);
      });

      test('should apply userId correctly', () async {
        // Arrange
        const userId = 'user-123';
        when(() => mockCollection.count(any())).thenAnswer((_) async => 5);

        // Act
        final response = await client.count(userId: userId);

        // Assert
        expect(response.data, 5);
        final captured =
            verify(() => mockCollection.count(captureAny())).captured.first;
        expect(captured, {'userId': userId});
      });

      test('should throw ServerException on database error', () async {
        // Arrange
        when(() => mockCollection.count(any()))
            .thenThrow(Exception('DB connection failed'));

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
        when(() => mockCollection.aggregateToStream(any()))
            .thenAnswer((_) => Stream.fromIterable(results));

        // Act
        final response = await client.aggregate(pipeline: pipeline);

        // Assert
        expect(response.data, results);
        final captured =
            verify(() => mockCollection.aggregateToStream(captureAny()))
                .captured
                .first;
        expect(captured, pipeline);
      });

      test(r'should prepend a $match stage when userId is provided', () async {
        // Arrange
        const userId = 'user-123';
        when(() => mockCollection.aggregateToStream(any()))
            .thenAnswer((_) => Stream.fromIterable(results));

        // Act
        await client.aggregate(pipeline: pipeline, userId: userId);

        // Assert
        final captured =
            verify(() => mockCollection.aggregateToStream(captureAny()))
                .captured
                .first as List<Map<String, Object>>;

        expect(captured.length, 2);
        expect(captured.first, {
          r'$match': {'userId': userId},
        });
        expect(captured.last, pipeline.first);
      });

      test(
        'should throw BadRequestException for a failed command MongoDartError',
        () async {
          // Arrange
          final mongoError = MongoDartError(
            'Command failed: Invalid pipeline stage specified',
          );
          when(() => mockCollection.aggregateToStream(any()))
              .thenThrow(mongoError);

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
          when(() => mockCollection.aggregateToStream(any()))
              .thenThrow(mongoError);

          // Act & Assert
          expect(
            () => client.aggregate(pipeline: pipeline),
            throwsA(isA<ServerException>()),
          );
        },
      );

      test('should throw ServerException on other database errors', () async {
        // Arrange
        when(() => mockCollection.aggregateToStream(any()))
            .thenThrow(Exception('DB connection failed'));

        // Act & Assert
        expect(
          () => client.aggregate(pipeline: pipeline),
          throwsA(isA<ServerException>()),
        );
      });
    });
  });
}
