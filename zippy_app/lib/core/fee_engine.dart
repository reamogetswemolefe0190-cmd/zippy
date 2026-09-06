/// Calculation engine for all Zippy transaction fees in South Africa.
///
/// Implements the two monetization models:
/// 1. 2.5% merchant service fee for micro-purchases (undercuts Yoco's 2.9% + R1).
/// 2. Flat R2.50 convenience fee for social bill splits.
class FeeEngine {
  /// The standard merchant service fee percentage (2.5%).
  static const double merchantFeeRate = 0.025;

  /// The flat convenience fee charged to each friend in a bill split (R2.50).
  static const double splitFlatFeeZar = 2.50;

  /// Calculates the gross, fee, and net settlement for a merchant payment.
  ///
  /// The [grossAmount] represents the Rand value entered by the customer.
  /// Returns a record containing `(gross, fee, net)`.
  static ({double gross, double fee, double net}) calculateMerchantBreakdown(double grossAmount) {
    if (grossAmount <= 0) {
      throw ArgumentError.value(grossAmount, 'grossAmount', 'Must be greater than 0');
    }

    final double normalizedGross = ((grossAmount * 100).round()) / 100;
    final double fee = ((normalizedGross * merchantFeeRate) * 100).round() / 100;
    final double net = ((normalizedGross - fee) * 100).round() / 100;

    return (gross: normalizedGross, fee: fee, net: net);
  }

  /// Calculates the individual participant's total debit for a bill split.
  ///
  /// The [shareAmount] represents the participant's portion of the bill.
  /// Returns a record containing `(share, convenienceFee, totalDebited)`.
  static ({double share, double convenienceFee, double totalDebited}) calculateSplitShare(double shareAmount) {
    if (shareAmount <= 0) {
      throw ArgumentError.value(shareAmount, 'shareAmount', 'Must be greater than 0');
    }

    final double normalizedShare = ((shareAmount * 100).round()) / 100;
    final double total = ((normalizedShare + splitFlatFeeZar) * 100).round() / 100;

    return (share: normalizedShare, convenienceFee: splitFlatFeeZar, totalDebited: total);
  }

  /// Calculates equal individual portions when dividing [totalAmount] among [numberOfPeople].
  ///
  /// Returns the per-person base portion in ZAR.
  /// Throws an [ArgumentError] if [totalAmount] is less than or equal to 0 or [numberOfPeople] is less than 1.
  static double calculateEqualPortion(double totalAmount, int numberOfPeople) {
    if (totalAmount <= 0) {
      throw ArgumentError.value(totalAmount, 'totalAmount', 'Must be greater than 0');
    }
    if (numberOfPeople < 1) {
      throw ArgumentError.value(numberOfPeople, 'numberOfPeople', 'Must be at least 1');
    }

    return ((totalAmount / numberOfPeople) * 100).round() / 100;
  }
}

