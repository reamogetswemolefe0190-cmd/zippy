/// Represents a verified merchant registered on the Zippy platform.
class VendorModel {
  /// The unique 4-digit till identifier (e.g., '4523').
  final String zippyNumber;

  /// The trading name of the business (e.g., "Siya's Tuck Shop").
  final String name;

  /// The business category (e.g., "Spaza Shop", "Street Food").
  final String category;

  /// The registered owner's full legal name.
  final String ownerName;

  /// The registered mobile phone receiving transaction SMS alerts.
  final String phoneNumber;

  /// The destination bank name where payouts settle in real-time.
  final String bankName;

  /// The destination bank account number.
  final String accountNumber;

  /// Creates a new [VendorModel] instance.
  const VendorModel({
    required this.zippyNumber,
    required this.name,
    required this.category,
    required this.ownerName,
    required this.phoneNumber,
    required this.bankName,
    required this.accountNumber,
  });

  /// Constructs a [VendorModel] from an Appwrite database document map.
  factory VendorModel.fromMap(Map<String, dynamic> map) {
    return VendorModel(
      zippyNumber: map['zippyNumber'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      ownerName: map['ownerName'] as String,
      phoneNumber: map['phoneNumber'] as String,
      bankName: map['bankName'] as String,
      accountNumber: map['accountNumber'] as String,
    );
  }

  /// Converts this vendor instance into a JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'zippyNumber': zippyNumber,
      'name': name,
      'category': category,
      'ownerName': ownerName,
      'phoneNumber': phoneNumber,
      'bankName': bankName,
      'accountNumber': accountNumber,
    };
  }
}
