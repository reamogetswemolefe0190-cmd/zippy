import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zippy_app/models/vendor_model.dart';
import 'package:zippy_app/models/transaction_model.dart';
import 'package:zippy_app/models/bill_split_model.dart';

/// Local disk persistence service backing the Zippy payment client.
///
/// Stores active sessions, registered merchant tills, transaction audit feeds,
/// and bill splits across web browser reloads and native app restarts.
class ZippyStorageService {
  static const String _keyActiveMerchantZippy = 'zippy_active_merchant_number';
  static const String _keyCustomVendors = 'zippy_custom_vendors_json';
  static const String _keyVendorTransactionsPrefix = 'zippy_tx_vendor_';
  static const String _keySplits = 'zippy_splits_json';
  static const String _keyLastActiveRole = 'zippy_last_active_role';
  static const String _keyCustomerName = 'zippy_customer_name';

  static SharedPreferences? _prefs;

  /// Initializes the underlying [SharedPreferences] instance.
  static Future<SharedPreferences> init() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Synchronous getter for [SharedPreferences] if already initialized.
  static SharedPreferences? get prefs => _prefs;

  /// Resets the cached [SharedPreferences] reference for test isolation.
  static void resetForTesting() {
    _prefs = null;
  }

  /// Saves the active merchant till number to local disk.
  static Future<void> saveActiveMerchantZippyNumber(String? zippyNumber) async {
    final p = await init();
    if (zippyNumber == null) {
      await p.remove(_keyActiveMerchantZippy);
    } else {
      await p.setString(_keyActiveMerchantZippy, zippyNumber);
    }
  }

  /// Loads the active merchant till number from local disk.
  static Future<String?> getActiveMerchantZippyNumber() async {
    final p = await init();
    return p.getString(_keyActiveMerchantZippy);
  }

  /// Saves custom registered vendors to local disk.
  static Future<void> saveCustomVendors(List<VendorModel> vendors) async {
    final p = await init();
    final jsonList = vendors.map((v) => v.toMap()).toList();
    await p.setString(_keyCustomVendors, jsonEncode(jsonList));
  }

  /// Loads custom registered vendors from local disk.
  static Future<List<VendorModel>> getCustomVendors() async {
    final p = await init();
    final raw = p.getString(_keyCustomVendors);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((item) => VendorModel.fromMap(Map<String, dynamic>.from(item as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves transactions for a specific merchant till number.
  static Future<void> saveVendorTransactions(String zippyNumber, List<TransactionModel> transactions) async {
    final p = await init();
    final jsonList = transactions.map((t) => t.toMap()).toList();
    await p.setString('$_keyVendorTransactionsPrefix$zippyNumber', jsonEncode(jsonList));
  }

  /// Loads transactions for a specific merchant till number.
  static Future<List<TransactionModel>> getVendorTransactions(String zippyNumber) async {
    final p = await init();
    final raw = p.getString('$_keyVendorTransactionsPrefix$zippyNumber');
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((item) => TransactionModel.fromMap(Map<String, dynamic>.from(item as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves bill splits to local disk.
  static Future<void> saveSplits(List<BillSplitModel> splits) async {
    final p = await init();
    final jsonList = splits.map((s) => s.toMap()).toList();
    await p.setString(_keySplits, jsonEncode(jsonList));
  }

  /// Loads bill splits from local disk.
  static Future<List<BillSplitModel>> getSplits() async {
    final p = await init();
    final raw = p.getString(_keySplits);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((item) => BillSplitModel.fromMap(Map<String, dynamic>.from(item as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves the last active role ('customer' vs 'merchant').
  static Future<void> saveLastActiveRole(String role) async {
    final p = await init();
    await p.setString(_keyLastActiveRole, role);
  }

  /// Loads the last active role ('customer' vs 'merchant').
  static Future<String?> getLastActiveRole() async {
    final p = await init();
    return p.getString(_keyLastActiveRole);
  }

  /// Saves the default customer name.
  static Future<void> saveCustomerName(String name) async {
    final p = await init();
    await p.setString(_keyCustomerName, name);
  }

  /// Loads the default customer name.
  static Future<String?> getCustomerName() async {
    final p = await init();
    return p.getString(_keyCustomerName);
  }

  /// Clears all stored local keys (useful for testing or full sign-out).
  static Future<void> clearAll() async {
    final p = await init();
    await p.clear();
  }
}
