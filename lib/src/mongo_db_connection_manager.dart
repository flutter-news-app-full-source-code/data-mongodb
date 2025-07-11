import 'package:ht_shared/ht_shared.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// Manages the connection to a MongoDB database.
///
/// This class handles the initialization and closing of the database
/// connection, providing a single point of access to the `Db` instance.
class MongoDbConnectionManager {
  Db? _db;

  /// The active database connection.
  ///
  /// Throws a [ServerException] if the database is not initialized or connected.
  /// Call [init] before accessing this property.
  Db get db {
    if (_db == null || !_db!.isConnected) {
      throw const ServerException(
        'Database connection is not initialized or has been closed.',
      );
    }
    return _db!;
  }

  /// Initializes the connection to the MongoDB server.
  ///
  /// - [connectionString]: The MongoDB connection string.
  ///
  /// Throws a [MongoDartError] if the connection fails.
  Future<void> init(String connectionString) async {
    _db = await Db.create(connectionString);
    await _db!.open();
  }

  /// Closes the database connection.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
