import 'dart:convert';

/// Current status of a participant's split share.
enum SplitParticipantStatus {
  /// Payment has been requested but not settled.
  pending,

  /// Payment successfully verified and settled into the host's account.
  paid,

  /// Payment was declined or cancelled.
  declined,
}

/// Represents a single friend participating in a bill split.
class SplitParticipant {
  /// Unique identifier for this participant record.
  final String id;

  /// Full display name of the friend.
  final String name;

  /// Mobile phone number for push/SMS notification.
  final String phoneNumber;

  /// The principal portion of the bill owed by this participant in ZAR.
  final double shareAmount;

  /// The Zippy convenience fee charged to this participant in ZAR (R2.50).
  final double convenienceFee;

  /// The total amount debited from this participant in ZAR (share + fee).
  final double totalToPay;

  /// Whether this participant has successfully paid their portion.
  final bool hasPaid;

  /// The current payment status.
  final SplitParticipantStatus status;

  /// The timestamp when the payment was settled.
  final DateTime? paidAt;

  /// Creates a new [SplitParticipant] instance.
  const SplitParticipant({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.shareAmount,
    required this.convenienceFee,
    required this.totalToPay,
    this.hasPaid = false,
    this.status = SplitParticipantStatus.pending,
    this.paidAt,
  });

  /// Constructs a [SplitParticipant] from a JSON-compatible map.
  factory SplitParticipant.fromMap(Map<String, dynamic> map) {
    return SplitParticipant(
      id: map['id'] as String,
      name: map['name'] as String,
      phoneNumber: map['phoneNumber'] as String,
      shareAmount: (map['shareAmount'] as num).toDouble(),
      convenienceFee: (map['convenienceFee'] as num).toDouble(),
      totalToPay: (map['totalToPay'] as num).toDouble(),
      hasPaid: map['hasPaid'] as bool? ?? false,
      status: map['status'] == 'paid'
          ? SplitParticipantStatus.paid
          : map['status'] == 'declined'
              ? SplitParticipantStatus.declined
              : SplitParticipantStatus.pending,
      paidAt: map['paidAt'] != null ? DateTime.parse(map['paidAt'] as String) : null,
    );
  }

  /// Converts this participant instance into a JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'shareAmount': shareAmount,
      'convenienceFee': convenienceFee,
      'totalToPay': totalToPay,
      'hasPaid': hasPaid,
      'status': status.name,
      'paidAt': paidAt?.toIso8601String(),
    };
  }
}

/// Represents a multi-participant social bill split.
class BillSplitModel {
  /// Unique identifier of this split in the Appwrite database.
  final String id;

  /// Title or venue description (e.g., "RocoMamas Saturday Dinner").
  final String title;

  /// Total bill amount paid by the host in ZAR.
  final double totalAmount;

  /// User ID of the host who paid the bill upfront.
  final String hostId;

  /// Full display name of the host.
  final String hostName;

  /// List of participating friends.
  final List<SplitParticipant> participants;

  /// The timestamp when the split was created.
  final DateTime createdAt;

  /// Creates a new [BillSplitModel] instance.
  const BillSplitModel({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.hostId,
    required this.hostName,
    required this.participants,
    required this.createdAt,
  });

  /// The percentage of participants who have settled their share.
  int get percentSettled {
    if (participants.isEmpty) return 100;
    final int paidCount = participants.where((p) => p.hasPaid).length;
    return ((paidCount / participants.length) * 100).round();
  }

  /// Whether all participants have fully settled.
  bool get isFullySettled => participants.isNotEmpty && participants.every((p) => p.hasPaid);

  /// Constructs a [BillSplitModel] from an Appwrite database document map.
  factory BillSplitModel.fromMap(Map<String, dynamic> map) {
    List<SplitParticipant> participantsList = [];
    if (map['participantsJson'] != null) {
      try {
        final List<dynamic> decoded =
            jsonDecode(map['participantsJson'] as String) as List<dynamic>;
        participantsList = decoded
            .map((item) => SplitParticipant.fromMap(item as Map<String, dynamic>))
            .toList();
      } catch (_) {
        participantsList = [];
      }
    } else if (map['participants'] is List) {
      participantsList = (map['participants'] as List<dynamic>)
          .map((item) => SplitParticipant.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    return BillSplitModel(
      id: map[r'$id'] as String? ?? map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      hostId: map['hostId'] as String? ?? '',
      hostName: map['hostName'] as String? ?? 'Host',
      participants: participantsList,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : (map[r'$createdAt'] != null
              ? DateTime.parse(map[r'$createdAt'] as String)
              : DateTime.now()),
    );
  }

  /// Converts this split model into a JSON-compatible map for Appwrite.
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'totalAmount': totalAmount,
      'hostId': hostId,
      'hostName': hostName,
      'status': isFullySettled ? 'SETTLED' : 'DISPATCHED',
      'participantsJson':
          jsonEncode(participants.map((p) => p.toMap()).toList()),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

