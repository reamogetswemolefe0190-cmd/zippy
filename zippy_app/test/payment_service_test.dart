import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zippy_app/core/appwrite_config.dart';
import 'package:zippy_app/models/bill_split_model.dart';
import 'package:zippy_app/services/zippy_payment_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ZippyPaymentService.resetSplits();
  });

  group('ZippyPaymentService Merchant Operations', () {
    test('lookupVendor finds verified merchant #4523', () async {
      final vendor = await ZippyPaymentService.lookupVendor('4523');
      expect(vendor, isNotNull);
      expect(vendor!.name, "Siya's Tuck Shop & Spaza");
      expect(vendor.bankName, 'Capitec Bank');
    });

    test('lookupVendor returns null for invalid till number', () async {
      final vendor = await ZippyPaymentService.lookupVendor('9999');
      expect(vendor, isNull);
    });

    test('lookupVendor sanitizes input by stripping non-digits and whitespace', () async {
      final vendor1 = await ZippyPaymentService.lookupVendor(' #4523 ');
      expect(vendor1, isNotNull);
      expect(vendor1!.zippyNumber, '4523');

      final vendor2 = await ZippyPaymentService.lookupVendor('45 23');
      expect(vendor2, isNotNull);
      expect(vendor2!.zippyNumber, '4523');

      final vendorShort = await ZippyPaymentService.lookupVendor('45');
      expect(vendorShort, isNull);

      final vendorNonNumeric = await ZippyPaymentService.lookupVendor('abcd');
      expect(vendorNonNumeric, isNull);
    });

    test('payMerchant generates valid Stitch CAP receipt with 2.5% fee', () async {
      final vendor = (await ZippyPaymentService.lookupVendor('4523'))!;
      final receipt = await ZippyPaymentService.payMerchant(
        vendor: vendor,
        grossAmount: 100.0,
        customerName: 'Thabo Mbeki',
      );

      expect(receipt['status'], 'SUCCESS');
      expect(receipt['authCode'], startsWith('STITCH_CAP_'));
      expect(receipt['grossAmount'], 100.0);
      expect(receipt['zippyFee'], 2.50);
      expect(receipt['netVendorPayout'], 97.50);
      expect(receipt['idempotencyKey'], startsWith('idem_'));
      expect(receipt['transaction'], isA<Map<String, dynamic>>());
      expect(receipt['transaction']['type'], 'MERCHANT_PAYMENT');
      expect(receipt['transaction']['status'], 'SETTLED');
    });
  });

  group('ZippyPaymentService Split Operations', () {
    test('createSplit calculates equal shares and persists in recent splits', () async {
      final split = await ZippyPaymentService.createSplit(
        title: 'Dinner at RocoMamas',
        totalAmount: 1200.0,
        hostName: 'Thabo Mbeki',
        friendNames: ['Lerato', 'Sipho', 'Kamo'],
      );

      expect(split.participants.length, 3);
      // R1200 divided among 4 (host + 3 friends) = R300 each
      expect(split.participants[0].shareAmount, 300.0);
      expect(split.participants[0].convenienceFee, 2.50);
      expect(split.participants[0].totalToPay, 302.50);
      expect(split.percentSettled, 0);

      final recent = ZippyPaymentService.getRecentSplits();
      expect(recent.length, 1);
      expect(recent.first.id, split.id);
    });

    test('settleParticipant updates participant status to paid', () async {
      final split = await ZippyPaymentService.createSplit(
        title: 'Taxi to Sandton',
        totalAmount: 90.0,
        hostName: 'Thabo',
        friendNames: ['Lerato', 'Sipho'],
      );

      final participantId = split.participants.first.id;
      final updated = await ZippyPaymentService.settleParticipant(
        splitId: split.id,
        participantId: participantId,
      );

      final settledFriend = updated.participants.firstWhere((p) => p.id == participantId);
      expect(settledFriend.hasPaid, isTrue);
      expect(settledFriend.status, SplitParticipantStatus.paid);
      expect(settledFriend.paidAt, isNotNull);
      expect(updated.percentSettled, 50);

      // Idempotency: Second call for already settled friend returns existing state without mutation
      final reSettled = await ZippyPaymentService.settleParticipant(
        splitId: split.id,
        participantId: participantId,
      );
      expect(reSettled.percentSettled, 50);
      expect(reSettled.participants.firstWhere((p) => p.id == participantId).paidAt, settledFriend.paidAt);

      // Invalid participant ID throws ArgumentError
      expect(
        () => ZippyPaymentService.settleParticipant(
          splitId: split.id,
          participantId: 'non_existent_participant',
        ),
        throwsArgumentError,
      );
    });

    test('createSplit with custom shares calculates correct per-person fees', () async {
      final split = await ZippyPaymentService.createSplit(
        title: 'Shisanyama Braai',
        totalAmount: 1000.0,
        hostName: 'Thabo',
        friendNames: ['Lerato', 'Sipho'],
        customShares: [400.0, 350.0],
      );

      expect(split.participants.length, 2);
      expect(split.participants[0].shareAmount, 400.0);
      expect(split.participants[0].totalToPay, 402.50);
      expect(split.participants[1].shareAmount, 350.0);
      expect(split.participants[1].totalToPay, 352.50);
    });

    test('createSplit throws ArgumentError for invalid custom shares or over-allocation', () async {
      // Non-positive share
      expect(
        () => ZippyPaymentService.createSplit(
          title: 'Invalid Share Split',
          totalAmount: 500.0,
          hostName: 'Thabo',
          friendNames: ['Lerato', 'Sipho'],
          customShares: [0.0, 200.0],
        ),
        throwsArgumentError,
      );

      // Custom shares exceeding total bill
      expect(
        () => ZippyPaymentService.createSplit(
          title: 'Over-allocated Split',
          totalAmount: 500.0,
          hostName: 'Thabo',
          friendNames: ['Lerato', 'Sipho'],
          customShares: [400.0, 300.0], // 700 > 500
        ),
        throwsArgumentError,
      );

      // Mismatched length
      expect(
        () => ZippyPaymentService.createSplit(
          title: 'Mismatched Length Split',
          totalAmount: 500.0,
          hostName: 'Thabo',
          friendNames: ['Lerato', 'Sipho'],
          customShares: [200.0],
        ),
        throwsArgumentError,
      );
    });
  });

  group('AppwriteClientConfig Architecture & Functions Integration', () {
    test('exposes collection and function IDs matching schema', () {
      expect(AppwriteClientConfig.databaseId, 'zippy_main');
      expect(AppwriteClientConfig.vendorsCollectionId, 'vendors');
      expect(AppwriteClientConfig.transactionsCollectionId, 'transactions');
      expect(AppwriteClientConfig.splitsCollectionId, 'splits');
      expect(AppwriteClientConfig.processMerchantPaymentFunctionId, 'process_merchant_payment');
      expect(AppwriteClientConfig.initiatePayshapSplitFunctionId, 'initiate_payshap_split');
    });

    test('configure allows switching endpoints and toggling offline fallback', () {
      AppwriteClientConfig.configure(
        endpoint: 'https://appwrite.myzippy.co.za/v1',
        projectId: 'zippy-prod-south-africa',
        offlineFallback: false,
      );

      expect(AppwriteClientConfig.endpoint, 'https://appwrite.myzippy.co.za/v1');
      expect(AppwriteClientConfig.projectId, 'zippy-prod-south-africa');
      expect(AppwriteClientConfig.offlineFallback, isFalse);

      // Reset to default offline mode for tests
      AppwriteClientConfig.configure(
        endpoint: 'https://cloud.appwrite.io/v1',
        projectId: 'zippy-south-africa',
        offlineFallback: true,
      );
      expect(AppwriteClientConfig.endpoint, 'https://cloud.appwrite.io/v1');
      expect(AppwriteClientConfig.projectId, 'zippy-south-africa');
      expect(AppwriteClientConfig.offlineFallback, isTrue);
    });
  });
}
