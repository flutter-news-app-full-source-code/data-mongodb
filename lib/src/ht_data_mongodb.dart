import 'package:ht_data_client/ht_data_client.dart';
import 'package:ht_data_mongodb/src/mongo_db_connection_manager.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:uuid/uuid.dart';

/// {@template ht_data_mongodb}
/// A MongoDB implementation of the [HtDataClient] interface.
///
/// This client interacts with a MongoDB database to perform CRUD operations,
/// translating the generic data client requests into native MongoDB queries.
/// {@endtemplate}
class HtDataMongodb<T> implements HtDataClient<T> {
  /// {@macro ht_data_mongodb}
  HtDataMongodb({
    required MongoDbConnectionManager connectionManager,
    required String modelName,
    required FromJson<T> fromJson,
    required ToJson<T> toJson,
    Logger? logger,
  })  : _connectionManager = connectionManager,
        _modelName = modelName,
        _fromJson = fromJson,
        _toJson = toJson,
        _logger = logger ?? Logger('HtDataMongodb<$T>');

  final MongoDbConnectionManager _connectionManager;
  final String _modelName;
  final FromJson<T> _fromJson;
  final ToJson<T> _toJson;
  final Logger _logger;
  final _uuid = const Uuid();

  /// A getter for the MongoDB collection for the given model type [T].
  DbCollection get _collection => _connectionManager.db.collection(_modelName);

  /// Maps a document received from MongoDB to a model of type [T].
  ///
  /// This function handles the critical transformation of MongoDB's `_id`
  /// (an `ObjectId`) into the `id` (a `String`) expected by the data models.
  T _mapMongoDocumentToModel(Map<String, dynamic> doc) {
    // MongoDB uses `_id` with ObjectId, our models use `id` with String.
    // We create a copy to avoid modifying the original map, which could cause
    // issues when determining the next cursor.
    final newDoc = Map<String, dynamic>.from(doc);
    newDoc['id'] = (newDoc['_id'] as ObjectId).oid;
    // The linter incorrectly flags this as a candidate for a cascade.
    // ignore: cascade_invocations
    return _fromJson(newDoc);
  }

  /// Maps a model of type [T] to a document suitable for MongoDB.
  ///
  /// This function prepares the data for insertion by removing the `id` field,
  /// as MongoDB will automatically generate the `_id` field.
  Map<String, dynamic> _mapModelToMongoDocument(T item) {
    // The `id` field in our model is not part of the MongoDB document schema,
    // as MongoDB uses `_id`. We remove it before insertion/update.
    return _toJson(item)..remove('id');
  }

  /// Builds a MongoDB query selector from the provided filter and userId.
  ///
  /// The [filter] map is expected to be in a format compatible with MongoDB's
  /// query syntax (e.g., using operators like `$in`, `$gte`).
  Map<String, dynamic> _buildSelector(
    Map<String, dynamic>? filter,
    String? userId,
  ) {
    final selector = <String, dynamic>{};

    if (userId != null) {
      selector['userId'] = userId;
    }

    if (filter != null) {
      // The filter map is assumed to be in valid MongoDB query format,
      // so we can merge it directly.
      selector.addAll(filter);
    }

    _logger.finer('Built MongoDB selector: $selector');
    return selector;
  }

  /// Builds a MongoDB sort map from the provided list of [SortOption].
  ///
  /// The [sortOptions] list is converted into a map where keys are field names
  /// and values are `1` for ascending or `-1` for descending.
  ///
  /// For stable pagination, it's crucial to have a deterministic sort order.
  /// This implementation ensures that `_id` is always included as a final
  /// tie-breaker if it's not already part of the sort criteria.
  Map<String, int> _buildSortBuilder(List<SortOption>? sortOptions) {
    final sortBuilder = <String, int>{};

    if (sortOptions != null && sortOptions.isNotEmpty) {
      for (final option in sortOptions) {
        sortBuilder[option.field] = option.order == SortOrder.asc ? 1 : -1;
      }
    }

    // Add `_id` as a final, unique tie-breaker for stable sorting.
    if (!sortBuilder.containsKey('_id')) {
      sortBuilder['_id'] = 1; // Default to ascending for the tie-breaker.
    }

    _logger.finer('Built MongoDB sort builder: $sortBuilder');
    return sortBuilder;
  }

  /// Modifies the selector to include conditions for cursor-based pagination.
  ///
  /// This method implements keyset pagination by adding a complex `$or`
  /// condition to the selector. This condition finds documents that come
  /// *after* the cursor document based on the specified sort order.
  Future<void> _addCursorToSelector(
    String cursorId,
    Map<String, dynamic> selector,
    Map<String, int> sortBuilder,
  ) async {
    if (!ObjectId.isValidHexId(cursorId)) {
      _logger.warning('Invalid cursor format: $cursorId');
      throw const BadRequestException('Invalid cursor format.');
    }
    final cursorObjectId = ObjectId.fromHexString(cursorId);

    final cursorDoc = await _collection.findOne(where.id(cursorObjectId));
    if (cursorDoc == null) {
      _logger.warning('Cursor document with id $cursorId not found.');
      throw const BadRequestException('Cursor document not found.');
    }

    final orConditions = <Map<String, dynamic>>[];
    final sortFields = sortBuilder.keys.toList();

    for (var i = 0; i < sortFields.length; i++) {
      final currentField = sortFields[i];
      final sortOrder = sortBuilder[currentField]!;
      final cursorValue = cursorDoc[currentField];

      final condition = <String, dynamic>{};
      for (var j = 0; j < i; j++) {
        final prevField = sortFields[j];
        condition[prevField] = cursorDoc[prevField];
      }

      condition[currentField] = {
        (sortOrder == 1 ? r'$gt' : r'$lt'): cursorValue,
      };
      orConditions.add(condition);
    }

    // This assumes no other $or conditions exist in the base filter.
    selector[r'$or'] = orConditions;
    _logger.finer('Added cursor conditions to selector: $selector');
  }

  @override
  Future<SuccessApiResponse<T>> create({
    required T item,
    String? userId,
  }) async {
    _logger.fine('Creating item in $_modelName, userId: $userId');
    try {
      final doc = _mapModelToMongoDocument(item);
      if (userId != null) {
        doc['userId'] = userId;
      }

      final writeResult = await _collection.insertOne(doc);

      if (!writeResult.isSuccess || writeResult.document == null) {
        _logger.severe('MongoDB create failed: ${writeResult.writeError}');
        throw ServerException(
          'Failed to create item: ${writeResult.writeError?.errmsg}',
        );
      }

      final createdItem = _mapMongoDocumentToModel(writeResult.document!);
      return SuccessApiResponse(
        data: createdItem,
        metadata: ResponseMetadata(
          requestId: _uuid.v4(),
          timestamp: DateTime.now(),
        ),
      );
    } on Exception catch (e, s) {
      _logger.severe('MongoDartError during create', e, s);
      throw ServerException('Database error during create: $e');
    }
  }

  @override
  Future<void> delete({required String id, String? userId}) async {
    _logger.fine(
      'Deleting item with id: $id from $_modelName, userId: $userId',
    );
    try {
      if (!ObjectId.isValidHexId(id)) {
        throw BadRequestException('Invalid ID format: "$id"');
      }

      final selector = <String, dynamic>{
        '_id': ObjectId.fromHexString(id),
      };
      if (userId != null) {
        selector['userId'] = userId;
      }

      final writeResult = await _collection.deleteOne(selector);

      if (writeResult.nRemoved == 0) {
        _logger.warning(
          'Delete FAILED: Item with id "$id" not found in $_modelName for userId: $userId',
        );
        throw NotFoundException(
          'Item with ID "$id" not found for deletion in $_modelName.',
        );
      }
      // No return value on success
    } on HtHttpException {
      rethrow;
    } on Exception catch (e, s) {
      _logger.severe('MongoDartError during delete', e, s);
      throw ServerException('Database error during delete: $e');
    }
  }

  @override
  Future<SuccessApiResponse<T>> read({
    required String id,
    String? userId,
  }) async {
    _logger.fine('Reading item with id: $id from $_modelName, userId: $userId');
    try {
      // Validate that the ID is a valid ObjectId hex string before querying.
      if (!ObjectId.isValidHexId(id)) {
        throw BadRequestException('Invalid ID format: "$id"');
      }

      final selector = <String, dynamic>{
        '_id': ObjectId.fromHexString(id),
      };

      if (userId != null) {
        selector['userId'] = userId;
      }

      final doc = await _collection.findOne(selector);

      if (doc == null) {
        _logger.warning(
          'Read FAILED: Item with id "$id" not found in $_modelName for '
          'userId: $userId',
        );
        throw NotFoundException(
          'Item with ID "$id" not found in $_modelName.',
        );
      }

      final item = _mapMongoDocumentToModel(doc);
      return SuccessApiResponse(
        data: item,
        metadata: ResponseMetadata(
          requestId: _uuid.v4(),
          timestamp: DateTime.now(),
        ),
      );
    } on HtHttpException {
      rethrow;
    } on Exception catch (e, s) {
      _logger.severe('MongoDartError during read', e, s);
      throw ServerException('Database error during read: $e');
    }
  }

  @override
  Future<SuccessApiResponse<PaginatedResponse<T>>> readAll({
    String? userId,
    Map<String, dynamic>? filter,
    PaginationOptions? pagination,
    List<SortOption>? sort,
  }) async {
    _logger.fine(
      'Reading all from $_modelName with filter: $filter, pagination: '
      '$pagination, sort: $sort, userId: $userId',
    );
    try {
      final selector = _buildSelector(filter, userId);
      final sortBuilder = _buildSortBuilder(sort);
      final limit = pagination?.limit ?? 20;

      if (pagination?.cursor != null) {
        await _addCursorToSelector(pagination!.cursor!, selector, sortBuilder);
      }

      // Fetch one extra item to determine if there are more pages.
      final selectorBuilder = SelectorBuilder()..raw(selector);

      // Apply sorting options by iterating over the built sort map.
      sortBuilder.forEach((field, order) {
        selectorBuilder.sortBy(field, descending: order == -1);
      });
      selectorBuilder.limit(limit + 1);

      final findResult = await _collection.find(selectorBuilder).toList();

      final hasMore = findResult.length > limit;
      // Take only the requested number of items for the final list.
      final documentsForPage = findResult.take(limit).toList();

      final items = documentsForPage.map(_mapMongoDocumentToModel).toList();

      // The cursor is the ID of the last item in the current page.
      final nextCursor = (documentsForPage.isNotEmpty && hasMore)
          ? (documentsForPage.last['_id'] as ObjectId).oid
          : null;

      final paginatedResponse = PaginatedResponse<T>(
        items: items,
        cursor: nextCursor,
        hasMore: hasMore,
      );

      return SuccessApiResponse(
        data: paginatedResponse,
        metadata: ResponseMetadata(
          requestId: _uuid.v4(),
          timestamp: DateTime.now(),
        ),
      );
    } on HtHttpException {
      rethrow;
    } on Exception catch (e, s) {
      _logger.severe('MongoDartError during readAll', e, s);
      throw ServerException('Database error during readAll: $e');
    }
  }

  @override
  Future<SuccessApiResponse<T>> update({
    required String id,
    required T item,
    String? userId,
  }) async {
    _logger.fine(
      'Updating item with id: $id in $_modelName, userId: $userId',
    );
    try {
      if (!ObjectId.isValidHexId(id)) {
        throw BadRequestException('Invalid ID format: "$id"');
      }

      final selector = <String, dynamic>{
        '_id': ObjectId.fromHexString(id),
      };
      if (userId != null) {
        selector['userId'] = userId;
      }

      final docToUpdate = _mapModelToMongoDocument(item);
      if (userId != null) {
        docToUpdate['userId'] = userId;
      }

      final writeResult = await _collection.replaceOne(selector, docToUpdate);

      if (writeResult.nModified == 0) {
        _logger.warning(
          'Update FAILED: Item with id "$id" not found in $_modelName for '
          'userId: $userId',
        );
        throw NotFoundException(
          'Item with ID "$id" not found for update in $_modelName.',
        );
      }

      // The updated item is the one we passed in.
      return SuccessApiResponse(
        data: item,
        metadata: ResponseMetadata(
          requestId: _uuid.v4(),
          timestamp: DateTime.now(),
        ),
      );
    } on HtHttpException {
      rethrow;
    } on Exception catch (e, s) {
      _logger.severe('MongoDartError during update', e, s);
      throw ServerException('Database error during update: $e');
    }
  }
}
