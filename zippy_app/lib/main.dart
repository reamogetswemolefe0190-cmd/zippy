import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zippy_app/core/zippy_theme.dart';
import 'package:zippy_app/models/vendor_model.dart';
import 'package:zippy_app/screens/merchant_dashboard_screen.dart';
import 'package:zippy_app/screens/split_fare_screen.dart';
import 'package:zippy_app/services/zippy_payment_service.dart';
import 'package:zippy_app/services/zippy_storage_service.dart';
import 'package:zippy_app/widgets/tactile_scale.dart';
import 'package:zippy_app/widgets/zar_numpad.dart';
import 'package:zippy_app/widgets/zippy_logo.dart';

void main() {
  runApp(const ZippyApp());
}

/// Root widget of the Zippy mobile application.
class ZippyApp extends StatelessWidget {
  /// Creates the root [ZippyApp].
  const ZippyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zippy ZA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ZippyTheme.background,
        colorScheme: const ColorScheme.dark(
          primary: ZippyTheme.primaryGreen,
          secondary: ZippyTheme.primaryGreen,
          surface: ZippyTheme.surface,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Primary role context of the app (Customer vs Merchant).
enum AppRole {
  /// Customer payer mode (pay merchants and split bills).
  customer,

  /// Merchant owner mode (manage till, view QR, track income & payments).
  merchant,
}

/// Active payment mode on the unified home screen.
enum PaymentMode {
  /// Merchant payment using 4-digit Zippy till code.
  merchant,

  /// Social bill split with 1-tap payback.
  splitFare,
}

/// Home dashboard view of Zippy providing unified payment and split rails.
class HomeScreen extends StatefulWidget {
  /// Creates the [HomeScreen].
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _splitNavigationVersion = 0;
  double? _prefillSplitTotal;
  String? _prefillSplitTitle;

  // Single initial screen unified state
  AppRole _appRole = AppRole.customer;
  PaymentMode _paymentMode = PaymentMode.merchant;
  late final TextEditingController _merchantZippyController;
  late final TextEditingController _splitTitleController;

  String _amountStr = '0';
  VendorModel? _lookedUpVendor;
  bool _isLoadingVendor = false;
  bool _vendorNotFound = false;
  bool _isProcessing = false;
  Map<String, dynamic>? _receipt;

  final List<String> _splitFriends = ['Lerato Molefe', 'Sipho Ndlovu', 'Kamohelo Sithole'];

  @override
  void initState() {
    super.initState();
    _merchantZippyController = TextEditingController();
    _splitTitleController = TextEditingController();
    _restoreStoredState();
  }

  Future<void> _restoreStoredState() async {
    try {
      await ZippyPaymentService.initializeStorage();
      final lastRole = await ZippyStorageService.getLastActiveRole();
      if (mounted && lastRole != null) {
        setState(() {
          if (lastRole == 'merchant') {
            _appRole = AppRole.merchant;
          } else {
            _appRole = AppRole.customer;
          }
        });
      }
    } catch (_) {
      // Storage fallback gracefully handled
    }
  }

  @override
  void dispose() {
    _merchantZippyController.dispose();
    _splitTitleController.dispose();
    super.dispose();
  }

  Future<void> _lookupMerchant(String number) async {
    final clean = number.replaceAll(RegExp(r'\D'), '').trim();
    if (clean.length == 4) {
      setState(() {
        _isLoadingVendor = true;
        _vendorNotFound = false;
      });
      try {
        final v = await ZippyPaymentService.lookupVendor(clean);
        if (mounted) {
          final current = _merchantZippyController.text.replaceAll(RegExp(r'\D'), '').trim();
          if (current != clean) return;
          setState(() {
            _lookedUpVendor = v;
            _isLoadingVendor = false;
            _vendorNotFound = (v == null);
          });
        }
      } catch (_) {
        if (mounted) {
          final current = _merchantZippyController.text.replaceAll(RegExp(r'\D'), '').trim();
          if (current != clean) return;
          setState(() {
            _lookedUpVendor = null;
            _isLoadingVendor = false;
            _vendorNotFound = true;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _lookedUpVendor = null;
          _isLoadingVendor = false;
          _vendorNotFound = false;
        });
      }
    }
  }

  void _onNumpad(String val) {
    setState(() {
      if (val == 'backspace') {
        if (_amountStr.isEmpty || _amountStr.length <= 1) {
          _amountStr = '0';
        } else {
          _amountStr = _amountStr.substring(0, _amountStr.length - 1);
          if (_amountStr.isEmpty) _amountStr = '0';
        }
      } else if (val == '.') {
        if (_amountStr.isEmpty) {
          _amountStr = '0.';
        } else if (!_amountStr.contains('.')) {
          _amountStr += '.';
        }
      } else {
        if (_amountStr.replaceAll('.', '').length >= 8) return;
        if (_amountStr.contains('.')) {
          final parts = _amountStr.split('.');
          if (parts.length > 1 && parts[1].length >= 2) return;
        }
        _amountStr = _amountStr == '0' ? val : _amountStr + val;
      }
    });
  }

  Future<void> _handleUnifiedAction() async {
    if (_amountStr.endsWith('.')) {
      _amountStr = _amountStr.substring(0, _amountStr.length - 1);
    }
    final double? amount = double.tryParse(_amountStr);
    if (amount == null || amount <= 0 || _isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      if (_paymentMode == PaymentMode.merchant) {
        if (_lookedUpVendor == null) return;
        final res = await ZippyPaymentService.payMerchant(
          vendor: _lookedUpVendor!,
          grossAmount: amount,
          customerName: 'Thabo Mbeki',
        );
        if (mounted) {
          setState(() {
            _receipt = res;
          });
        }
      } else {
        // Split Fare mode
        await ZippyPaymentService.createSplit(
          title: _splitTitleController.text.trim().isNotEmpty
              ? _splitTitleController.text.trim()
              : 'Split Bill',
          totalAmount: amount,
          hostName: 'Thabo Mbeki',
          friendNames: _splitFriends,
        );
        if (mounted) {
          setState(() {
            _prefillSplitTotal = amount;
            _prefillSplitTitle = _splitTitleController.text;
            _currentIndex = 1; // Transition to dedicated Split screen dashboard
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _onQuickPayVendorSelected(VendorModel vendor, double defaultAmount) {
    setState(() {
      _paymentMode = PaymentMode.merchant;
      _merchantZippyController.text = vendor.zippyNumber;
      _lookedUpVendor = vendor;
      _isLoadingVendor = false;
      _vendorNotFound = false;
      _amountStr = defaultAmount % 1 == 0
          ? defaultAmount.toInt().toString()
          : defaultAmount.toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZippyTheme.background,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.02),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _receipt != null
              ? KeyedSubtree(
                  key: const ValueKey('receipt_view'),
                  child: _buildHomeReceiptView(),
                )
              : SingleChildScrollView(
                  key: const ValueKey('home_main_scroll_view'),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Persistent Brand Header: Zippy + Pay simply. + Role Switcher
                      _buildBrandHeader(),
                      const SizedBox(height: 12),

                      if (_appRole == AppRole.merchant)
                        KeyedSubtree(
                          key: const ValueKey('merchant_dashboard_view'),
                          child: MerchantDashboardScreen(
                            onSwitchToCustomer: () {
                              setState(() {
                                _appRole = AppRole.customer;
                              });
                              ZippyStorageService.saveLastActiveRole('customer');
                            },
                          ),
                        )
                      else ...[
                        // 2. Persistent Inquiry & Segmented Animated Mode Switcher
                        _buildModePromptAndSegmentedControl(),
                        const SizedBox(height: 16),

                        // 3. Dynamic Mode Body Content with smooth cross-fade/slide
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.02),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _currentIndex == 0
                              ? KeyedSubtree(
                                  key: const ValueKey('merchant_view_mode'),
                                  child: _buildMerchantBody(),
                                )
                              : KeyedSubtree(
                                  key: ValueKey('split_fare_view_$_splitNavigationVersion'),
                                  child: SplitFareScreen(
                                    key: ValueKey('split_fare_screen_$_splitNavigationVersion'),
                                    initialTotal: _prefillSplitTotal,
                                    initialTitle: _prefillSplitTitle,
                                  ),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    final bool isMerchant = _appRole == AppRole.merchant;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: ZippyTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Center(
                child: ZippyLogo(
                  size: 26,
                  primaryColor: Colors.white,
                  accentColor: ZippyTheme.primaryGreen,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'zippy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Pay simply.',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          key: const ValueKey('roleSwitcherButton'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            final nextRole = isMerchant ? AppRole.customer : AppRole.merchant;
            setState(() {
              _appRole = nextRole;
            });
            ZippyStorageService.saveLastActiveRole(nextRole == AppRole.merchant ? 'merchant' : 'customer');
          },
          child: TactileScale(
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isMerchant
                  ? ZippyTheme.primaryGreen.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isMerchant
                    ? ZippyTheme.primaryGreen.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isMerchant ? Icons.storefront_rounded : Icons.person_outline_rounded,
                  size: 15,
                  color: isMerchant ? ZippyTheme.primaryGreen : Colors.white70,
                ),
                const SizedBox(width: 5),
                Text(
                  isMerchant ? 'Merchant Hub' : 'Pay Mode',
                  style: TextStyle(
                    color: isMerchant ? ZippyTheme.primaryGreen : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.swap_horiz_rounded,
                  size: 14,
                  color: isMerchant ? ZippyTheme.primaryGreen : Colors.white38,
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

  Widget _buildModePromptAndSegmentedControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Who are you paying?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 58,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: ZippyTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ZippyTheme.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double pillWidth = constraints.maxWidth / 2;
              final double pillHeight = constraints.maxHeight;

              return Stack(
                children: [
                  // Animated sliding spring indicator
                  AnimatedAlign(
                    alignment: _currentIndex == 0
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      width: pillWidth,
                      height: pillHeight,
                      decoration: BoxDecoration(
                        color: ZippyTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: ZippyTheme.primaryGreen.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Pill selection touch targets (min 48px touch target)
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          key: const Key('merchantModeCard'),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _paymentMode = PaymentMode.merchant;
                              _currentIndex = 0;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: constraints.maxHeight,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _currentIndex == 0
                                      ? Icons.storefront
                                      : Icons.storefront_outlined,
                                  size: 18,
                                  color: _currentIndex == 0
                                      ? Colors.black
                                      : Colors.white70,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Merchant',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _currentIndex == 0
                                        ? Colors.black
                                        : Colors.white70,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          key: const Key('splitFareModeCard'),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _paymentMode = PaymentMode.splitFare;
                              _currentIndex = 1;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: constraints.maxHeight,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _currentIndex == 1
                                      ? Icons.people
                                      : Icons.people_outline,
                                  size: 18,
                                  color: _currentIndex == 1
                                      ? Colors.black
                                      : Colors.white70,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Split Fare',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _currentIndex == 1
                                        ? Colors.black
                                        : Colors.white70,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMerchantBody() {
    final double amount = double.tryParse(_amountStr) ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick-Pay Recent Vendors (Horizontal Cards)
        const Text(
          'QUICK PAY RECENT',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildQuickVendorCard(
                vendorKey: 'quick_vendor_4523',
                tillNumber: '4523',
                name: "Siya's Tuck Shop",
                timeAgo: 'Yesterday',
                amount: 45.0,
              ),
              const SizedBox(width: 8),
              _buildQuickVendorCard(
                vendorKey: 'quick_vendor_1082',
                tillNumber: '1082',
                name: "Mama Thembi's",
                timeAgo: '2 days ago',
                amount: 25.0,
              ),
              const SizedBox(width: 8),
              _buildQuickVendorCard(
                vendorKey: 'quick_vendor_8831',
                tillNumber: '8831',
                name: "Sipho's Butchery",
                timeAgo: 'Last week',
                amount: 120.0,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Recipient Card with animated vendor verification reveal
        _buildRecipientSection(),
        const SizedBox(height: 12),

        // Hero Amount Display: "You're paying" + R45.00 with optical scaling
        _buildAmountSection(),
        const SizedBox(height: 12),

        // Tactile ZarNumpad with 0.96 scale press-down animation
        ZarNumpad(onKeyPressed: _onNumpad),
        const SizedBox(height: 16),

        // Visual Conclusion CTA: [ Pay R45.00 ] with TactileScale micro-interaction
        TactileScale(
          enabled: amount > 0 && !_isProcessing && _lookedUpVendor != null,
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              key: const Key('homePrimaryActionButton'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ZippyTheme.primaryGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: (amount > 0 && !_isProcessing && _lookedUpVendor != null)
                  ? _showPaymentConfirmationModal
                  : null,
              child: _isProcessing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'Pay R ${_amountStr.endsWith('.') ? _amountStr.substring(0, _amountStr.length - 1) : _amountStr}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildAmountSection() {
    final double fontSize = _amountStr.length >= 7
        ? 30.0
        : _amountStr.length >= 5
            ? 38.0
            : 48.0;

    return Center(
      child: Column(
        children: [
          const Text(
            "You're paying",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'R ',
                style: TextStyle(
                  color: ZippyTheme.primaryGreen,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
                child: Text(
                  _amountStr,
                  key: const Key('homeAmountDisplay'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZippyTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _lookedUpVendor != null
              ? ZippyTheme.primaryGreen.withValues(alpha: 0.3)
              : ZippyTheme.border,
        ),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paying',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Till Code',
                  style: TextStyle(
                    color: ZippyTheme.primaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ZippyTheme.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.storefront,
                    color: ZippyTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _lookedUpVendor?.name ?? 'Enter Till Number',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_lookedUpVendor != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: ZippyTheme.primaryGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: ZippyTheme.primaryGreen, width: 0.8),
                              ),
                              child: const Text(
                                'VERIFIED',
                                style: TextStyle(
                                  color: ZippyTheme.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _lookedUpVendor != null
                            ? '✓ Verified • ${_lookedUpVendor!.bankName}'
                            : '4-digit code required',
                        style: TextStyle(
                          color: _lookedUpVendor != null
                              ? ZippyTheme.primaryGreen
                              : Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoadingVendor)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: ZippyTheme.primaryGreen),
                  )
                else
                  Container(
                    width: 80,
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ZippyTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: TextField(
                      key: const Key('homeZippyNumberField'),
                      controller: _merchantZippyController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                        hintText: '####',
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                      ),
                      onChanged: (val) => _lookupMerchant(val),
                    ),
                  ),
              ],
            ),
            if (_lookedUpVendor != null) ...[
              const SizedBox(height: 10),
              Container(
                key: const Key('homeVendorBankDetailsCard'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ZippyTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance, size: 14, color: ZippyTheme.primaryGreen),
                        const SizedBox(width: 6),
                        Text(
                          '${_lookedUpVendor!.bankName} (•••• ${_lookedUpVendor!.accountNumber.length >= 4 ? _lookedUpVendor!.accountNumber.substring(_lookedUpVendor!.accountNumber.length - 4) : _lookedUpVendor!.accountNumber})',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _lookedUpVendor!.category,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
            if (_vendorNotFound) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Till #${_merchantZippyController.text} not registered on Zippy',
                      key: const Key('homeVendorNotFoundMessage'),
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickVendorCard({
    required String vendorKey,
    required String tillNumber,
    required String name,
    required String timeAgo,
    required double amount,
  }) {
    return InkWell(
      key: Key(vendorKey),
      onTap: () {
        final vendor = ZippyPaymentService.recentVendors.firstWhere(
          (v) => v.zippyNumber == tillNumber,
          orElse: () => VendorModel(
            zippyNumber: tillNumber,
            name: name,
            category: 'Spaza',
            ownerName: 'Vendor Owner',
            bankName: 'Capitec Bank',
            accountNumber: '1000000000',
            phoneNumber: '+27 82 000 0000',
          ),
        );
        _onQuickPayVendorSelected(vendor, amount);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ZippyTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ZippyTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  color: ZippyTheme.primaryGreen,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'R ${amount.toInt()} • $timeAgo',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentConfirmationModal() {
    final double amount = double.tryParse(_amountStr) ?? 0.0;
    showModalBottomSheet(
      context: context,
      backgroundColor: ZippyTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Confirm payment',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'R ${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ZippyTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ZippyTheme.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recipient', style: TextStyle(color: Colors.white60, fontSize: 13)),
                        Text(
                          _lookedUpVendor?.name ?? 'Merchant',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Bank & Status', style: TextStyle(color: Colors.white60, fontSize: 13)),
                        Text(
                          '${_lookedUpVendor?.bankName ?? 'Capitec Bank'} • Verified ✓',
                          style: const TextStyle(color: ZippyTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Payment fee', style: TextStyle(color: Colors.white60, fontSize: 13)),
                        Text('R 0.00 (Free)', style: TextStyle(color: ZippyTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          'R ${amount.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TactileScale(
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    key: const Key('confirmPaymentButton'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZippyTheme.primaryGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleUnifiedAction();
                    },
                    child: const Text(
                      'Confirm Payment',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white60, fontSize: 14)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeReceiptView() {
    final double gross = (_receipt!['grossAmount'] as num).toDouble();
    final double netPayout = (_receipt!['netVendorPayout'] as num).toDouble();
    final double zippyFee = (_receipt!['zippyFee'] as num).toDouble();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ZippyTheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: ZippyTheme.primaryGreen.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: ZippyTheme.primaryGreen, size: 64),
              const SizedBox(height: 12),
              const Text(
                'Payment Succeeded',
                style: TextStyle(
                  color: ZippyTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'R ${gross.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Paid to ${_lookedUpVendor!.name}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFF334155)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment Reference:', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  Text(
                    '${_receipt!['authCode']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Settlement Method:', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  Text(
                    'Direct to ${_lookedUpVendor!.bankName}',
                    style: const TextStyle(
                      color: ZippyTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Merchant Settlement (97.5%):', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  Text(
                    'R ${netPayout.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Service Fee (2.5%):', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  Text(
                    'R ${zippyFee.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('SMS Confirmation:', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  Text(
                    'Delivered to ${_lookedUpVendor!.phoneNumber}',
                    style: const TextStyle(color: ZippyTheme.primaryGreen, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Prominent "Split this bill with friends?" Button with TactileScale
              TactileScale(
                child: ElevatedButton.icon(
                  key: const Key('splitBillButton'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZippyTheme.primaryGreen,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _receipt = null;
                      _paymentMode = PaymentMode.splitFare;
                      _amountStr = gross % 1 == 0
                          ? gross.toInt().toString()
                          : gross.toStringAsFixed(2);
                      _splitTitleController.text = 'Bill at ${_lookedUpVendor!.name}';
                      _prefillSplitTotal = gross;
                      _prefillSplitTitle = 'Bill at ${_lookedUpVendor!.name}';
                      _splitNavigationVersion++;
                      _currentIndex = 1; // Jump directly to Split Fare screen with prefilled values
                    });
                  },
                  icon: const Icon(Icons.people, color: Colors.black),
                  label: const Text(
                    'Split this bill with friends?',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                onPressed: () {
                  setState(() {
                    _receipt = null;
                    _currentIndex = 0;
                    _paymentMode = PaymentMode.merchant;
                    _amountStr = '0';
                    _prefillSplitTotal = null;
                    _prefillSplitTitle = null;
                  });
                },
                child: const Text(
                  'Make another payment',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
