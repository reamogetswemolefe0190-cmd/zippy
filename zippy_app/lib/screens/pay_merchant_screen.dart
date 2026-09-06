import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zippy_app/models/vendor_model.dart';
import 'package:zippy_app/services/zippy_payment_service.dart';
import 'package:zippy_app/widgets/zar_numpad.dart';

/// Screen allowing customers to enter a 4-digit Zippy Number and execute a micro-payment.
class PayMerchantScreen extends StatefulWidget {
  /// Initial 4-digit merchant identifier to pre-populate.
  final String? initialZippyNumber;

  /// Initial payment amount in ZAR to pre-populate.
  final double? initialAmount;

  /// Callback when user wants to transition to splitting this bill.
  final void Function(double amount, String vendorName)? onSplitRequested;

  /// Creates a [PayMerchantScreen].
  const PayMerchantScreen({
    super.key,
    this.initialZippyNumber,
    this.initialAmount,
    this.onSplitRequested,
  });

  @override
  State<PayMerchantScreen> createState() => _PayMerchantScreenState();
}

class _PayMerchantScreenState extends State<PayMerchantScreen> {
  late final TextEditingController _zippyController;
  String _zippyNumber = '4523';
  String _amountStr = '45';
  VendorModel? _vendor;
  bool _isLoadingVendor = false;
  bool _vendorNotFound = false;
  bool _isProcessing = false;
  Map<String, dynamic>? _receipt;

  @override
  void initState() {
    super.initState();
    _zippyNumber = widget.initialZippyNumber ?? '4523';
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountStr = widget.initialAmount! % 1 == 0
          ? widget.initialAmount!.toInt().toString()
          : widget.initialAmount!.toStringAsFixed(2);
    }
    _zippyController = TextEditingController(text: _zippyNumber);
    _lookupVendor(_zippyNumber);
  }

  @override
  void didUpdateWidget(PayMerchantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialZippyNumber != null &&
        widget.initialZippyNumber != oldWidget.initialZippyNumber) {
      _zippyNumber = widget.initialZippyNumber!;
      _zippyController.text = _zippyNumber;
      _lookupVendor(_zippyNumber);
    }
    if (widget.initialAmount != null &&
        widget.initialAmount != oldWidget.initialAmount &&
        widget.initialAmount! > 0) {
      setState(() {
        _amountStr = widget.initialAmount! % 1 == 0
            ? widget.initialAmount!.toInt().toString()
            : widget.initialAmount!.toStringAsFixed(2);
      });
    }
  }

  @override
  void dispose() {
    _zippyController.dispose();
    super.dispose();
  }

  Future<void> _lookupVendor(String number) async {
    final clean = number.replaceAll(RegExp(r'\D'), '').trim();
    if (clean.length == 4) {
      setState(() {
        _isLoadingVendor = true;
        _vendorNotFound = false;
      });
      try {
        final vendor = await ZippyPaymentService.lookupVendor(clean);
        if (mounted) {
          final current = _zippyController.text.replaceAll(RegExp(r'\D'), '').trim();
          if (current != clean) return;
          setState(() {
            _vendor = vendor;
            _isLoadingVendor = false;
            _vendorNotFound = (vendor == null);
          });
        }
      } catch (_) {
        if (mounted) {
          final current = _zippyController.text.replaceAll(RegExp(r'\D'), '').trim();
          if (current != clean) return;
          setState(() {
            _vendor = null;
            _isLoadingVendor = false;
            _vendorNotFound = true;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _vendor = null;
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

  Future<void> _handlePay() async {
    if (_amountStr.endsWith('.')) {
      _amountStr = _amountStr.substring(0, _amountStr.length - 1);
    }
    if (_vendor == null || double.tryParse(_amountStr) == null) return;
    setState(() => _isProcessing = true);

    try {
      final res = await ZippyPaymentService.payMerchant(
        vendor: _vendor!,
        grossAmount: double.parse(_amountStr),
        customerName: 'Thabo Mbeki',
      );

      if (mounted) {
        setState(() {
          _receipt = res;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_receipt != null) {
      return _buildReceiptView();
    }

    final double amount = double.tryParse(_amountStr) ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        title: const Text(
          'Pay Merchant',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Zippy Number Input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Merchant Zippy # (Till Code)',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        '#',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: const Key('zippyNumberField'),
                          controller: _zippyController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 4,
                          onChanged: (val) {
                            _zippyNumber = val;
                            _lookupVendor(val);
                          },
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            hintText: '4523',
                            hintStyle: TextStyle(color: Colors.white24),
                          ),
                        ),
                      ),
                      if (_isLoadingVendor)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  if (_vendor != null) ...[
                    const Divider(color: Color(0xFF334155)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _vendor!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_vendor!.category} • ${_vendor!.bankName}',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'VERIFIED',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_vendorNotFound) ...[
                    const Divider(color: Color(0xFF334155)),
                    Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Till #$_zippyNumber not registered on Zippy',
                            key: const Key('vendorNotFoundMessage'),
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Amount Display (Clean, Zero Fee Jargon)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF131D31),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  const Text(
                    'AMOUNT TO PAY',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'R $_amountStr',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Direct Instant Settlement • Zero Hidden Fees',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Numpad
            ZarNumpad(onKeyPressed: _onNumpad),
            const SizedBox(height: 16),

            // Pay Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                key: const Key('payMerchantSubmitButton'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _vendor != null && amount > 0 && !_isProcessing ? _handlePay : null,
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Builder(
                        builder: (context) {
                          final displayAmount = _amountStr.endsWith('.')
                              ? _amountStr.substring(0, _amountStr.length - 1)
                              : _amountStr;
                          return Text(
                            'Pay R $displayAmount to #${_vendor?.zippyNumber ?? _zippyNumber}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptView() {
    final double gross = (_receipt!['grossAmount'] as num).toDouble();
    final double netPayout = (_receipt!['netVendorPayout'] as num).toDouble();
    final double zippyFee = (_receipt!['zippyFee'] as num).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                  size: 64,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Payment Succeeded',
                  style: TextStyle(
                    color: Color(0xFF10B981),
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
                  'Paid to ${_vendor!.name}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),
                const Divider(color: Color(0xFF334155)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Payment Reference:',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
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
                    const Text(
                      'Settlement Method:',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    Text(
                      'Direct to ${_vendor!.bankName}',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
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
                    const Text(
                      'Merchant Settlement (97.5%):',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
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
                    const Text(
                      'Service Fee (2.5%):',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
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
                    const Text(
                      'SMS Confirmation:',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    Text(
                      'Delivered to ${_vendor!.phoneNumber}',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  key: const Key('splitBillButton'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16C784),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    final grossAmount = gross;
                    final vendorName = _vendor!.name;
                    setState(() {
                      _receipt = null;
                      _amountStr = '0';
                    });
                    widget.onSplitRequested?.call(
                      grossAmount,
                      vendorName,
                    );
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
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _receipt = null;
                      _amountStr = '0';
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
      ),
    );
  }
}
