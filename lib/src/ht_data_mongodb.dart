import 'package:ht_data_client/ht_data_client.dart';
import 'package:ht_data_mongodb/src/mongo_db_connection_manager.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

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

  /// A getter for the MongoDB collection for the given model type [T].
  DbCollection get _collection => _connectionManager.db.collection(_modelName);

  /// Maps a document received from MongoDB to a model of type [T].
  ///
  /// This function handles the critical transformation of MongoDB's `_id`
  /// (an `ObjectId`) into the `id` (a `String`) expected by the data models.
  T _mapMongoDocumentToModel(Map<String, dynamic> doc) {
    // MongoDB uses `_id` with ObjectId, our models use `id` with String.
    // We need to perform this mapping before deserializing.
    doc['id'] = (doc['_id'] as ObjectId).toHexString();
    doc.remove('_id');
    return _fromJson(doc);
  }

  /// Maps a model of type [T] to a document suitable for MongoDB.
  ///
  /// This function prepares the data for insertion by removing the `id` field,
  /// as MongoDB will automatically generate the `_id` field.
  Map<String, dynamic> _mapModelToMongoDocument(T item) {
    final doc = _toJson(item);
    // The `id` field in our model is not part of the MongoDB document schema,
    // as MongoDB uses `_id`. We remove it before insertion/update.
    doc.remove('id');
    return doc;
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
        metadata: ResponseMetadata.now(),
      );
    } on MongoDartError catch (e, s) {
      _logger.severe('MongoDartError during create', e, s);
      throw ServerException('Database error during create: ${e.message}');
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
    } on MongoDartError catch (e, s) {
      _logger.severe('MongoDartError during delete', e, s);
      throw ServerException('Database error during delete: ${e.message}');
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
          'Read FAILED: Item with id "$id" not found in $_modelName for userId: $userId',
        );
        throw NotFoundException(
          'Item with ID "$id" not found in $_modelName.',
        );
      }

      final item = _mapMongoDocumentToModel(doc);
      return SuccessApiResponse(data: item, metadata: ResponseMetadata.now());
    } on MongoDartError catch (e, s) {
      _logger.severe('MongoDartError during read', e, s);
      throw ServerException('Database error during read: ${e.message}');
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
      // This structure sets up the flow for the next steps.
      // The logic for selector, sorting, and pagination will be built out.

      // Step 3.2: Build the query selector.
      final selector = _buildSelector(filter, userId);

      // Step 3.3: Build the sort builder (to be implemented).
      final sortBuilder = <String, dynamic>{};

      // Step 3.4: Handle pagination and execute query (to be implemented).
      final items = <T>[];
      const hasMore = false;
      const String? cursor = null;

      final paginatedResponse = PaginatedResponse(
        items: items,
        cursor: cursor,
        hasMore: hasMore,
      );

      return SuccessApiResponse(
        data: paginatedResponse,
        metadata: ResponseMetadata.now(),
      );
    } on MongoDartError catch (e, s) {
      _logger.severe('MongoDartError during readAll', e, s);
      throw ServerException('Database error during readAll: ${e.message}');
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
          'Update FAILED: Item with id "$id" not found in $_modelName for userId: $userId',
        );
        throw NotFoundException(
          'Item with ID "$id" not found for update in $_modelName.',
        );
      }

      // The updated item is the one we passed in.
      return SuccessApiResponse(data: item, metadata: ResponseMetadata.now());
    } on MongoDartError catch (e, s) {
      _logger.severe('MongoDartError during update', e, s);
      throw ServerException('Database error during update: ${e.message}');
    }
  }
}
