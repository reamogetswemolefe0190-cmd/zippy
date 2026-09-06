import 'package:flutter_test/flutter_test.dart';
import 'package:zippy_app/models/vendor_model.dart';
import 'package:zippy_app/models/bill_split_model.dart';
import 'package:zippy_app/models/transaction_model.dart';

void main() {
  group('VendorModel Serialization', () {
    test('roundtrips toMap and fromMap correctly', () {
      const vendor = VendorModel(
        zippyNumber: '4523',
        name: "Siya's Tuck Shop",
        category: 'Spaza Shop',
        ownerName: 'Siyabonga Khumalo',
        phoneNumber: '+27821114523',
        bankName: 'Capitec Bank',
        accountNumber: '1098234523',
      );

      final map = vendor.toMap();
      expect(map['zippyNumber'], '4523');
      expect(map['name'], "Siya's Tuck Shop");

      final reconstructed = VendorModel.fromMap(map);
      expect(reconstructed.zippyNumber, vendor.zippyNumber);
      expect(reconstructed.name, vendor.name);
      expect(reconstructed.bankName, vendor.bankName);
    });
  });

  group('TransactionModel Serialization', () {
    test('roundtrips toMap and fromMap correctly', () {
      final now = DateTime.now();
      final tx = TransactionModel(
        id: 'tx_123456',
        type: 'MERCHANT_PAYMENT',
        status: 'SETTLED',
        authCode: 'STITCH_CAP_789012',
        grossAmount: 100.0,
        zippyFee: 2.50,
        netPayout: 97.50,
        idempotencyKey: 'idem_key_999',
        createdAt: now,
      );

      final map = tx.toMap();
      expect(map['type'], 'MERCHANT_PAYMENT');
      expect(map['status'], 'SETTLED');
      expect(map['authCode'], 'STITCH_CAP_789012');
      expect(map['grossAmount'], 100.0);
      expect(map['zippyFee'], 2.50);
      expect(map['netPayout'], 97.50);
      expect(map['idempotencyKey'], 'idem_key_999');

      final reconstructed = TransactionModel.fromMap({
        r'$id': 'tx_123456',
        ...map,
      });
      expect(reconstructed.id, 'tx_123456');
      expect(reconstructed.type, 'MERCHANT_PAYMENT');
      expect(reconstructed.grossAmount, 100.0);
      expect(reconstructed.zippyFee, 2.50);
      expect(reconstructed.netPayout, 97.50);
      expect(reconstructed.idempotencyKey, 'idem_key_999');
    });

    test(r'parses from Appwrite database document map with $id and $createdAt', () {
      final map = {
        r'$id': 'doc_trans_001',
        'type': 'MERCHANT_PAYMENT',
        'status': 'SETTLED',
        'authCode': 'STITCH_CAP_112233',
        'grossAmount': 50.0,
        'zippyFee': 1.25,
        'netPayout': 48.75,
        'idempotencyKey': 'idem_001',
        r'$createdAt': '2026-09-05T10:00:00.000Z',
      };

      final tx = TransactionModel.fromMap(map);
      expect(tx.id, 'doc_trans_001');
      expect(tx.grossAmount, 50.0);
      expect(tx.createdAt, DateTime.parse('2026-09-05T10:00:00.000Z'));
    });
  });

  group('BillSplitModel & SplitParticipant Serialization & Progress', () {
    test('calculates settlement progress and isFullySettled correctly', () {
      final participants = [
        const SplitParticipant(
          id: 'p1',
          name: 'Lerato Molefe',
          phoneNumber: '+27835552233',
          shareAmount: 300.0,
          convenienceFee: 2.50,
          totalToPay: 302.50,
          hasPaid: true,
          status: SplitParticipantStatus.paid,
        ),
        const SplitParticipant(
          id: 'p2',
          name: 'Sipho Ndlovu',
          phoneNumber: '+27846663344',
          shareAmount: 300.0,
          convenienceFee: 2.50,
          totalToPay: 302.50,
          hasPaid: false,
          status: SplitParticipantStatus.pending,
        ),
      ];

      final split = BillSplitModel(
        id: 'split_123',
        title: 'Dinner at RocoMamas',
        totalAmount: 900.0,
        hostId: 'user_thabo',
        hostName: 'Thabo Mbeki',
        participants: participants,
        createdAt: DateTime.now(),
      );

      expect(split.percentSettled, 50);
      expect(split.isFullySettled, isFalse);

      final map = split.toMap();
      expect(map['title'], 'Dinner at RocoMamas');
      expect(map['status'], 'DISPATCHED');
      expect(map['hostName'], 'Thabo Mbeki');
      expect(map['participantsJson'], isA<String>());

      final reconstructed = BillSplitModel.fromMap(map);
      expect(reconstructed.title, split.title);
      expect(reconstructed.hostName, 'Thabo Mbeki');
      expect(reconstructed.participants.length, 2);
      expect(reconstructed.participants.first.hasPaid, isTrue);
      expect(reconstructed.percentSettled, 50);
    });

    test(r'supports Appwrite $id and $createdAt fallback', () {
      final map = {
        r'$id': 'split_appwrite_123',
        'title': 'Shisanyama Braai',
        'totalAmount': 600.0,
        'hostId': 'user_host_1',
        'hostName': 'Sipho',
        'status': 'DISPATCHED',
        'participantsJson': '[]',
        r'$createdAt': '2026-09-05T12:00:00.000Z',
      };

      final reconstructed = BillSplitModel.fromMap(map);
      expect(reconstructed.id, 'split_appwrite_123');
      expect(reconstructed.createdAt, DateTime.parse('2026-09-05T12:00:00.000Z'));
    });

    test('reports 100% percentSettled when all friends paid', () {
      final participants = [
        const SplitParticipant(
          id: 'p1',
          name: 'Lerato',
          phoneNumber: '+27835552233',
          shareAmount: 100.0,
          convenienceFee: 2.50,
          totalToPay: 102.50,
          hasPaid: true,
          status: SplitParticipantStatus.paid,
        ),
      ];

      final split = BillSplitModel(
        id: 'split_999',
        title: 'Quick Lunch',
        totalAmount: 200.0,
        hostId: 'user_thabo',
        hostName: 'Thabo',
        participants: participants,
        createdAt: DateTime.now(),
      );

      expect(split.percentSettled, 100);
      expect(split.isFullySettled, isTrue);
    });
  });
}
