import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zippy_app/main.dart';
import 'package:zippy_app/services/zippy_payment_service.dart';
import 'package:zippy_app/services/zippy_storage_service.dart';
import 'package:zippy_app/widgets/tactile_scale.dart';
import 'package:zippy_app/widgets/zippy_logo.dart';

void main() {
  setUp(() {
    ZippyStorageService.resetForTesting();
    SharedPreferences.setMockInitialValues({});
    ZippyPaymentService.resetSplits();
    ZippyPaymentService.resetMerchantData();
  });

  void configurePhoneDimensions(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('ZippyApp smoke test verifies home brand', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    expect(find.text('zippy'), findsOneWidget);
    expect(find.text('Pay Mode'), findsOneWidget);
  });

  testWidgets('Home screen opens with bold question and two distinct cards', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // Verify "Who are you paying?" is prominently displayed
    expect(find.text('Who are you paying?'), findsOneWidget);

    // Verify two distinct cards: Merchant and Split Fare with min 48px touch targets
    final merchantModeFinder = find.byKey(const Key('merchantModeCard'));
    final splitFareModeFinder = find.byKey(const Key('splitFareModeCard'));
    expect(merchantModeFinder, findsOneWidget);
    expect(splitFareModeFinder, findsOneWidget);
    expect(tester.getSize(merchantModeFinder).height, greaterThanOrEqualTo(48.0));
    expect(tester.getSize(splitFareModeFinder).height, greaterThanOrEqualTo(48.0));

    // Verify Quick Pay Recent section
    expect(find.text('QUICK PAY RECENT'), findsOneWidget);
    expect(find.byKey(const Key('quick_vendor_4523')), findsOneWidget);
    expect(find.byKey(const Key('quick_vendor_1082')), findsOneWidget);
    expect(find.byKey(const Key('quick_vendor_8831')), findsOneWidget);
  });

  testWidgets('Tactile numpad updates amount on home screen without fee jargon', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // Tap backspace twice to clear default amount
    await tester.tap(find.byKey(const Key('numpad_backspace')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('numpad_backspace')));
    await tester.pumpAndSettle();

    // Enter 1, 2, 5
    await tester.tap(find.byKey(const Key('numpad_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('numpad_2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('numpad_5')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('homeAmountDisplay')), findsOneWidget);
    expect(find.text('125'), findsOneWidget);

    // Ensure zero financial fee jargon on the customer's face
    expect(find.textContaining('Vendor Net:'), findsNothing);
    expect(find.textContaining('Zippy 2.5% Fee:'), findsNothing);
    expect(find.textContaining('52% Net Margin'), findsNothing);
  });

  testWidgets('Quick Pay vendor selection pre-populates vendor code and amount', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // Tap Mama Thembi's Vetkoek (#1082, R25)
    await tester.tap(find.byKey(const Key('quick_vendor_1082')));
    await tester.pumpAndSettle();

    expect(find.text('25'), findsOneWidget);
    expect(find.textContaining('Mama Thembi'), findsWidgets);
  });

  testWidgets('Full payment flow: Pay merchant, view receipt, and tap split with friends', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // Select vendor #4523 and enter R45
    await tester.tap(find.byKey(const Key('quick_vendor_4523')));
    await tester.pumpAndSettle();

    // Pay button should be active for verified vendor #4523
    final payButton = find.byKey(const Key('homePrimaryActionButton'));
    expect(payButton, findsOneWidget);

    // Tap Pay & confirm in modal
    await tester.tap(payButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmPaymentButton')));
    await tester.pump(); // Start processing
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle(); // Settle receipt

    // Verify Receipt View
    expect(find.text('Payment Succeeded'), findsOneWidget);
    expect(find.text('Paid to Siya\'s Tuck Shop & Spaza'), findsOneWidget);
    expect(find.textContaining('Direct to Capitec Bank'), findsOneWidget);

    // Verify prominent "Split this bill with friends?" prompt
    final splitPromptButton = find.byKey(const Key('splitBillButton'));
    expect(splitPromptButton, findsOneWidget);

    // Tap "Split this bill with friends?"
    await tester.tap(splitPromptButton);
    await tester.pumpAndSettle();

    // Should transition to Split Fare screen with pre-filled amount (45) and title
    expect(find.text('Split Fare ⚡'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.textContaining('Bill at Siya\'s Tuck Shop'), findsOneWidget);
  });

  testWidgets('Split Fare flow allows friend selection, portion mode toggle, and live settlement', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // Navigate to Split Fare tab (index 2)
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    expect(find.text('Split Fare ⚡'), findsOneWidget);

    // Enter total amount 1200
    await tester.tap(find.byKey(const Key('numpad_1')));
    await tester.tap(find.byKey(const Key('numpad_2')));
    await tester.tap(find.byKey(const Key('numpad_0')));
    await tester.tap(find.byKey(const Key('numpad_0')));
    await tester.pumpAndSettle();

    // Advance to Step 1: People & Portions
    await tester.tap(find.byKey(const Key('splitStep1Continue')));
    await tester.pumpAndSettle();

    // Verify portion modes (Equal vs Custom) with min 48px touch targets
    final equalPortionFinder = find.byKey(const Key('splitModeEqual'));
    final customPortionFinder = find.byKey(const Key('splitModeCustom'));
    expect(equalPortionFinder, findsOneWidget);
    expect(customPortionFinder, findsOneWidget);
    expect(tester.getSize(equalPortionFinder).height, greaterThanOrEqualTo(48.0));
    expect(tester.getSize(customPortionFinder).height, greaterThanOrEqualTo(48.0));

    // Toggle to Custom portions
    await tester.tap(find.byKey(const Key('splitModeCustom')));
    await tester.pumpAndSettle();

    // Toggle back to Equal portions
    await tester.tap(find.byKey(const Key('splitModeEqual')));
    await tester.pumpAndSettle();

    // Advance to Step 2: Summary & Dispatch
    await tester.tap(find.byKey(const Key('splitStep2Continue')));
    await tester.pumpAndSettle();

    // Dispatch split requests
    final dispatchBtn = find.byKey(const Key('dispatchSplitButton'));
    expect(dispatchBtn, findsOneWidget);
    expect(find.textContaining('Send split request'), findsOneWidget);

    await tester.tap(dispatchBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verify Live Settlement Dashboard
    expect(find.text('Split Settlement Live'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);

    // Settle first friend via 1-Tap Pay
    final firstFriendSettle = find.byKey(const Key('settleButton_p_lerato_molefe'));
    expect(firstFriendSettle, findsOneWidget);
    final settleSize = tester.getSize(firstFriendSettle);
    expect(settleSize.height, greaterThanOrEqualTo(48.0));

    await tester.tap(firstFriendSettle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Participant should now show PAID badge
    expect(find.text('PAID'), findsOneWidget);
    // Progress should now be 33%
    expect(find.text('33%'), findsOneWidget);
  });

  testWidgets('SplitFareScreen updates prefilled amount and title when navigating from receipt after previous tab visit', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // 1. Visit Split Fare tab first
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    expect(find.text('Split Fare ⚡'), findsOneWidget);

    // 2. Switch back to Merchant tab
    await tester.tap(find.byIcon(Icons.storefront_outlined));
    await tester.pumpAndSettle();

    // 3. Select Siya's Tuck Shop (#4523, R45) and pay
    await tester.tap(find.byKey(const Key('quick_vendor_4523')));
    await tester.pumpAndSettle();
    final payBtn = find.byKey(const Key('homePrimaryActionButton'));
    await tester.tap(payBtn);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmPaymentButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Payment Succeeded'), findsOneWidget);

    // 4. Tap "Split this bill with friends?"
    await tester.tap(find.byKey(const Key('splitBillButton')));
    await tester.pumpAndSettle();

    // 5. Verify Split Fare screen updated with prefilled values via didUpdateWidget
    expect(find.text('Split Fare ⚡'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.textContaining("Bill at Siya's Tuck Shop"), findsOneWidget);
  });

  testWidgets('Custom Portions mode enforces balance, catches invalid inputs, and enables reset to equal', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // Navigate to Split Fare tab
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    // Enter bill total 1200
    await tester.tap(find.byKey(const Key('numpad_1')));
    await tester.tap(find.byKey(const Key('numpad_2')));
    await tester.tap(find.byKey(const Key('numpad_0')));
    await tester.tap(find.byKey(const Key('numpad_0')));
    await tester.pumpAndSettle();

    // Advance to Step 1: People & Portions
    await tester.tap(find.byKey(const Key('splitStep1Continue')));
    await tester.pumpAndSettle();

    // Toggle to Custom portions
    await tester.tap(find.byKey(const Key('splitModeCustom')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customPortionsSummaryCard')), findsOneWidget);

    // 1. Test non-positive / invalid input
    final leratoField = find.byKey(const Key('customPortionField_lerato_molefe'));
    expect(leratoField, findsOneWidget);

    await tester.enterText(leratoField, '0');
    await tester.pumpAndSettle();

    // Expect invalid error to display and continue button to be disabled
    expect(find.byKey(const Key('customPortionInvalidError')), findsOneWidget);
    final continueBtn = tester.widget<ElevatedButton>(find.byKey(const Key('splitStep2Continue')));
    expect(continueBtn.onPressed, isNull);

    // 2. Test over-allocation exceeding total bill
    await tester.enterText(leratoField, '800');
    await tester.pumpAndSettle();

    final siphoField = find.byKey(const Key('customPortionField_sipho_ndlovu'));
    expect(siphoField, findsOneWidget);
    // 800 (Lerato) + 800 (Sipho) = 1600 > 1200
    await tester.enterText(siphoField, '800');
    await tester.pumpAndSettle();

    // Expect over-allocation error to display and continue button to be disabled
    expect(find.byKey(const Key('customPortionExceedError')), findsOneWidget);
    final continueBtnOver = tester.widget<ElevatedButton>(find.byKey(const Key('splitStep2Continue')));
    expect(continueBtnOver.onPressed, isNull);

    // Tap "Reset to Equal"
    final resetBtn = find.byKey(const Key('resetToEqualSharesButton'));
    final resetSize = tester.getSize(resetBtn);
    expect(resetSize.height, greaterThanOrEqualTo(48.0));
    await tester.tap(resetBtn);
    await tester.pumpAndSettle();

    // Errors should clear and continue button should be enabled
    expect(find.byKey(const Key('customPortionInvalidError')), findsNothing);
    expect(find.byKey(const Key('customPortionExceedError')), findsNothing);
    final continueBtnReset = tester.widget<ElevatedButton>(find.byKey(const Key('splitStep2Continue')));
    expect(continueBtnReset.onPressed, isNotNull);

    // Advance to Step 2: Summary & Dispatch
    await tester.tap(find.byKey(const Key('splitStep2Continue')));
    await tester.pumpAndSettle();

    // Dispatch split
    await tester.tap(find.byKey(const Key('dispatchSplitButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Split Settlement Live'), findsOneWidget);
  });

  testWidgets('SplitFareScreen debounces rapid repeated taps on 1-Tap Pay and locks in-flight state', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // Navigate to Split Fare tab
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    // Enter bill total 300
    await tester.tap(find.byKey(const Key('numpad_3')));
    await tester.tap(find.byKey(const Key('numpad_0')));
    await tester.tap(find.byKey(const Key('numpad_0')));
    await tester.pumpAndSettle();

    // Advance through Step 1 and Step 2
    await tester.tap(find.byKey(const Key('splitStep1Continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('splitStep2Continue')));
    await tester.pumpAndSettle();

    // Dispatch split
    await tester.tap(find.byKey(const Key('dispatchSplitButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final firstFriendSettle = find.byKey(const Key('settleButton_p_lerato_molefe'));
    expect(firstFriendSettle, findsOneWidget);

    // First tap initiates in-flight settlement
    await tester.tap(firstFriendSettle);
    await tester.pump(); // Advance one frame so state updates to in-flight

    // Button should now display "Settling..." with progress indicator and disabled onPressed
    expect(find.text('Settling...'), findsOneWidget);
    final inFlightButton = tester.widget<ElevatedButton>(firstFriendSettle);
    expect(inFlightButton.onPressed, isNull);

    // Rapid second tap while in-flight should not trigger error or state race
    await tester.tap(firstFriendSettle, warnIfMissed: false);
    await tester.pump();

    // Let the async delayed call complete (200ms in service)
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Participant is now settled (PAID)
    expect(find.text('PAID'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
  });

  testWidgets('Merchant lookup edge cases: unknown till code displays error banner and non-digits are filtered', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // 1. Enter unknown 4-digit code '9999' on Home screen
    final homeZippyField = find.byKey(const Key('homeZippyNumberField'));
    expect(tester.getSize(homeZippyField).height, greaterThanOrEqualTo(48.0));
    await tester.enterText(homeZippyField, '9999');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // Expect not found banner on Home screen
    expect(find.byKey(const Key('homeVendorNotFoundMessage')), findsOneWidget);
    expect(find.textContaining('Till #9999 not registered'), findsOneWidget);

    // Pay button should be disabled for unregistered vendor
    final homePayBtn = tester.widget<ElevatedButton>(find.byKey(const Key('homePrimaryActionButton')));
    expect(homePayBtn.onPressed, isNull);

    // 2. Re-enter valid code '4523' on Merchant screen
    await tester.enterText(homeZippyField, '4523');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('homeVendorNotFoundMessage')), findsNothing);
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text("Siya's Tuck Shop & Spaza"), findsOneWidget);
    expect(find.byKey(const Key('homeVendorBankDetailsCard')), findsOneWidget);
    expect(find.textContaining('Capitec Bank'), findsWidgets);

    // 3. Out-of-order race condition test: enter valid '4523' and immediately delete last digit
    await tester.enterText(homeZippyField, '4523');
    await tester.pump();
    await tester.enterText(homeZippyField, '452');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text("Siya's Tuck Shop & Spaza"), findsNothing);
    expect(find.byKey(const Key('homeVendorBankDetailsCard')), findsNothing);
  });

  testWidgets('Tactile numpad edge cases: consecutive decimal points, leading zeros, backspacing to zero, and length limits', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // 1. Initial amount starts at '0'
    expect(find.text('0'), findsWidgets);

    // Backspacing when already '0' stays '0'
    await tester.tap(find.byKey(const Key('numpad_backspace')));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsWidgets);

    // Multiple leading zeros stay '0'
    await tester.tap(find.byKey(const Key('numpad_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('numpad_0')));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsWidgets);

    // 2. Press dot: becomes '0.'
    await tester.tap(find.byKey(const Key('numpad_.')));
    await tester.pumpAndSettle();
    expect(find.text('0.'), findsOneWidget);

    // Consecutive dot press is ignored
    await tester.tap(find.byKey(const Key('numpad_.')));
    await tester.pumpAndSettle();
    expect(find.text('0.'), findsOneWidget);

    // Enter cents '5' then '0'
    await tester.tap(find.byKey(const Key('numpad_5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('numpad_0')));
    await tester.pumpAndSettle();
    expect(find.text('0.50'), findsOneWidget);

    // Third decimal digit is ignored (max 2 decimal places)
    await tester.tap(find.byKey(const Key('numpad_9')));
    await tester.pumpAndSettle();
    expect(find.text('0.50'), findsOneWidget);

    // 3. Backspace tests
    await tester.tap(find.byKey(const Key('numpad_backspace')));
    await tester.pumpAndSettle();
    expect(find.text('0.5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('numpad_backspace')));
    await tester.pumpAndSettle();
    expect(find.text('0.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('numpad_backspace')));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsWidgets);

    // 4. Max length boundary test (up to 8 digits)
    for (int i = 0; i < 12; i++) {
      await tester.tap(find.byKey(const Key('numpad_9')));
      await tester.pumpAndSettle();
    }
    // Amount display should be capped at 8 digits: 99999999
    expect(find.text('99999999'), findsOneWidget);
  });

  testWidgets('SplitFareScreen clears stale active split and opens clean form when navigating from receipt', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // 1. Visit Split Fare tab and dispatch a split so _activeSplit is active
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    // Enter bill total 300
    await tester.tap(find.byKey(const Key('numpad_3')));
    await tester.tap(find.byKey(const Key('numpad_0')));
    await tester.tap(find.byKey(const Key('numpad_0')));
    await tester.pumpAndSettle();

    // Advance through Step 1 and Step 2
    await tester.tap(find.byKey(const Key('splitStep1Continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('splitStep2Continue')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dispatchSplitButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verify Split Settlement Live dashboard is currently showing
    expect(find.text('Split Settlement Live'), findsOneWidget);

    // 2. Return to Merchant tab
    await tester.tap(find.byIcon(Icons.storefront_outlined));
    await tester.pumpAndSettle();

    // 3. Select vendor Siya's Tuck Shop (#4523, R45) and pay
    await tester.tap(find.byKey(const Key('quick_vendor_4523')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('homePrimaryActionButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmPaymentButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Payment Succeeded'), findsOneWidget);

    // 4. Tap "Split this bill with friends?"
    await tester.tap(find.byKey(const Key('splitBillButton')));
    await tester.pumpAndSettle();

    // 5. Must show Split Fare form (prefilled with 45), NOT the old Split Settlement Live dashboard!
    expect(find.text('Split Fare ⚡'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.textContaining("Bill at Siya's Tuck Shop"), findsOneWidget);
    expect(find.text('Split Settlement Live'), findsNothing);
    expect(find.byKey(const Key('splitStep1Continue')), findsOneWidget);
  });

  testWidgets('Quick Pay vendor selection clears previous vendor not found error banner', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // 1. Enter unknown till code '9999'
    final homeZippyField = find.byKey(const Key('homeZippyNumberField'));
    await tester.enterText(homeZippyField, '9999');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // Expect not found banner
    expect(find.byKey(const Key('homeVendorNotFoundMessage')), findsOneWidget);

    // 2. Tap Quick Pay card for Siya's Tuck Shop (#4523)
    await tester.tap(find.byKey(const Key('quick_vendor_4523')));
    await tester.pumpAndSettle();

    // 3. Error banner MUST be cleared, and verified vendor details card MUST show
    expect(find.byKey(const Key('homeVendorNotFoundMessage')), findsNothing);
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text("Siya's Tuck Shop & Spaza"), findsOneWidget);
    expect(find.byKey(const Key('homeVendorBankDetailsCard')), findsOneWidget);
  });

  testWidgets('TactileScale resets pressed scale when disabled via didUpdateWidget', (WidgetTester tester) async {
    bool enabled = true;
    late StateSetter setHarnessState;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHarnessState = setState;
              return TactileScale(
                enabled: enabled,
                child: Container(
                  key: const Key('testChild'),
                  width: 100,
                  height: 50,
                  color: Colors.blue,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Start gesture (pointer down)
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('testChild'))));
    await tester.pump();

    // Verify AnimatedScale has started scaling down
    AnimatedScale scaleWidget = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scaleWidget.scale, 0.96);

    // Disable widget while pointer is still down
    setHarnessState(() {
      enabled = false;
    });
    await tester.pump();

    // Scale must reset to 1.0 immediately upon disabling
    scaleWidget = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scaleWidget.scale, 1.0);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('ZarNumpad keys maintain touch target heights >= 48px', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'backspace'];
    for (final k in keys) {
      final keyFinder = find.byKey(Key('numpad_$k'));
      expect(keyFinder, findsOneWidget);
      final size = tester.getSize(keyFinder);
      expect(size.height, greaterThanOrEqualTo(48.0), reason: 'Numpad key $k height (${size.height}) is below 48px');
      expect(size.width, greaterThanOrEqualTo(48.0), reason: 'Numpad key $k width (${size.width}) is below 48px');
    }
  });

  testWidgets('SplitFareScreen guards against duplicate in-flight split creations', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // Navigate to Split Fare tab
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    // Enter bill total 300
    await tester.tap(find.byKey(const Key('numpad_3')));
    await tester.tap(find.byKey(const Key('numpad_0')));
    await tester.tap(find.byKey(const Key('numpad_0')));
    await tester.pumpAndSettle();

    // Advance through Step 1 and Step 2
    await tester.tap(find.byKey(const Key('splitStep1Continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('splitStep2Continue')));
    await tester.pumpAndSettle();

    final dispatchBtn = find.byKey(const Key('dispatchSplitButton'));
    expect(dispatchBtn, findsOneWidget);

    // Rapid double-tap on dispatch button
    await tester.tap(dispatchBtn);
    await tester.pump(); // In-flight state begins
    await tester.tap(dispatchBtn, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verify exactly one split was created
    expect(ZippyPaymentService.getRecentSplits().length, 1);
    expect(find.text('Split Settlement Live'), findsOneWidget);
  });

  testWidgets('Dual usage: role switcher toggles between Customer Mode and Merchant Hub', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    ZippyPaymentService.setActiveMerchant('4523');
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // Verify initial state is Customer Mode
    expect(find.text('Who are you paying?'), findsOneWidget);
    expect(find.byKey(const ValueKey('roleSwitcherButton')), findsOneWidget);
    expect(find.text('Pay Mode'), findsOneWidget);

    // Switch to Merchant Hub
    await tester.tap(find.byKey(const ValueKey('roleSwitcherButton')));
    await tester.pumpAndSettle();

    // Verify Merchant Hub view elements
    expect(find.text('Merchant Hub'), findsOneWidget);
    expect(find.text('Who are you paying?'), findsNothing);
    expect(find.byKey(const Key('merchantTillCodeDisplay')), findsOneWidget);
    expect(find.text('4523'), findsOneWidget);
    expect(find.byKey(const Key('merchantGrossSalesTile')), findsOneWidget);
    expect(find.byKey(const Key('merchantNetPayoutTile')), findsOneWidget);
    expect(find.byKey(const Key('merchantFeesTile')), findsOneWidget);
    expect(find.byKey(const Key('merchantSalesCountTile')), findsOneWidget);

    // Switch back to Customer Mode
    await tester.tap(find.byKey(const ValueKey('roleSwitcherButton')));
    await tester.pumpAndSettle();

    expect(find.text('Who are you paying?'), findsOneWidget);
    expect(find.text('Pay Mode'), findsOneWidget);
  });

  testWidgets('Merchant Hub: supports till code copy and QR modal for active merchant', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    ZippyPaymentService.setActiveMerchant('4523');
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // Switch to Merchant Hub
    await tester.tap(find.byKey(const ValueKey('roleSwitcherButton')));
    await tester.pumpAndSettle();

    // Test Copy Till Code
    final copyBtn = find.byKey(const Key('copyTillCodeButton'));
    expect(copyBtn, findsOneWidget);
    await tester.tap(copyBtn);
    await tester.pump();
    expect(find.text('Copied Zippy Till #4523 to clipboard!'), findsOneWidget);
    await tester.pumpAndSettle();

    // Test Display QR Modal
    final qrBtn = find.byKey(const Key('showQrCodeButton'));
    expect(qrBtn, findsOneWidget);
    await tester.tap(qrBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining("Siya's Tuck Shop"), findsWidgets);
    expect(find.textContaining('Scan to pay Till #4523'), findsOneWidget);

    // Close QR modal
    final closeBtn = find.byKey(const Key('closeQrModalButton'));
    expect(closeBtn, findsOneWidget);
    await tester.tap(closeBtn);
    await tester.pumpAndSettle();
  });

  testWidgets('Merchant Hub: allows registering a new 4-digit Zippy till number', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    ZippyPaymentService.resetMerchantData();
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // Switch to Merchant Hub (starts at registration onboarding when no till is active)
    await tester.tap(find.byKey(const ValueKey('roleSwitcherButton')));
    await tester.pumpAndSettle();

    // Verify registration view opened directly
    expect(find.text('Register Your Merchant Till'), findsOneWidget);
    expect(find.byKey(const Key('submitMerchantRegistrationButton')), findsOneWidget);

    // Enter business details
    await tester.enterText(find.byKey(const Key('merchantTradingNameField')), "Khaya's Fresh Produce");
    await tester.enterText(find.byKey(const Key('merchantOwnerNameField')), 'Khaya Dlamini');
    await tester.enterText(find.byKey(const Key('merchantPhoneField')), '+27 82 123 4567');
    await tester.enterText(find.byKey(const Key('merchantAccountNumberField')), '1234567890');
    await tester.enterText(find.byKey(const Key('merchantDesiredCodeField')), '9911');

    // Submit registration
    await tester.tap(find.byKey(const Key('submitMerchantRegistrationButton')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verify new merchant is active and till 9911 is displayed
    expect(find.text("Khaya's Fresh Produce"), findsOneWidget);
    expect(find.text('9911'), findsOneWidget);
  });

  testWidgets('Customer Mode: Ambient physical discovery via Scan Zippy modal', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // Verify ambient Scan button has min 48px touch target
    final scanBtn = find.byKey(const Key('connectScanZippy'));
    expect(scanBtn, findsOneWidget);
    expect(tester.getSize(scanBtn).height, greaterThanOrEqualTo(48.0));

    // Open Scan modal
    await tester.tap(scanBtn);
    await tester.pumpAndSettle();

    // Verify viewfinder and simulation trigger
    expect(find.text('Scan Zippy Countertop QR'), findsOneWidget);
    final simulateScan = find.byKey(const Key('scanSimulateButton_4523'));
    expect(simulateScan, findsOneWidget);
    expect(tester.getSize(simulateScan).height, greaterThanOrEqualTo(48.0));

    // Simulate scanning vendor #4523 stand
    await tester.tap(simulateScan);
    await tester.pumpAndSettle();

    // Verify merchant connected
    expect(find.text("Siya's Tuck Shop & Spaza"), findsOneWidget);
    expect(find.byKey(const Key('homeVendorBankDetailsCard')), findsOneWidget);

    // Test Clear / Change button
    final changeBtn = find.byKey(const Key('clearConnectedVendorButton'));
    expect(changeBtn, findsOneWidget);
    expect(tester.getSize(changeBtn).height, greaterThanOrEqualTo(48.0));
    await tester.tap(changeBtn);
    await tester.pumpAndSettle();

    // Should return to ambient connection mode
    expect(find.byKey(const Key('connectScanZippy')), findsOneWidget);
  });

  testWidgets('Customer Mode: Ambient proximity discovery via Nearby Merchants radar', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // Verify ambient Nearby button has min 48px touch target
    final nearbyBtn = find.byKey(const Key('connectNearbyMerchant'));
    expect(nearbyBtn, findsOneWidget);
    expect(tester.getSize(nearbyBtn).height, greaterThanOrEqualTo(48.0));

    // Open Nearby radar modal
    await tester.tap(nearbyBtn);
    await tester.pumpAndSettle();

    // Verify radar sheet and proximity list
    expect(find.text('Nearby Zippy Merchants'), findsOneWidget);
    expect(find.textContaining('within 15m'), findsOneWidget);

    final vendorCard4523 = find.byKey(const Key('nearbyConnectButton_4523'));
    expect(vendorCard4523, findsOneWidget);
    expect(tester.getSize(vendorCard4523).height, greaterThanOrEqualTo(48.0));
    expect(find.textContaining('3m away'), findsOneWidget);

    // Connect to nearby merchant #4523
    await tester.tap(vendorCard4523);
    await tester.pumpAndSettle();

    // Verify merchant connected
    expect(find.text("Siya's Tuck Shop & Spaza"), findsOneWidget);
    expect(find.byKey(const Key('homeVendorBankDetailsCard')), findsOneWidget);
  });

  testWidgets('Customer Mode: Ambient Tap-to-Pay pairing via NFC Tap modal', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // Verify ambient Tap button has min 48px touch target
    final tapBtn = find.byKey(const Key('connectNfcTap'));
    expect(tapBtn, findsOneWidget);
    expect(tester.getSize(tapBtn).height, greaterThanOrEqualTo(48.0));

    // Open NFC tap modal
    await tester.tap(tapBtn);
    await tester.pumpAndSettle();

    // Verify contactless simulation
    expect(find.text('Tap Merchant Terminal'), findsOneWidget);
    final simulateTap = find.byKey(const Key('nfcTapSimulateButton_4523'));
    expect(simulateTap, findsOneWidget);
    expect(tester.getSize(simulateTap).height, greaterThanOrEqualTo(48.0));

    // Tap to pair
    await tester.tap(simulateTap);
    await tester.pumpAndSettle();

    // Verify merchant connected
    expect(find.text("Siya's Tuck Shop & Spaza"), findsOneWidget);
    expect(find.byKey(const Key('homeVendorBankDetailsCard')), findsOneWidget);
  });

  testWidgets('Merchant Hub Triad: Accept (radar beacon) and Identify (audio chime)', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    ZippyPaymentService.setActiveMerchant('4523');
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // Switch to Merchant Hub
    await tester.tap(find.byKey(const ValueKey('roleSwitcherButton')));
    await tester.pumpAndSettle();

    // Pillar 1: ACCEPT - Verify Proximity Beacon is broadcasting
    expect(find.byKey(const Key('merchantProximityBeaconStatus')), findsOneWidget);
    expect(find.textContaining('Ambient Radar: Active'), findsOneWidget);

    // Pillar 3: IDENTIFY - Verify Audio Chime toggle button
    final chimeBtn = find.byKey(const Key('testChimeButton'));
    expect(chimeBtn, findsOneWidget);
    expect(tester.getSize(chimeBtn).height, greaterThanOrEqualTo(48.0));

    await tester.tap(chimeBtn);
    await tester.pump();
    expect(find.textContaining('Countertop Audio Chime: Ready'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('Merchant Hub Triad: Reconcile (daily ledger & CSV export)', (WidgetTester tester) async {
    configurePhoneDimensions(tester);
    ZippyPaymentService.setActiveMerchant('4523');
    await tester.pumpWidget(const ZippyApp());
    await tester.pumpAndSettle();

    // Switch to Merchant Hub
    await tester.tap(find.byKey(const ValueKey('roleSwitcherButton')));
    await tester.pumpAndSettle();

    // Pillar 2: RECONCILE - Verify Auto-Reconciled Ledger & CSV Export
    expect(find.byKey(const Key('merchantReconciliationCard')), findsOneWidget);
    expect(find.text('DAILY RECONCILIATION'), findsOneWidget);
    expect(find.text('Auto-Reconciled'), findsOneWidget);
    expect(find.textContaining('Matched against SARB PayShap'), findsOneWidget);

    final exportBtn = find.byKey(const Key('exportReconciliationButton'));
    expect(exportBtn, findsOneWidget);
    expect(tester.getSize(exportBtn).height, greaterThanOrEqualTo(48.0));

    // Tap Export CSV
    await tester.tap(exportBtn);
    await tester.pump();
    expect(find.textContaining('Daily settlement report exported'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('ZippyLogo renders custom vector Bilateral Split paths cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ZippyLogo(size: 64),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ZippyLogo), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
