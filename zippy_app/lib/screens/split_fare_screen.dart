import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zippy_app/core/fee_engine.dart';
import 'package:zippy_app/core/zippy_theme.dart';
import 'package:zippy_app/models/bill_split_model.dart';
import 'package:zippy_app/services/zippy_payment_service.dart';
import 'package:zippy_app/widgets/tactile_scale.dart';
import 'package:zippy_app/widgets/zar_numpad.dart';

/// Contact model representing a selectable friend.
class FriendContact {
  /// Display name of the friend.
  final String name;

  /// Mobile phone number.
  final String phone;

  /// Creates a [FriendContact].
  const FriendContact({required this.name, required this.phone});
}

/// Screen allowing the host to create a new split or manage an active split.
class SplitFareScreen extends StatefulWidget {
  /// Initial total bill to prefill if coming from a merchant payment.
  final double? initialTotal;

  /// Initial venue title to prefill.
  final String? initialTitle;

  /// Creates a [SplitFareScreen].
  const SplitFareScreen({super.key, this.initialTotal, this.initialTitle});

  @override
  State<SplitFareScreen> createState() => _SplitFareScreenState();
}

class _SplitFareScreenState extends State<SplitFareScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _totalCtrl;

  final List<FriendContact> _availableFriends = const [
    FriendContact(name: 'Lerato Molefe', phone: '+27 83 555 2233'),
    FriendContact(name: 'Sipho Ndlovu', phone: '+27 84 666 3344'),
    FriendContact(name: 'Kamohelo Sithole', phone: '+27 72 888 4455'),
    FriendContact(name: 'Nomsa Dube', phone: '+27 82 999 1122'),
  ];

  late Set<String> _selectedFriendNames;
  bool _isCustomSplit = false;
  final Map<String, TextEditingController> _customControllers = {};

  BillSplitModel? _activeSplit;
  bool _isCreating = false;
  final Set<String> _settlingParticipantIds = {};

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(
      text: widget.initialTitle ?? '',
    );
    final initTotalStr = widget.initialTotal != null
        ? (widget.initialTotal! % 1 == 0
            ? widget.initialTotal!.toInt().toString()
            : widget.initialTotal!.toStringAsFixed(2))
        : '0';
    _totalCtrl = TextEditingController(text: initTotalStr);

    // Default to first 3 friends selected
    _selectedFriendNames = {
      _availableFriends[0].name,
      _availableFriends[1].name,
      _availableFriends[2].name,
    };

    _recalculateCustomControllers();
  }

  @override
  void didUpdateWidget(SplitFareScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool shouldSync = false;
    if (widget.initialTotal != null && widget.initialTotal != oldWidget.initialTotal) {
      final initTotalStr = widget.initialTotal! % 1 == 0
          ? widget.initialTotal!.toInt().toString()
          : widget.initialTotal!.toStringAsFixed(2);
      _totalCtrl.text = initTotalStr;
      shouldSync = true;
    }
    if (widget.initialTitle != null && widget.initialTitle != oldWidget.initialTitle) {
      _titleCtrl.text = widget.initialTitle!;
      shouldSync = true;
    }
    if (shouldSync) {
      _activeSplit = null;
      _recalculateCustomControllers(force: true);
    }
  }

  void _recalculateCustomControllers({bool force = false}) {
    final double total = double.tryParse(_totalCtrl.text) ?? 0.0;
    final int count = _selectedFriendNames.length + 1; // Including host
    final double equalShare = (count > 0 && total > 0)
        ? FeeEngine.calculateEqualPortion(total, count)
        : 0.0;

    for (final friend in _availableFriends) {
      if (!_customControllers.containsKey(friend.name)) {
        _customControllers[friend.name] = TextEditingController(
          text: equalShare.toStringAsFixed(2),
        );
      } else if (force) {
        _customControllers[friend.name]!.text = equalShare.toStringAsFixed(2);
      }
    }
  }

  double get _currentTotal => double.tryParse(_totalCtrl.text) ?? 0.0;

  double get _customFriendsSum {
    double sum = 0.0;
    for (final name in _selectedFriendNames) {
      final text = _customControllers[name]?.text.trim() ?? '';
      final val = double.tryParse(text) ?? 0.0;
      sum += val;
    }
    return ((sum * 100).round()) / 100;
  }

  double get _hostPortion {
    final rem = _currentTotal - _customFriendsSum;
    return ((rem * 100).round()) / 100;
  }

  bool get _hasInvalidPortion {
    if (!_isCustomSplit) return false;
    for (final name in _selectedFriendNames) {
      final text = _customControllers[name]?.text.trim() ?? '';
      final val = double.tryParse(text);
      if (val == null || val <= 0) return true;
    }
    return false;
  }

  bool get _isCustomOverAllocated =>
      _isCustomSplit && (_customFriendsSum > _currentTotal + 0.009);

  bool get _canDispatch {
    if (_currentTotal <= 0 || _selectedFriendNames.isEmpty || _isCreating) {
      return false;
    }
    if (_isCustomSplit) {
      if (_hasInvalidPortion || _isCustomOverAllocated) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _totalCtrl.dispose();
    for (final ctrl in _customControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _onNumpad(String val) {
    setState(() {
      var current = _totalCtrl.text;
      if (current.isEmpty || (double.tryParse(current) == null && !current.endsWith('.'))) {
        current = '0';
      }
      if (val == 'backspace') {
        if (current.isEmpty || current.length <= 1) {
          current = '0';
        } else {
          current = current.substring(0, current.length - 1);
          if (current.isEmpty) current = '0';
        }
      } else if (val == '.') {
        if (current.isEmpty) {
          current = '0.';
        } else if (!current.contains('.')) {
          current += '.';
        }
      } else {
        if (current.replaceAll('.', '').length >= 8) return;
        if (current.contains('.')) {
          final parts = current.split('.');
          if (parts.length > 1 && parts[1].length >= 2) return;
        }
        current = current == '0' ? val : current + val;
      }
      _totalCtrl.text = current;
      _recalculateCustomControllers(force: !_isCustomSplit);
    });
  }

  void _toggleFriend(String friendName) {
    setState(() {
      if (_selectedFriendNames.contains(friendName)) {
        if (_selectedFriendNames.length > 1) {
          _selectedFriendNames.remove(friendName);
        }
      } else {
        _selectedFriendNames.add(friendName);
      }
      _recalculateCustomControllers();
    });
  }

  Future<void> _createSplit() async {
    if (_isCreating) return;
    var totalText = _totalCtrl.text.trim();
    if (totalText.endsWith('.')) {
      totalText = totalText.substring(0, totalText.length - 1);
      _totalCtrl.text = totalText;
    }
    final double? total = double.tryParse(totalText);
    if (total == null || total <= 0 || _selectedFriendNames.isEmpty) return;
    if (_isCustomSplit && (_hasInvalidPortion || _isCustomOverAllocated)) return;

    setState(() => _isCreating = true);

    try {
      List<double>? customShares;
      if (_isCustomSplit) {
        customShares = _selectedFriendNames.map((name) {
          final ctrl = _customControllers[name];
          var shareText = ctrl?.text.trim() ?? '';
          if (shareText.endsWith('.')) {
            shareText = shareText.substring(0, shareText.length - 1);
          }
          return double.tryParse(shareText) ?? 0.0;
        }).toList();
      }

      final split = await ZippyPaymentService.createSplit(
        title: _titleCtrl.text.trim().isNotEmpty
            ? _titleCtrl.text.trim()
            : 'Split Bill',
        totalAmount: total,
        hostName: 'Thabo Mbeki',
        friendNames: _selectedFriendNames.toList(),
        customShares: customShares,
      );

      if (mounted) {
        setState(() {
          _activeSplit = split;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Split failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _settleParticipant(String participantId) async {
    if (_activeSplit == null || _settlingParticipantIds.contains(participantId)) return;
    setState(() => _settlingParticipantIds.add(participantId));

    try {
      final updated = await ZippyPaymentService.settleParticipant(
        splitId: _activeSplit!.id,
        participantId: participantId,
      );
      if (mounted) {
        setState(() => _activeSplit = updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settlement failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _settlingParticipantIds.remove(participantId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeSplit != null) {
      return _buildActiveSplitView();
    }

    final double total = double.tryParse(_totalCtrl.text) ?? 0.0;
    final int friendCount = _selectedFriendNames.length;
    final int totalPersons = friendCount + 1; // Including host
    final double equalShare = (totalPersons > 0 && total > 0)
        ? FeeEngine.calculateEqualPortion(total, totalPersons)
        : 0.0;
    final double friendsSum = _isCustomSplit
        ? _customFriendsSum
        : ((equalShare * friendCount * 100).round() / 100);
    final double feeTotal = friendCount * 2.50;
    final double totalRequested = friendsSum + feeTotal;
    final double hostShare = _isCustomSplit ? _hostPortion : (total - friendsSum);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode Subtitle
        const Text(
          'Split Fare ⚡',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        // 1. Venue / Occasion Card (matching Recipient Card style)
        _buildOccasionSection(),
        const SizedBox(height: 12),

        // 2. Hero Bill Amount Section (matching Hero Amount style)
        _buildHeroBillSection(total, friendCount, hostShare, friendsSum, equalShare),
        const SizedBox(height: 12),

        // Shared Tactile ZAR Numpad with Split Purple accent
        ZarNumpad(
          onKeyPressed: _onNumpad,
          accentColor: ZippyTheme.splitPurple,
        ),
        const SizedBox(height: 16),

        // 3. Portion Mode Selector (Equal vs Custom)
        _buildPortionModeSelector(totalPersons),
        if (_isCustomSplit) ...[
          const SizedBox(height: 12),
          _buildCustomSummaryCard(),
        ],
        const SizedBox(height: 16),

        // 4. Select Friends Header & List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SELECT FRIENDS ($friendCount of ${_availableFriends.length} selected)',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const Text(
              '1-Tap PayShap RTP',
              style: TextStyle(
                color: ZippyTheme.splitPurple,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ..._availableFriends.map((friend) => _buildFriendCard(friend, equalShare)),
        const SizedBox(height: 14),

        // 5. Grouped Fintech Fee Summary Card
        if (friendCount > 0) ...[
          _buildFintechSummaryCard(friendCount, friendsSum, feeTotal, totalRequested),
          const SizedBox(height: 16),
        ],

        // 6. Visual Conclusion CTA (54px height matching Pay button) with TactileScale
        TactileScale(
          enabled: _canDispatch,
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              key: const Key('dispatchSplitButton'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ZippyTheme.primaryGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: _canDispatch ? _createSplit : null,
              child: _isCreating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                    )
                  : Text(
                      'Create & Split R ${friendsSum.toStringAsFixed(0)} ⚡',
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

  Widget _buildOccasionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZippyTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZippyTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ZippyTheme.splitPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.group_outlined,
                  color: ZippyTheme.splitPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Occasion / Group Title',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextField(
                      key: const Key('splitTitleField'),
                      controller: _titleCtrl,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'e.g. Dinner at RocoMamas',
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildOccasionChip('🍔 Dinner', 'RocoMamas Saturday Dinner 🍔'),
                const SizedBox(width: 8),
                _buildOccasionChip('🚕 Taxi Fare', 'Taxi to Sandton City 🚕'),
                const SizedBox(width: 8),
                _buildOccasionChip('🍻 Drinks', 'Drinks at Tigers Milk 🍻'),
                const SizedBox(width: 8),
                _buildOccasionChip('🛒 Groceries', 'Braai groceries at Woolies 🛒'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccasionChip(String label, String fullTitle) {
    final isSelected = _titleCtrl.text == fullTitle;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _titleCtrl.text = fullTitle;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? ZippyTheme.splitPurple.withValues(alpha: 0.25)
              : ZippyTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? ZippyTheme.splitPurple
                : ZippyTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBillSection(
    double total,
    int friendCount,
    double hostShare,
    double friendsSum,
    double equalShare,
  ) {
    final double fontSize = _totalCtrl.text.length >= 7
        ? 28.0
        : _totalCtrl.text.length >= 5
            ? 36.0
            : 44.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: ZippyTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZippyTheme.border),
      ),
      child: Column(
        children: [
          const Text(
            'Total Bill Paid by You',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'R ',
                style: TextStyle(
                  color: ZippyTheme.splitPurple,
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
                  _totalCtrl.text,
                  key: const Key('splitTotalField'),
                ),
              ),
            ],
          ),
          if (total > 0 && friendCount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ZippyTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'You: R ${hostShare.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: ZippyTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('•', style: TextStyle(color: Colors.white38)),
                  const SizedBox(width: 8),
                  Text(
                    '$friendCount friends: R ${friendsSum.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  if (!_isCustomSplit) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(R ${equalShare.toStringAsFixed(2)} ea)',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPortionModeSelector(int totalPersons) {
    return Container(
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
              AnimatedAlign(
                alignment: !_isCustomSplit
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
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      key: const Key('splitModeEqual'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (_isCustomSplit) {
                          setState(() {
                            _isCustomSplit = false;
                            _recalculateCustomControllers(force: true);
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: constraints.maxHeight,
                        alignment: Alignment.center,
                        child: Text(
                          'Equal Portions (÷$totalPersons)',
                          style: TextStyle(
                            color: !_isCustomSplit ? Colors.black : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      key: const Key('splitModeCustom'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (!_isCustomSplit) {
                          setState(() {
                            _isCustomSplit = true;
                            _recalculateCustomControllers();
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: constraints.maxHeight,
                        alignment: Alignment.center,
                        child: Text(
                          'Custom Portions',
                          style: TextStyle(
                            color: _isCustomSplit ? Colors.black : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildCustomSummaryCard() {
    return Container(
      key: const Key('customPortionsSummaryCard'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZippyTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isCustomOverAllocated || _hasInvalidPortion
              ? const Color(0xFFEF4444).withValues(alpha: 0.5)
              : ZippyTheme.splitPurple.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Custom Portions Breakdown',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              InkWell(
                key: const Key('resetToEqualSharesButton'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _recalculateCustomControllers(force: true);
                  });
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: Container(
                    alignment: Alignment.centerRight,
                    child: const Text(
                      'Reset to Equal',
                      style: TextStyle(
                        color: ZippyTheme.splitPurple,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Friends Subtotal: R ${_customFriendsSum.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              Text(
                'Your Share (Host): R ${_hostPortion.toStringAsFixed(2)}',
                style: TextStyle(
                  color: _hostPortion < 0 ? const Color(0xFFEF4444) : ZippyTheme.primaryGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (_hasInvalidPortion) ...[
            const SizedBox(height: 6),
            const Text(
              '⚠️ Each friend portion must be a valid amount greater than R0.00',
              key: Key('customPortionInvalidError'),
              style: TextStyle(color: Color(0xFFEF4444), fontSize: 11),
            ),
          ] else if (_isCustomOverAllocated) ...[
            const SizedBox(height: 6),
            Text(
              '⚠️ Friend portions (R ${_customFriendsSum.toStringAsFixed(2)}) exceed total bill (R ${_currentTotal.toStringAsFixed(2)})',
              key: const Key('customPortionExceedError'),
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFriendCard(FriendContact friend, double equalShare) {
    final isSelected = _selectedFriendNames.contains(friend.name);
    final initials = friend.name
        .split(' ')
        .take(2)
        .map((p) => p.isNotEmpty ? p[0] : '')
        .join();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? ZippyTheme.surfaceElevated : ZippyTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? ZippyTheme.splitPurple.withValues(alpha: 0.4)
              : ZippyTheme.border,
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              _toggleFriend(friend.name);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Center(
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? ZippyTheme.splitPurple : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? ZippyTheme.splitPurple : Colors.white38,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 18, color: Colors.black)
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: ZippyTheme.surfaceElevated,
            child: Text(
              initials,
              style: TextStyle(
                color: isSelected ? ZippyTheme.splitPurple : Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  friend.phone,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected) ...[
            if (!_isCustomSplit)
              Text(
                'R ${equalShare.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              )
            else
              SizedBox(
                width: 85,
                child: TextField(
                  key: Key('customPortionField_${friend.name.toLowerCase().replaceAll(' ', '_')}'),
                  controller: _customControllers[friend.name],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    prefixText: 'R ',
                    prefixStyle: TextStyle(color: ZippyTheme.splitPurple, fontSize: 13),
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(color: ZippyTheme.splitPurple),
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 2),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFintechSummaryCard(
    int friendCount,
    double friendsSum,
    double feeTotal,
    double totalRequested,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZippyTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZippyTheme.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$friendCount friends selected',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'R ${friendsSum.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Convenience fees (R2.50 × $friendCount)',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              Text(
                'R ${feeTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: ZippyTheme.splitPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total to collect',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'R ${totalRequested.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSplitView() {
    final split = _activeSplit!;
    final int percent = split.percentSettled;
    final int settledCount = split.participants.where((p) => p.hasPaid).length;
    final int totalParticipants = split.participants.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Header Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Split Settlement Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ZippyTheme.splitPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: ZippyTheme.splitPurple.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: ZippyTheme.splitPurple,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            IconButton(
              key: const Key('closeActiveSplitButton'),
              icon: const Icon(Icons.close, color: Colors.white60),
              onPressed: () => setState(() => _activeSplit = null),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Settlement Header Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: ZippyTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ZippyTheme.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        split.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Bill: R ${split.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: ZippyTheme.splitPurple,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: percent / 100,
                backgroundColor: ZippyTheme.surfaceElevated,
                valueColor: const AlwaysStoppedAnimation(ZippyTheme.primaryGreen),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$settledCount of $totalParticipants Friends Settled',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    split.isFullySettled
                        ? 'Fully Settled 🎉'
                        : 'Settlement in progress',
                    style: TextStyle(
                      color: split.isFullySettled
                          ? ZippyTheme.primaryGreen
                          : ZippyTheme.splitPurple,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Participant Settlements List Header
        const Text(
          'PARTICIPANT 1-TAP SETTLEMENTS',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),

        ...split.participants.map((p) {
          final isSettling = _settlingParticipantIds.contains(p.id);
          final initials = p.name
              .split(' ')
              .take(2)
              .map((s) => s.isNotEmpty ? s[0] : '')
              .join();

          return Container(
            key: Key('participant_${p.id}'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ZippyTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ZippyTheme.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: ZippyTheme.surfaceElevated,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'R ${p.shareAmount.toStringAsFixed(2)} (+ R2.50 fee = R ${p.totalToPay.toStringAsFixed(2)})',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (p.hasPaid)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ZippyTheme.primaryGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ZippyTheme.primaryGreen, width: 0.8),
                    ),
                    child: const Text(
                      'PAID',
                      style: TextStyle(
                        color: ZippyTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else
                  TactileScale(
                    enabled: !isSettling,
                    child: ElevatedButton.icon(
                      key: Key('settleButton_${p.id}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZippyTheme.primaryGreen,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(64, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: isSettling ? null : () => _settleParticipant(p.id),
                      icon: isSettling
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.flash_on, size: 14, color: Colors.black),
                      label: Text(
                        isSettling ? 'Settling...' : '1-Tap Pay',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),

        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(140, 48)),
            onPressed: () => setState(() => _activeSplit = null),
            icon: const Icon(Icons.arrow_back, color: Colors.white60, size: 16),
            label: const Text(
              'Back to Split Form',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
