import 'package:flutter_test/flutter_test.dart';
import 'package:zippy_app/core/fee_engine.dart';

void main() {
  group('FeeEngine Merchant Calculations (2.5% Service Fee)', () {
    test('calculates correct breakdown for standard R100 purchase', () {
      final breakdown = FeeEngine.calculateMerchantBreakdown(100.0);
      expect(breakdown.gross, 100.0);
      expect(breakdown.fee, 2.50);
      expect(breakdown.net, 97.50);
    });

    test('calculates correct breakdown for R45.00 micro-purchase at Tuck Shop', () {
      final breakdown = FeeEngine.calculateMerchantBreakdown(45.0);
      expect(breakdown.gross, 45.0);
      expect(breakdown.fee, 1.13); // 45 * 0.025 = 1.125 -> rounds to 1.13
      expect(breakdown.net, 43.87); // 45 - 1.13 = 43.87
    });

    test('calculates correct breakdown for small R5.00 purchase', () {
      final breakdown = FeeEngine.calculateMerchantBreakdown(5.0);
      expect(breakdown.gross, 5.0);
      expect(breakdown.fee, 0.13); // 5 * 0.025 = 0.125 -> rounds to 0.13
      expect(breakdown.net, 4.87);
    });

    test('normalizes fractional cents and guarantees gross == fee + net', () {
      final breakdown = FeeEngine.calculateMerchantBreakdown(45.004);
      expect(breakdown.gross, 45.00);
      expect(breakdown.fee + breakdown.net, breakdown.gross);

      final breakdown2 = FeeEngine.calculateMerchantBreakdown(99.999);
      expect(breakdown2.gross, 100.00);
      expect(breakdown2.fee + breakdown2.net, breakdown2.gross);
    });

    test('throws ArgumentError for non-positive gross amounts', () {
      expect(() => FeeEngine.calculateMerchantBreakdown(0), throwsArgumentError);
      expect(() => FeeEngine.calculateMerchantBreakdown(-50.0), throwsArgumentError);
    });
  });

  group('FeeEngine Split Calculations (R2.50 Convenience Fee)', () {
    test('calculates split share for R300.00 equal dinner portion', () {
      final result = FeeEngine.calculateSplitShare(300.0);
      expect(result.share, 300.0);
      expect(result.convenienceFee, 2.50);
      expect(result.totalDebited, 302.50);
    });

    test('calculates split share for small R15.00 taxi share', () {
      final result = FeeEngine.calculateSplitShare(15.0);
      expect(result.share, 15.0);
      expect(result.convenienceFee, 2.50);
      expect(result.totalDebited, 17.50);
    });

    test('throws ArgumentError for non-positive share amounts', () {
      expect(() => FeeEngine.calculateSplitShare(0), throwsArgumentError);
      expect(() => FeeEngine.calculateSplitShare(-10.0), throwsArgumentError);
    });
  });

  group('FeeEngine calculateEqualPortion', () {
    test('divides R1200 equally among 4 people', () {
      final portion = FeeEngine.calculateEqualPortion(1200.0, 4);
      expect(portion, 300.0);
    });

    test('divides R100 among 3 people with two-decimal rounding', () {
      final portion = FeeEngine.calculateEqualPortion(100.0, 3);
      expect(portion, 33.33);
    });

    test('throws ArgumentError for non-positive amounts or people < 1', () {
      expect(() => FeeEngine.calculateEqualPortion(0, 3), throwsArgumentError);
      expect(() => FeeEngine.calculateEqualPortion(-100, 3), throwsArgumentError);
      expect(() => FeeEngine.calculateEqualPortion(100, 0), throwsArgumentError);
      expect(() => FeeEngine.calculateEqualPortion(100, -2), throwsArgumentError);
    });
  });
}
