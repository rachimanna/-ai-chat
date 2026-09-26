import 'package:flutter/material.dart';

/// Плавное появление (прозрачность + небольшой сдвиг снизу).
class AppearAnimation extends StatefulWidget {
  const AppearAnimation({
    super.key,
    required this.child,
    this.enabled = true,
    this.duration = const Duration(milliseconds: 320),
    this.offset = 0.08,
  });

  final Widget child;
  final bool enabled;
  final Duration duration;
  final double offset;

  @override
  State<AppearAnimation> createState() => _AppearAnimationState();
}

class _AppearAnimationState extends State<AppearAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.enabled ? 0 : 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(
          begin: Offset(0, widget.offset),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
