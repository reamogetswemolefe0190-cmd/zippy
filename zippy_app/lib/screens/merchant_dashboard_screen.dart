import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zippy_app/core/zippy_theme.dart';
import 'package:zippy_app/models/transaction_model.dart';
import 'package:zippy_app/models/vendor_model.dart';
import 'package:zippy_app/services/zippy_payment_service.dart';
import 'package:zippy_app/widgets/tactile_scale.dart';

/// Screen allowing merchants to register a 4-digit Zippy till number, display their counter QR/code,
/// and monitor real-time gross income, 2.5% service fees, and net bank payouts.
class MerchantDashboardScreen extends StatefulWidget {
  /// Optional callback invoked when user requests to switch to customer mode.
  final VoidCallback? onSwitchToCustomer;

  /// Creates a [MerchantDashboardScreen].
  const MerchantDashboardScreen({super.key, this.onSwitchToCustomer});

  @override
  State<MerchantDashboardScreen> createState() => _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  bool _isRegisteringNew = false;
  bool _isSubmittingRegistration = false;
  String? _selectedCategory = 'Spaza Shop';
  String _selectedBank = 'Capitec Bank';

  late final TextEditingController _nameCtrl;
  late final TextEditingController _ownerCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _accountCtrl;
  late final TextEditingController _customCodeCtrl;

  final List<String> _categories = const [
    'Spaza Shop',
    'Street Food',
    'Tavern & Dining',
    'Salon & Barber',
    'Transport & Taxi',
    'Retail Store',
  ];

  final List<String> _supportedBanks = const [
    'Capitec Bank',
    'FNB',
    'Standard Bank',
    'Nedbank',
    'Absa',
    'TymeBank',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _ownerCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _accountCtrl = TextEditingController();
    _customCodeCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ownerCtrl.dispose();
    _phoneCtrl.dispose();
    _accountCtrl.dispose();
    _customCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final name = _nameCtrl.text.trim();
    final owner = _ownerCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final account = _accountCtrl.text.trim();

    if (name.isEmpty || owner.isEmpty || phone.isEmpty || account.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all business and banking details'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSubmittingRegistration = true);
    try {
      final vendor = await ZippyPaymentService.registerVendor(
        name: name,
        category: _selectedCategory ?? 'Spaza Shop',
        ownerName: owner,
        phoneNumber: phone,
        bankName: _selectedBank,
        accountNumber: account,
        customZippyNumber: _customCodeCtrl.text.trim().isNotEmpty
            ? _customCodeCtrl.text.trim()
            : null,
      );

      if (mounted) {
        setState(() {
          _isRegisteringNew = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zippy Till #${vendor.zippyNumber} activated successfully! 🎉'),
            backgroundColor: ZippyTheme.primaryGreen,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingRegistration = false);
      }
    }
  }

  void _copyTillCode(String zippyNumber) {
    Clipboard.setData(ClipboardData(text: zippyNumber));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied Zippy Till #$zippyNumber to clipboard!'),
        backgroundColor: ZippyTheme.primaryGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeVendor = ZippyPaymentService.activeMerchant;

    if (_isRegisteringNew || activeVendor == null) {
      return _buildRegistrationView();
    }

    return _buildDashboardHub(activeVendor);
  }

  Widget _buildDashboardHub(VendorModel vendor) {
    final stats = ZippyPaymentService.getMerchantStats(vendor.zippyNumber);
    final transactions = ZippyPaymentService.getTransactionsForVendor(vendor.zippyNumber);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Merchant Identity & Switcher Card
        _buildMerchantHeaderCard(vendor),
        const SizedBox(height: 14),

        // 2. Countertop Stand Till Display & QR Card
        _buildCounterTillCard(vendor),
        const SizedBox(height: 14),

        // 3. Real-Time Income & Financial Summary Grid
        _buildIncomeMetricsGrid(stats),
        const SizedBox(height: 18),

        // 4. Live Incoming Transaction Feed Header
        const Text(
          'LIVE INCOMING PAYMENTS',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),

        // 6. Transaction Items Stream
        if (transactions.isEmpty)
          _buildEmptyTransactionsCard()
        else
          ...transactions.map(_buildTransactionRow),

        const SizedBox(height: 24),

        // 7. Register New Till Secondary Button
        Center(
          child: TextButton.icon(
            key: const Key('registerNewTillButton'),
            style: TextButton.styleFrom(minimumSize: const Size(200, 48)),
            onPressed: () => setState(() => _isRegisteringNew = true),
            icon: const Icon(Icons.add_business_rounded, color: Colors.white60, size: 18),
            label: const Text(
              'Register Another Zippy Till',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMerchantHeaderCard(VendorModel vendor) {
    final allVendors = ZippyPaymentService.recentVendors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZippyTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZippyTheme.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: ZippyTheme.primaryGreen.withValues(alpha: 0.15),
            child: const Icon(Icons.storefront, color: ZippyTheme.primaryGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendor.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${vendor.category} • ${vendor.ownerName}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          if (allVendors.length > 1)
            PopupMenuButton<String>(
              key: const Key('switchMerchantTillMenu'),
              icon: const Icon(Icons.swap_horiz_rounded, color: ZippyTheme.primaryGreen),
              color: ZippyTheme.surfaceElevated,
              tooltip: 'Switch Active Till',
              onSelected: (selectedZippyNumber) {
                setState(() {
                  ZippyPaymentService.setActiveMerchant(selectedZippyNumber);
                });
              },
              itemBuilder: (context) => allVendors.map((v) {
                return PopupMenuItem(
                  value: v.zippyNumber,
                  child: Text(
                    '${v.name} (#${v.zippyNumber})',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCounterTillCard(VendorModel vendor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ZippyTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZippyTheme.primaryGreen.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: ZippyTheme.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.store_mall_directory_rounded, color: ZippyTheme.primaryGreen, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'YOUR TILL DISPLAY',
                    style: TextStyle(
                      color: ZippyTheme.primaryGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ZippyTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Countertop Ready',
                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4-Digit Till Code Presentation
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              color: ZippyTheme.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ZippyTheme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '#',
                  style: TextStyle(
                    color: ZippyTheme.primaryGreen,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  vendor.zippyNumber,
                  key: const Key('merchantTillCodeDisplay'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // QR Code simulation & copy button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TactileScale(
                child: OutlinedButton.icon(
                  key: const Key('copyTillCodeButton'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: ZippyTheme.border),
                    minimumSize: const Size(120, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _copyTillCode(vendor.zippyNumber),
                  icon: const Icon(Icons.copy_rounded, size: 16, color: ZippyTheme.primaryGreen),
                  label: const Text('Copy Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              TactileScale(
                child: OutlinedButton.icon(
                  key: const Key('showQrCodeButton'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: ZippyTheme.border),
                    minimumSize: const Size(120, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _showQrModal(vendor);
                  },
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18, color: ZippyTheme.primaryGreen),
                  label: const Text('Display QR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Settlement Account Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: ZippyTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: ZippyTheme.primaryGreen, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Instant Payout to ${vendor.bankName} (••••${vendor.accountNumber.substring(vendor.accountNumber.length - 4)})',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQrModal(VendorModel vendor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ZippyTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                vendor.name,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Scan to pay Till #${vendor.zippyNumber}',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 130, color: Colors.black),
                      Text(
                        '#${vendor.zippyNumber}',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  key: const Key('closeQrModalButton'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZippyTheme.primaryGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close QR', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIncomeMetricsGrid(MerchantIncomeStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final halfWidth = (constraints.maxWidth - 10) / 2;

        return Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: halfWidth,
                  child: _buildMetricTile(
                    label: "Today's Gross Sales",
                    value: 'R ${stats.totalGross.toStringAsFixed(2)}',
                    subtext: 'From customer tills',
                    valueColor: ZippyTheme.primaryGreen,
                    keyStr: 'merchantGrossSalesTile',
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: halfWidth,
                  child: _buildMetricTile(
                    label: 'Net Payout (97.5%)',
                    value: 'R ${stats.totalNet.toStringAsFixed(2)}',
                    subtext: 'Direct to your bank',
                    valueColor: Colors.white,
                    keyStr: 'merchantNetPayoutTile',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: halfWidth,
                  child: _buildMetricTile(
                    label: 'Zippy Fee (2.5%)',
                    value: 'R ${stats.totalFees.toStringAsFixed(2)}',
                    subtext: 'Transparent service fee',
                    valueColor: Colors.white70,
                    keyStr: 'merchantFeesTile',
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: halfWidth,
                  child: _buildMetricTile(
                    label: 'Sales Count',
                    value: '${stats.transactionCount}',
                    subtext: 'Completed payments',
                    valueColor: Colors.white,
                    keyStr: 'merchantSalesCountTile',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subtext,
    required Color valueColor,
    required String keyStr,
  }) {
    return Container(
      key: Key(keyStr),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZippyTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZippyTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(subtext, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }


  Widget _buildEmptyTransactionsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ZippyTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZippyTheme.border),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded, color: Colors.white38, size: 36),
            SizedBox(height: 8),
            Text(
              'No payments received yet',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'Customer payments to your till will appear here in real time.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionRow(TransactionModel tx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ZippyTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZippyTheme.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: ZippyTheme.primaryGreen.withValues(alpha: 0.15),
            child: const Icon(Icons.arrow_downward_rounded, color: ZippyTheme.primaryGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.customerName ?? 'Customer Payment',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '${_formatTimestamp(tx.createdAt)} • ${tx.authCode}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+ R ${tx.grossAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: ZippyTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'Net: R ${tx.netPayout.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Register Your Merchant Till',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (ZippyPaymentService.activeMerchant != null)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => setState(() => _isRegisteringNew = false),
                )
              else if (widget.onSwitchToCustomer != null)
                TextButton.icon(
                  onPressed: widget.onSwitchToCustomer,
                  icon: const Icon(Icons.arrow_back, size: 14, color: ZippyTheme.primaryGreen),
                  label: const Text('Pay Mode', style: TextStyle(color: ZippyTheme.primaryGreen, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Create your 4-digit Zippy Number to receive real-time bank payments with 2.5% pass-through fees.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 18),

          // Form Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ZippyTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ZippyTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trading Name
                const Text('Business Trading Name', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('merchantTradingNameField'),
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. Siya\'s Tuck Shop, Kasi Cuts',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: ZippyTheme.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ZippyTheme.border)),
                  ),
                ),
                const SizedBox(height: 14),

                // Category Chips
                const Text('Business Category', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _categories.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return InkWell(
                      key: Key('categoryChip_$cat'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = cat);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? ZippyTheme.primaryGreen.withValues(alpha: 0.15) : ZippyTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSel ? ZippyTheme.primaryGreen : Colors.transparent),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSel ? ZippyTheme.primaryGreen : Colors.white70,
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Owner Name & Phone
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Owner Name', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            key: const Key('merchantOwnerNameField'),
                            controller: _ownerCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Full Name',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: ZippyTheme.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ZippyTheme.border)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mobile Phone', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            key: const Key('merchantPhoneField'),
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: '+27 ...',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: ZippyTheme.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ZippyTheme.border)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Destination Bank & Account
                const Text('Settlement Bank & Account Number', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: ZippyTheme.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ZippyTheme.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            key: const Key('merchantBankDropdown'),
                            value: _selectedBank,
                            dropdownColor: ZippyTheme.surfaceElevated,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            isExpanded: true,
                            items: _supportedBanks.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedBank = val);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: TextField(
                        key: const Key('merchantAccountNumberField'),
                        controller: _accountCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Account Number',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: ZippyTheme.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ZippyTheme.border)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Preferred 4-digit code
                const Text('Desired 4-Digit Zippy Code (Optional)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('merchantDesiredCodeField'),
                  controller: _customCodeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 4),
                  decoration: InputDecoration(
                    prefixText: '# ',
                    prefixStyle: const TextStyle(color: ZippyTheme.primaryGreen, fontWeight: FontWeight.bold),
                    hintText: '7742',
                    counterText: '',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: ZippyTheme.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ZippyTheme.border)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Submit Button
          TactileScale(
            enabled: !_isSubmittingRegistration,
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                key: const Key('submitMerchantRegistrationButton'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZippyTheme.primaryGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _isSubmittingRegistration ? null : _handleRegister,
                child: _isSubmittingRegistration
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                        'Create & Activate Zippy Till ⚡',
                        style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}';
  }
}
