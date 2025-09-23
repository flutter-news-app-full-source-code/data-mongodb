<div align="center">
  <img src="https://avatars.githubusercontent.com/u/202675624?s=400&u=dc72a2b53e8158956a3b672f8e52e39394b6b610&v=4" alt="Flutter News App Toolkit Logo" width="220">
  <h1>Data MongoDB</h1>
  <p><strong>A production-ready MongoDB implementation of the `DataClient` interface for the Flutter News App Toolkit.</strong></p>
</div>

<p align="center">
  <img src="https://img.shields.io/badge/coverage-91%25-green?style=for-the-badge" alt="coverage">
  <a href="https://flutter-news-app-full-source-code.github.io/docs/"><img src="https://img.shields.io/badge/LIVE_DOCS-VIEW-slategray?style=for-the-badge" alt="Live Docs: View"></a>
  <a href="https://github.com/flutter-news-app-full-source-code"><img src="https://img.shields.io/badge/MAIN_PROJECT-BROWSE-purple?style=for-the-badge" alt="Main Project: Browse"></a>
</p>

This `data_mongodb` package provides a robust, concrete implementation of the `DataClient` interface within the [**Flutter News App Full Source Code Toolkit**](https://github.com/flutter-news-app-full-source-code). It acts as the bridge between your application's repositories and a MongoDB database, translating abstract data requests into native, efficient MongoDB queries. This package is designed for backend services (like a Dart Frog API) or applications that connect directly to MongoDB, ensuring consistent and scalable data persistence.

## ⭐ Feature Showcase: Powerful MongoDB Integration

This package offers a comprehensive set of features for interacting with MongoDB.

<details>
<summary><strong>🧱 Core Functionality</strong></summary>

### 🚀 `DataClient` Implementation
- **`DataMongodb<T>` Class:** A production-ready MongoDB implementation of the `DataClient<T>` interface, enabling type-safe interactions with various data models.
- **`MongoDbConnectionManager`:** Includes a robust connection manager for handling MongoDB connection lifecycle, ensuring reliable database access.

### 🌐 Advanced Querying & Data Management
- **Native MongoDB Queries:** Translates `readAll` parameters (rich `filter`, multi-field `sort`, and cursor-based `pagination`) into efficient native MongoDB queries.
- **ID Management Strategy:** Faithfully maps the application-level `id` string to the database `_id` field, crucial for correctly handling both global documents (like headlines) and user-owned documents (like settings).
- **Support for Multiple Data Models:** Correctly handles various document types, including global entities and user-owned documents where the `_id` serves as a foreign key to the user.
- **Efficient Counting & Aggregation:** Implements `count` for efficient document counting and `aggregate` to execute powerful, server-side aggregation pipelines.
- **Partial Text Search:** Translates a `q` filter parameter into a case-insensitive (`$regex`) search across designated searchable fields.

### 🛡️ Standardized Error Handling
- **`HttpException` Propagation:** Throws standard exceptions from `package:core` for consistent error handling, ensuring predictable error management across the application layers.

> **💡 Your Advantage:** You get a meticulously designed, production-quality MongoDB client that simplifies database interactions, ensures data integrity, provides robust error handling, and supports advanced querying capabilities. This package accelerates development by providing a solid foundation for data persistence.

</details>

## 🔑 Licensing

This `data_mongodb` package is an integral part of the [**Flutter News App Full Source Code Toolkit**](https://github.com/flutter-news-app-full-source-code). For comprehensive details regarding licensing, including trial and commercial options for the entire toolkit, please refer to the main toolkit organization page.
