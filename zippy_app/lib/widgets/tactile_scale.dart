import 'package:flutter/material.dart';

/// A wrapper widget that applies a smooth 0.96 scale micro-interaction when pressed down.
///
/// Follows tactile micro-interaction principles from Apple design and Emil Kowalski animation patterns.
class TactileScale extends StatefulWidget {
  /// The child widget to wrap with the tactile scale effect.
  final Widget child;

  /// Pressed scale factor. Defaults to 0.96.
  final double pressedScale;

  /// Animation duration for the press down and release transitions.
  final Duration duration;

  /// Whether the tactile micro-interaction is enabled. Defaults to true.
  final bool enabled;

  /// Creates a [TactileScale] wrapper.
  const TactileScale({
    super.key,
    required this.child,
    this.pressedScale = 0.96,
    this.duration = const Duration(milliseconds: 100),
    this.enabled = true,
  });

  @override
  State<TactileScale> createState() => _TactileScaleState();
}

class _TactileScaleState extends State<TactileScale> {
  bool _isPressed = false;

  @override
  void didUpdateWidget(TactileScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (!widget.enabled) return;
        setState(() => _isPressed = true);
      },
      onPointerUp: (_) {
        if (_isPressed) {
          setState(() => _isPressed = false);
        }
      },
      onPointerCancel: (_) {
        if (_isPressed) {
          setState(() => _isPressed = false);
        }
      },
      child: AnimatedScale(
        scale: _isPressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
