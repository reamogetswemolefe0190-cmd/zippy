import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zippy_app/models/vendor_model.dart';
import 'package:zippy_app/models/transaction_model.dart';
import 'package:zippy_app/models/bill_split_model.dart';
import 'package:zippy_app/services/zippy_storage_service.dart';
import 'package:zippy_app/services/zippy_payment_service.dart';

void main() {
  setUp(() {
    ZippyStorageService.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  group('ZippyStorageService Unit Tests', () {
    test('saveActiveMerchantZippyNumber and getActiveMerchantZippyNumber roundtrips', () async {
      await ZippyStorageService.saveActiveMerchantZippyNumber('4523');
      final loaded = await ZippyStorageService.getActiveMerchantZippyNumber();
      expect(loaded, '4523');

      await ZippyStorageService.saveActiveMerchantZippyNumber(null);
      final cleared = await ZippyStorageService.getActiveMerchantZippyNumber();
      expect(cleared, isNull);
    });

    test('saveCustomVendors and getCustomVendors persists custom merchants', () async {
      const vendor = VendorModel(
        zippyNumber: '9912',
        name: 'Gugulethu Fresh Produce',
        category: 'Spaza Shop',
        ownerName: 'Vuyo Ndlovu',
        phoneNumber: '+27829912000',
        bankName: 'Capitec Bank',
        accountNumber: '1122334455',
      );

      await ZippyStorageService.saveCustomVendors([vendor]);
      final loaded = await ZippyStorageService.getCustomVendors();
      expect(loaded.length, 1);
      expect(loaded.first.zippyNumber, '9912');
      expect(loaded.first.name, 'Gugulethu Fresh Produce');
    });

    test('saveVendorTransactions and getVendorTransactions persists transactions', () async {
      final tx = TransactionModel(
        id: 'tx_test_1',
        type: 'MERCHANT_PAYMENT',
        status: 'SETTLED',
        authCode: 'STITCH_CAP_TEST',
        grossAmount: 100.0,
        zippyFee: 2.5,
        netPayout: 97.5,
        idempotencyKey: 'idem_test',
        customerName: 'Thabo Mbeki',
        createdAt: DateTime.now(),
      );

      await ZippyStorageService.saveVendorTransactions('4523', [tx]);
      final loaded = await ZippyStorageService.getVendorTransactions('4523');
      expect(loaded.length, 1);
      expect(loaded.first.id, 'tx_test_1');
      expect(loaded.first.grossAmount, 100.0);
    });

    test('saveSplits and getSplits persists bill splits', () async {
      final split = BillSplitModel(
        id: 'split_1',
        title: 'Dinner at RocoMamas',
        totalAmount: 300.0,
        hostId: 'user_thabo',
        hostName: 'Thabo',
        participants: [],
        createdAt: DateTime.now(),
      );

      await ZippyStorageService.saveSplits([split]);
      final loaded = await ZippyStorageService.getSplits();
      expect(loaded.length, 1);
      expect(loaded.first.title, 'Dinner at RocoMamas');
    });

    test('saveLastActiveRole persists role across app launches', () async {
      await ZippyStorageService.saveLastActiveRole('merchant');
      expect(await ZippyStorageService.getLastActiveRole(), 'merchant');

      await ZippyStorageService.saveLastActiveRole('customer');
      expect(await ZippyStorageService.getLastActiveRole(), 'customer');
    });
  });

  group('ZippyPaymentService Storage Integration Tests', () {
    test('registerVendor persists new vendor to storage and can be restored', () async {
      final vendor = await ZippyPaymentService.registerVendor(
        name: 'Kasi Shisanyama',
        category: 'Street Food',
        ownerName: 'Musa Sithole',
        phoneNumber: '+27830001111',
        bankName: 'FNB',
        accountNumber: '6200001111',
        customZippyNumber: '6655',
      );

      expect(vendor.zippyNumber, '6655');
      final storedVendors = await ZippyStorageService.getCustomVendors();
      expect(storedVendors.any((v) => v.zippyNumber == '6655'), isTrue);

      final activeZippy = await ZippyStorageService.getActiveMerchantZippyNumber();
      expect(activeZippy, '6655');
    });

    test('payMerchant persists transaction to storage', () async {
      final vendor = (await ZippyPaymentService.lookupVendor('4523'))!;
      await ZippyPaymentService.payMerchant(
        vendor: vendor,
        grossAmount: 50.0,
        customerName: 'Lerato',
      );

      final storedTxs = await ZippyStorageService.getVendorTransactions('4523');
      expect(storedTxs.isNotEmpty, isTrue);
      expect(storedTxs.first.grossAmount, 50.0);
    });
  });
}
