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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: ZippyTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Center(
                child: ZippyLogo(
                  size: 22,
                  primaryColor: Colors.white,
                  accentColor: ZippyTheme.primaryGreen,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'zippy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isMerchant
                    ? ZippyTheme.primaryGreen.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isMerchant
                      ? ZippyTheme.primaryGreen.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMerchant ? Icons.storefront_rounded : Icons.person_outline_rounded,
                    size: 14,
                    color: isMerchant ? ZippyTheme.primaryGreen : Colors.white70,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isMerchant ? 'Merchant Hub' : 'Pay Mode',
                    style: TextStyle(
                      color: isMerchant ? ZippyTheme.primaryGreen : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.swap_horiz_rounded,
                    size: 13,
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
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 58,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double pillWidth = constraints.maxWidth / 2;
              final double pillHeight = constraints.maxHeight;

              return Stack(
                children: [
                  // Animated sliding slate indicator (refined slate instead of bulky neon)
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
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 6,
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
                          borderRadius: BorderRadius.circular(11),
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
                                  size: 16,
                                  color: _currentIndex == 0
                                      ? ZippyTheme.primaryGreen
                                      : Colors.white60,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Merchant',
                                  style: TextStyle(
                                    fontWeight: _currentIndex == 0
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 13,
                                    color: _currentIndex == 0
                                        ? Colors.white
                                        : Colors.white60,
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
                          borderRadius: BorderRadius.circular(11),
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
                                  size: 16,
                                  color: _currentIndex == 1
                                      ? ZippyTheme.splitPurple
                                      : Colors.white60,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Split Fare',
                                  style: TextStyle(
                                    fontWeight: _currentIndex == 1
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 13,
                                    color: _currentIndex == 1
                                        ? Colors.white
                                        : Colors.white60,
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
        // 1. Recipient Input Card on top
        _buildRecipientSection(),
        const SizedBox(height: 10),

        // 2. Light secondary Quick Pay Recent Chips immediately below Recipient
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            'QUICK PAY RECENT',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
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
                timeAgo: '2d ago',
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
        const SizedBox(height: 6),

        // 3. Dominant Visual Center: Hero Amount Display (Uncarded, Generous Breathing Room)
        _buildAmountSection(),

        // 4. Tactile ZarNumpad with 0.96 scale press-down animation
        ZarNumpad(onKeyPressed: _onNumpad),
        const SizedBox(height: 16),

        // 5. Visual Conclusion CTA: [ Pay R45.00 ] with TactileScale micro-interaction
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
    final double amount = double.tryParse(_amountStr) ?? 0.0;
    final double fontSize = _amountStr.length >= 7
        ? 34.0
        : _amountStr.length >= 5
            ? 44.0
            : 56.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            const Text(
              "You're paying",
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'R ',
                  style: TextStyle(
                    color: amount > 0 ? ZippyTheme.primaryGreen : Colors.white38,
                    fontSize: fontSize * 0.52,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
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
      ),
    );
  }

  Widget _buildRecipientSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _lookedUpVendor != null
              ? ZippyTheme.primaryGreen.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_lookedUpVendor == null) ...[
            // Ambient Connection Header
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connect to Merchant',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Point camera, radar proximity, or tap phone',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3 Ambient Physical Discovery Modes (Min 48px touch targets)
            Row(
              children: [
                // 1. Scan Zippy
                Expanded(
                  child: TactileScale(
                    child: InkWell(
                      key: const Key('connectScanZippy'),
                      onTap: _openQrScannerModal,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16C784).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF16C784).withValues(alpha: 0.35)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner_rounded, size: 16, color: ZippyTheme.primaryGreen),
                            SizedBox(width: 5),
                            Text(
                              'Scan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Nearby Radar
                Expanded(
                  child: TactileScale(
                    child: InkWell(
                      key: const Key('connectNearbyMerchant'),
                      onTap: _openNearbyRadarModal,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.radar_rounded, size: 16, color: Color(0xFF38BDF8)),
                            SizedBox(width: 5),
                            Text(
                              'Nearby',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 3. NFC Tap
                Expanded(
                  child: TactileScale(
                    child: InkWell(
                      key: const Key('connectNfcTap'),
                      onTap: _openNfcTapModal,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.contactless_rounded, size: 16, color: Color(0xFFA78BFA)),
                            SizedBox(width: 5),
                            Text(
                              'Tap',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Discreet 4-Digit Till Fallback
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tag_rounded, size: 15, color: Colors.white38),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Or manual 4-digit till #',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Container(
                    width: 76,
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                        hintText: '####',
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                      ),
                      onChanged: (val) => _lookupMerchant(val),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Connected Verified Merchant Card
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: ZippyTheme.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: ZippyTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _lookedUpVendor!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '✓ Verified • ${_lookedUpVendor!.bankName} • Till #${_lookedUpVendor!.zippyNumber}',
                        style: const TextStyle(
                          color: ZippyTheme.primaryGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 68,
                  constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 15),
                      hintText: '####',
                      hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                    ),
                    onChanged: (val) => _lookupMerchant(val),
                  ),
                ),
                const SizedBox(width: 6),
                TactileScale(
                  child: InkWell(
                    key: const Key('clearConnectedVendorButton'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _merchantZippyController.clear();
                        _lookedUpVendor = null;
                        _vendorNotFound = false;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Text(
                        'Change',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              key: const Key('homeVendorBankDetailsCard'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance, size: 13, color: ZippyTheme.primaryGreen),
                      const SizedBox(width: 5),
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
          if (_isLoadingVendor)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ZippyTheme.primaryGreen),
                ),
              ),
            ),
          if (_vendorNotFound) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 13),
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
    );
  }

  void _openQrScannerModal() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZippyTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
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
              const SizedBox(height: 18),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner_rounded, color: ZippyTheme.primaryGreen, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Scan Zippy Countertop QR',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Point camera at countertop acrylic stand, bill sticker, or till QR',
                style: TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Viewfinder simulation with laser line
              Container(
                width: 220,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ZippyTheme.primaryGreen, width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 120, color: Colors.white12),
                    Container(
                      width: 190,
                      height: 2,
                      decoration: BoxDecoration(
                        color: ZippyTheme.primaryGreen,
                        boxShadow: [
                          BoxShadow(
                            color: ZippyTheme.primaryGreen.withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'DETECTED IN VIEWFINDER:',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('scanSimulateButton_4523'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZippyTheme.primaryGreen,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(ctx);
                    _connectMerchantByCode('4523');
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text(
                    "Siya's Tuck Shop (#4523) • Stand QR",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('closeQrScannerModalButton'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: ZippyTheme.border),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel Scan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openNearbyRadarModal() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZippyTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
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
              const SizedBox(height: 18),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.radar_rounded, color: Color(0xFF38BDF8), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Nearby Zippy Merchants',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Ambient PayShap & Bluetooth radar detecting merchants within 15m',
                style: TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              _buildNearbyMerchantTile(
                ctx: ctx,
                keyStr: 'nearbyConnectButton_4523',
                tillNumber: '4523',
                name: "Siya's Tuck Shop & Spaza",
                distance: '3m away',
                signalLabel: 'Strong',
                signalColor: ZippyTheme.primaryGreen,
              ),
              const SizedBox(height: 8),
              _buildNearbyMerchantTile(
                ctx: ctx,
                keyStr: 'nearbyConnectButton_1082',
                tillNumber: '1082',
                name: "Mama Thembi's Vetkoek",
                distance: '8m away',
                signalLabel: 'Good',
                signalColor: const Color(0xFFFBBF24),
              ),
              const SizedBox(height: 8),
              _buildNearbyMerchantTile(
                ctx: ctx,
                keyStr: 'nearbyConnectButton_8831',
                tillNumber: '8831',
                name: "Sipho's Butchery",
                distance: '15m away',
                signalLabel: 'Fair',
                signalColor: Colors.white54,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('closeNearbyRadarModalButton'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: ZippyTheme.border),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close Radar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNearbyMerchantTile({
    required BuildContext ctx,
    required String keyStr,
    required String tillNumber,
    required String name,
    required String distance,
    required String signalLabel,
    required Color signalColor,
  }) {
    return InkWell(
      key: Key(keyStr),
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.pop(ctx);
        _connectMerchantByCode(tillNumber);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ZippyTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: signalColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.storefront_rounded, color: signalColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$distance • Signal: $signalLabel • #$tillNumber',
                    style: TextStyle(color: signalColor, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: ZippyTheme.primaryGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ZippyTheme.primaryGreen.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'Connect',
                style: TextStyle(
                  color: ZippyTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNfcTapModal() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZippyTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
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
              const SizedBox(height: 18),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.contactless_rounded, color: Color(0xFFA78BFA), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Tap Merchant Terminal',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Hold top of phone against merchant NFC sticker, countertop tag, or phone',
                style: TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFFA78BFA).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA78BFA).withValues(alpha: 0.4), width: 2),
                ),
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFA78BFA).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.contactless_rounded,
                      size: 48,
                      color: Color(0xFFA78BFA),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('nfcTapSimulateButton_4523'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA78BFA),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    Navigator.pop(ctx);
                    _connectMerchantByCode('4523');
                  },
                  icon: const Icon(Icons.nfc_rounded, size: 18),
                  label: const Text(
                    "Simulate Tap on Siya's Tuck Shop (#4523)",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('closeNfcModalButton'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: ZippyTheme.border),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel NFC', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _connectMerchantByCode(String code) {
    _merchantZippyController.text = code;
    _lookupMerchant(code);
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: ZippyTheme.primaryGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: ZippyTheme.primaryGreen,
                size: 13,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'R ${amount.toInt()}',
                style: const TextStyle(
                  color: ZippyTheme.primaryGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
