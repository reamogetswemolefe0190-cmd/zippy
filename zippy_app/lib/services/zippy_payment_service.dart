import 'package:zippy_app/core/appwrite_config.dart';
import 'package:zippy_app/core/fee_engine.dart';
import 'package:zippy_app/models/vendor_model.dart';
import 'package:zippy_app/models/bill_split_model.dart';
import 'package:zippy_app/models/transaction_model.dart';
import 'package:zippy_app/services/zippy_storage_service.dart';

/// Financial income statistics for a merchant till.
class MerchantIncomeStats {
  /// Total gross sales volume in ZAR.
  final double totalGross;

  /// Total net payout settled to the merchant bank in ZAR (97.5%).
  final double totalNet;

  /// Total Zippy service fees deducted in ZAR (2.5%).
  final double totalFees;

  /// Number of customer transactions.
  final int transactionCount;

  /// Creates a [MerchantIncomeStats] record.
  const MerchantIncomeStats({
    required this.totalGross,
    required this.totalNet,
    required this.totalFees,
    required this.transactionCount,
  });
}

/// Primary interface connecting the Zippy Flutter client to Appwrite BaaS and Stitch.
class ZippyPaymentService {
  /// In-memory catalog of verified mock vendors for rapid lookup.
  static final List<VendorModel> _seedVendors = [
    const VendorModel(
      zippyNumber: '4523',
      name: "Siya's Tuck Shop & Spaza",
      category: 'Spaza Shop',
      ownerName: 'Siyabonga Khumalo',
      phoneNumber: '+27821114523',
      bankName: 'Capitec Bank',
      accountNumber: '1098234523',
    ),
    const VendorModel(
      zippyNumber: '1082',
      name: "Mama Thembi's Vetkoek & Fast Foods",
      category: 'Street Food',
      ownerName: 'Thembi Dlamini',
      phoneNumber: '+27832221082',
      bankName: 'Standard Bank',
      accountNumber: '2093841082',
    ),
    const VendorModel(
      zippyNumber: '8831',
      name: "Bra Willie's Car Wash & Shisanyama",
      category: 'Tavern & Dining',
      ownerName: 'Willie Mokoena',
      phoneNumber: '+27843338831',
      bankName: 'FNB',
      accountNumber: '6284938831',
    ),
  ];

  /// Active mock in-memory split registry for live demonstration.
  static final List<BillSplitModel> _splits = [];

  /// Active in-memory merchant transactions map: `zippyNumber` -> `List<TransactionModel>`.
  static final Map<String, List<TransactionModel>> _vendorTransactions = {};

  /// Active merchant profile zippyNumber for the Merchant Hub view.
  static String? _activeMerchantZippyNumber;

  /// Gets the currently active merchant profile.
  static VendorModel? get activeMerchant {
    if (_activeMerchantZippyNumber == null) return null;
    try {
      return _seedVendors.firstWhere((v) => v.zippyNumber == _activeMerchantZippyNumber);
    } catch (_) {
      return null;
    }
  }

  /// Sets the currently active merchant profile by [zippyNumber].
  static void setActiveMerchant(String zippyNumber) {
    _activeMerchantZippyNumber = zippyNumber;
    ZippyStorageService.saveActiveMerchantZippyNumber(zippyNumber);
  }

  /// Restores cached merchant profiles, active till, and transaction records from local disk.
  static Future<void> initializeStorage() async {
    final custom = await ZippyStorageService.getCustomVendors();
    for (final v in custom) {
      if (!_seedVendors.any((existing) => existing.zippyNumber == v.zippyNumber)) {
        _seedVendors.add(v);
      }
    }
    final active = await ZippyStorageService.getActiveMerchantZippyNumber();
    if (active != null && _seedVendors.any((v) => v.zippyNumber == active)) {
      _activeMerchantZippyNumber = active;
    }
    for (final v in _seedVendors) {
      final txs = await ZippyStorageService.getVendorTransactions(v.zippyNumber);
      if (txs.isNotEmpty) {
        _vendorTransactions[v.zippyNumber] = txs;
      }
    }
    final storedSplits = await ZippyStorageService.getSplits();
    if (storedSplits.isNotEmpty) {
      _splits.clear();
      _splits.addAll(storedSplits);
    }
  }

  /// Verified merchant catalog for quick-pay shortcuts.
  static List<VendorModel> get recentVendors => List.unmodifiable(_seedVendors);

  /// Clears stored splits (primarily used for test isolation).
  static void resetSplits() {
    _splits.clear();
    ZippyStorageService.saveSplits([]);
  }

  /// Clears stored merchant data (used for test isolation).
  static void resetMerchantData() {
    _vendorTransactions.clear();
    _activeMerchantZippyNumber = null;
    ZippyStorageService.saveActiveMerchantZippyNumber(null);
  }

  /// Retrieves transaction history for a specific merchant [zippyNumber].
  static List<TransactionModel> getTransactionsForVendor(String zippyNumber) {
    return List.unmodifiable(_vendorTransactions[zippyNumber] ?? []);
  }

  /// Calculates income statistics for a merchant.
  static MerchantIncomeStats getMerchantStats(String zippyNumber) {
    final list = _vendorTransactions[zippyNumber] ?? [];
    double totalGross = 0.0;
    double totalNet = 0.0;
    double totalFees = 0.0;
    for (final tx in list) {
      totalGross += tx.grossAmount;
      totalNet += tx.netPayout;
      totalFees += tx.zippyFee;
    }
    return MerchantIncomeStats(
      totalGross: totalGross,
      totalNet: totalNet,
      totalFees: totalFees,
      transactionCount: list.length,
    );
  }

  /// Registers a new merchant vendor and assigns an active 4-digit Zippy till number.
  static Future<VendorModel> registerVendor({
    required String name,
    required String category,
    required String ownerName,
    required String phoneNumber,
    required String bankName,
    required String accountNumber,
    String? customZippyNumber,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    String number = customZippyNumber?.replaceAll(RegExp(r'\D'), '').trim() ?? '';
    if (number.length != 4 || _seedVendors.any((v) => v.zippyNumber == number)) {
      int candidate = 7740;
      while (_seedVendors.any((v) => v.zippyNumber == candidate.toString())) {
        candidate++;
      }
      number = candidate.toString();
    }

    final vendor = VendorModel(
      zippyNumber: number,
      name: name.trim(),
      category: category.trim(),
      ownerName: ownerName.trim(),
      phoneNumber: phoneNumber.trim(),
      bankName: bankName.trim(),
      accountNumber: accountNumber.trim(),
    );

    _seedVendors.add(vendor);
    _vendorTransactions[number] = [];
    _activeMerchantZippyNumber = number;
    final customVendors = _seedVendors.where((v) => !['4523', '1082', '8831'].contains(v.zippyNumber)).toList();
    await ZippyStorageService.saveCustomVendors(customVendors);
    await ZippyStorageService.saveActiveMerchantZippyNumber(number);
    await ZippyStorageService.saveVendorTransactions(number, []);
    return vendor;
  }

  /// Looks up a registered merchant by their 4-digit [zippyNumber].
  ///
  /// Returns `null` if no matching vendor is registered.
  static Future<VendorModel?> lookupVendor(String zippyNumber) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final clean = zippyNumber.replaceAll(RegExp(r'\D'), '').trim();
    if (clean.length != 4) return null;
    try {
      return _seedVendors.firstWhere((v) => v.zippyNumber == clean);
    } catch (_) {
      return null;
    }
  }

  /// Processes a merchant payment via Stitch pass-through.
  ///
  /// Deducts a 2.5% service fee for Zippy and routes 97.5% net payout
  /// directly to the merchant's bank account.
  static Future<Map<String, dynamic>> payMerchant({
    required VendorModel vendor,
    required double grossAmount,
    required String customerName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final breakdown = FeeEngine.calculateMerchantBreakdown(grossAmount);
    final String authCode = 'STITCH_CAP_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final String idempotencyKey = 'idem_${DateTime.now().millisecondsSinceEpoch}_${vendor.zippyNumber}';

    final transaction = TransactionModel(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      type: 'MERCHANT_PAYMENT',
      status: 'SETTLED',
      authCode: authCode,
      grossAmount: breakdown.gross,
      zippyFee: breakdown.fee,
      netPayout: breakdown.net,
      idempotencyKey: idempotencyKey,
      customerName: customerName,
      createdAt: DateTime.now(),
    );

    // Record in merchant live transaction stream
    _vendorTransactions.putIfAbsent(vendor.zippyNumber, () => []).insert(0, transaction);
    await ZippyStorageService.saveVendorTransactions(vendor.zippyNumber, _vendorTransactions[vendor.zippyNumber]!);

    return {
      'status': 'SUCCESS',
      'authCode': authCode,
      'vendor': vendor.toMap(),
      'customerName': customerName,
      'grossAmount': breakdown.gross,
      'zippyFee': breakdown.fee,
      'netVendorPayout': breakdown.net,
      'currency': 'ZAR',
      'idempotencyKey': idempotencyKey,
      'transaction': transaction.toMap(),
      'timestamp': DateTime.now().toIso8601String(),
      'appwriteDatabaseId': AppwriteClientConfig.databaseId,
      'appwriteFunctionId': AppwriteClientConfig.processMerchantPaymentFunctionId,
    };
  }

  /// Creates and dispatches a new [BillSplitModel].
  ///
  /// Calculates portions (either equal or [customShares]) and attaches the R2.50 convenience fee.
  /// Throws an [ArgumentError] if [totalAmount] is <= 0, [friendNames] is empty,
  /// any custom share is <= 0, or sum of custom shares exceeds [totalAmount].
  static Future<BillSplitModel> createSplit({
    required String title,
    required double totalAmount,
    required String hostName,
    required List<String> friendNames,
    List<double>? customShares,
  }) async {
    if (totalAmount <= 0) {
      throw ArgumentError.value(totalAmount, 'totalAmount', 'Total amount must be greater than 0');
    }
    if (friendNames.isEmpty) {
      throw ArgumentError('At least one friend must be selected to create a split');
    }

    if (customShares != null) {
      if (customShares.length != friendNames.length) {
        throw ArgumentError('customShares length (${customShares.length}) must match friendNames length (${friendNames.length})');
      }
      double customSum = 0.0;
      for (final s in customShares) {
        if (s <= 0) {
          throw ArgumentError.value(s, 'customShare', 'Custom share must be greater than 0');
        }
        customSum += s;
      }
      if (customSum > totalAmount + 0.01) {
        throw ArgumentError('Sum of custom shares (R ${customSum.toStringAsFixed(2)}) exceeds total bill (R ${totalAmount.toStringAsFixed(2)})');
      }
    }

    await Future.delayed(const Duration(milliseconds: 200));

    final int friendCount = friendNames.length;
    final int totalPersons = friendCount + 1; // Including host

    final participants = <SplitParticipant>[];
    for (int i = 0; i < friendCount; i++) {
      final name = friendNames[i];
      final double share = (customShares != null && i < customShares.length)
          ? customShares[i]
          : FeeEngine.calculateEqualPortion(totalAmount, totalPersons);

      final splitBreakdown = FeeEngine.calculateSplitShare(share);

      participants.add(
        SplitParticipant(
          id: 'p_${name.toLowerCase().replaceAll(' ', '_')}',
          name: name,
          phoneNumber: '+2782${(1000000 + i * 333333)}',
          shareAmount: splitBreakdown.share,
          convenienceFee: splitBreakdown.convenienceFee,
          totalToPay: splitBreakdown.totalDebited,
        ),
      );
    }

    final newSplit = BillSplitModel(
      id: 'split_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      title: title,
      totalAmount: totalAmount,
      hostId: 'user_thabo',
      hostName: hostName,
      participants: participants,
      createdAt: DateTime.now(),
    );

    _splits.insert(0, newSplit);
    await ZippyStorageService.saveSplits(_splits);
    return newSplit;
  }

  /// Settles an individual participant's share in a split via 1-tap PayShap RTP.
  static Future<BillSplitModel> settleParticipant({
    required String splitId,
    required String participantId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final int splitIndex = _splits.indexWhere((s) => s.id == splitId);
    if (splitIndex == -1) throw Exception('Split not found');

    final split = _splits[splitIndex];
    final participantIndex = split.participants.indexWhere((p) => p.id == participantId);
    if (participantIndex == -1) {
      throw ArgumentError('Participant $participantId not found in split $splitId');
    }

    // Idempotency: return existing split if participant has already settled
    if (split.participants[participantIndex].hasPaid) {
      return split;
    }

    final updatedParticipants = split.participants.map((p) {
      if (p.id == participantId) {
        return SplitParticipant(
          id: p.id,
          name: p.name,
          phoneNumber: p.phoneNumber,
          shareAmount: p.shareAmount,
          convenienceFee: p.convenienceFee,
          totalToPay: p.totalToPay,
          hasPaid: true,
          status: SplitParticipantStatus.paid,
          paidAt: DateTime.now(),
        );
      }
      return p;
    }).toList();

    final updatedSplit = BillSplitModel(
      id: split.id,
      title: split.title,
      totalAmount: split.totalAmount,
      hostId: split.hostId,
      hostName: split.hostName,
      participants: updatedParticipants,
      createdAt: split.createdAt,
    );

    _splits[splitIndex] = updatedSplit;
    await ZippyStorageService.saveSplits(_splits);
    return updatedSplit;
  }

  /// Retrieves all active and recent splits.
  static List<BillSplitModel> getRecentSplits() => List.unmodifiable(_splits);
}

