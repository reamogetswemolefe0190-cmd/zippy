import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tactile, flat numeric keypad for fast South African Rand amounts.
///
/// Implements tactile micro-interactions with 0.96 press-down scaling,
/// haptic feedback, and accessibility compliance (>= 48x48px touch targets).
class ZarNumpad extends StatelessWidget {
  /// Callback when a button is tapped.
  final void Function(String value) onKeyPressed;

  /// Optional accent splash color for keypad taps. Defaults to emerald green.
  final Color? accentColor;

  /// Creates a new [ZarNumpad].
  const ZarNumpad({super.key, required this.onKeyPressed, this.accentColor});

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'backspace'];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 52,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        final bool isBackspace = key == 'backspace';

        return _NumpadKeyButton(
          keyValue: key,
          isBackspace: isBackspace,
          accentColor: accentColor,
          onTap: () => onKeyPressed(key),
        );
      },
    );
  }
}

class _NumpadKeyButton extends StatefulWidget {
  final String keyValue;
  final bool isBackspace;
  final Color? accentColor;
  final VoidCallback onTap;

  const _NumpadKeyButton({
    required this.keyValue,
    required this.isBackspace,
    this.accentColor,
    required this.onTap,
  });

  @override
  State<_NumpadKeyButton> createState() => _NumpadKeyButtonState();
}

class _NumpadKeyButtonState extends State<_NumpadKeyButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isPressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: Key('numpad_${widget.keyValue}'),
          borderRadius: BorderRadius.circular(14),
          splashColor: (widget.accentColor ?? const Color(0xFF16C784)).withValues(alpha: 0.15),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          onHighlightChanged: (highlighted) {
            setState(() => _isPressed = highlighted);
          },
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              child: widget.isBackspace
                  ? const Icon(Icons.backspace_outlined, color: Colors.white60, size: 20)
                  : Text(
                      widget.keyValue,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFF8FAFC),
                        letterSpacing: -0.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
