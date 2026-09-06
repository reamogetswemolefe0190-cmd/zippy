import 'package:appwrite/appwrite.dart';

/// Configures and manages the global Appwrite BaaS client for Zippy.
///
/// Connects to the self-hosted or cloud Appwrite instance to manage
/// user authentication, database collections, and serverless cloud functions.
class AppwriteClientConfig {
  static String _endpoint = 'https://cloud.appwrite.io/v1';
  static String _projectId = 'zippy-south-africa';

  /// The active Appwrite endpoint URL.
  static String get endpoint => _endpoint;

  /// The active Appwrite project identifier.
  static String get projectId => _projectId;

  static Client? _client;

  /// The global [Client] instance.
  static Client get client => _client ??= Client()
      .setEndpoint(_endpoint)
      .setProject(_projectId)
      .setSelfSigned(status: true);

  static Account? _account;
  /// Account management service.
  static Account get account => _account ??= Account(client);

  static Databases? _databases;
  /// NoSQL / Relational database service.
  static Databases get databases => _databases ??= Databases(client);

  static Functions? _functions;
  /// Serverless functions service for Stitch orchestration.
  static Functions get functions => _functions ??= Functions(client);

  static Realtime? _realtime;
  /// Realtime websocket subscription service.
  static Realtime get realtime => _realtime ??= Realtime(client);

  /// Database identifier matching appwrite_schema/collections.json.
  static const String databaseId = 'zippy_main';

  /// Users collection ID matching appwrite_schema/collections.json.
  static const String usersCollectionId = 'users';

  /// Vendors collection ID matching appwrite_schema/collections.json.
  static const String vendorsCollectionId = 'vendors';

  /// Transactions collection ID matching appwrite_schema/collections.json.
  static const String transactionsCollectionId = 'transactions';

  /// Social bill splits collection ID matching appwrite_schema/collections.json.
  static const String splitsCollectionId = 'splits';

  /// Function ID for processing merchant payments matching appwrite_functions/.
  static const String processMerchantPaymentFunctionId = 'process_merchant_payment';

  /// Function ID for initiating PayShap splits matching appwrite_functions/.
  static const String initiatePayshapSplitFunctionId = 'initiate_payshap_split';

  /// Whether offline / mock fallback mode is active.
  ///
  /// Defaults to `true` in local development when live cloud credentials
  /// are not provisioned.
  static bool offlineFallback = true;

  /// Reconfigures the global Appwrite client with custom credentials or endpoints.
  static void configure({
    String? endpoint,
    String? projectId,
    bool? offlineFallback,
  }) {
    if (endpoint != null) {
      _endpoint = endpoint;
      if (_client != null) _client!.setEndpoint(endpoint);
    }
    if (projectId != null) {
      _projectId = projectId;
      if (_client != null) _client!.setProject(projectId);
    }
    if (offlineFallback != null) {
      AppwriteClientConfig.offlineFallback = offlineFallback;
    }
  }
}
