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

  @override
  Future<SuccessApiResponse<T>> create({required T item, String? userId}) {
    // TODO: implement create
    throw UnimplementedError();
  }

  @override
  Future<void> delete({required String id, String? userId}) {
    // TODO: implement delete
    throw UnimplementedError();
  }

  @override
  Future<SuccessApiResponse<T>> read({required String id, String? userId}) {
    // TODO: implement read
    throw UnimplementedError();
  }

  @override
  Future<SuccessApiResponse<PaginatedResponse<T>>> readAll({
    String? userId,
    Map<String, dynamic>? filter,
    PaginationOptions? pagination,
    List<SortOption>? sort,
  }) {
    // TODO: implement readAll
    throw UnimplementedError();
  }

  @override
  Future<SuccessApiResponse<T>> update({
    required String id,
    required T item,
    String? userId,
  }) {
    // TODO: implement update
    throw UnimplementedError();
  }
}
